// QuizDraw Submit Guess Edge Function
// 개발 헌법 준수: 실제 구현만, 폴백/더미 데이터 절대 금지

import {
  createServiceClient,
  createResponse,
  createErrorResponse,
  handleCors,
  validateRequestMethod,
  parseRequestBody,
  validateUUID,
  validateGuess,
  normalizeText,
  generateIdempotencyKey,
  logInfo,
  logError,
  BUSINESS_RULES
} from '../_shared/utils.ts';

interface SubmitGuessRequest {
  round_id?: string;
  room_id?: string;
  room_code?: string;
  user_id: string;
  guess: string;
}

interface SubmitGuessResponse {
  guess_id: string;
  round_id: string;
  user_id: string;
  guess: string;
  is_correct: boolean;
  is_winner: boolean;
  coins_earned?: number;
  round_status: string;
  created_at: string;
}

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    validateRequestMethod(req, ['POST']);
    const body = await parseRequestBody(req) as SubmitGuessRequest;
    
    const { round_id, room_id, room_code, user_id, guess } = body;

    validateUUID(user_id, 'user_id');
    validateGuess(guess);

    const supabase = createServiceClient();

    // 라운드 조회 (여러 방법 지원)
    let round;
    if (round_id) {
      const { data, error } = await supabase
        .from('rounds')
        .select('*')
        .eq('id', round_id)
        .single();
      if (error) throw new Error(`Round not found: ${error.message}`);
      round = data;
    } else if (room_id || room_code) {
      // 룸에서 현재 진행중인 라운드 찾기
      const roomFilter = room_id ? 
        supabase.from('rooms').select('id').eq('id', room_id) :
        supabase.from('rooms').select('id').eq('code', room_code);
      
      const { data: roomData, error: roomError } = await roomFilter.single();
      if (roomError) throw new Error(`Room not found: ${roomError.message}`);

      const { data, error } = await supabase
        .from('rounds')
        .select('*')
        .eq('room_id', roomData.id)
        .eq('status', 'playing')
        .single();
      if (error) throw new Error(`No active round found: ${error.message}`);
      round = data;
    } else {
      throw new Error('Either round_id, room_id, or room_code is required');
    }

    // 라운드 상태 확인
    if (round.status !== 'playing') {
      return createErrorResponse('Round is not active', 400);
    }

    // 그리는 사람은 자신의 그림에 정답을 제출할 수 없음
    if (round.drawer_user_id === user_id) {
      return createErrorResponse('Drawer cannot submit guess', 400);
    }

    // 정답 정규화 및 비교
    const normalizedGuess = normalizeText(guess);
    const normalizedAnswer = normalizeText(round.answer);
    const isCorrect = normalizedGuess === normalizedAnswer;

    // 추측 저장
    const { data: guessData, error: guessError } = await supabase
      .from('guesses')
      .insert([{
        round_id: round.id,
        user_id,
        text: guess.trim(),
        normalized_text: normalizedGuess,
        is_correct: isCorrect
      }])
      .select('*')
      .single();

    if (guessError) {
      if (guessError.message.includes('unique')) {
        return createErrorResponse('You have already submitted a guess for this round', 400);
      }
      throw new Error(`Failed to save guess: ${guessError.message}`);
    }

    let coinsEarned = 0;
    let isWinner = false;

    // 정답인 경우 처리
    if (isCorrect) {
      isWinner = true;
      
      // 라운드 종료
      await supabase
        .from('rounds')
        .update({ 
          status: 'ended', 
          winner_user_id: user_id,
          ended_at: new Date().toISOString()
        })
        .eq('id', round.id);

      // 룸 상태를 다시 waiting으로 변경 (다음 라운드를 위해)
      await supabase
        .from('rooms')
        .update({ status: 'waiting' })
        .eq('id', round.room_id);

      // 코인 보상 지급
      const receiveIdempotency = generateIdempotencyKey('RECEIVE', round.id, user_id);
      const sendIdempotency = generateIdempotencyKey('SEND', round.id, round.drawer_user_id);

      // 정답자에게 RECEIVE 보상
      try {
        await supabase
          .from('coin_tx')
          .insert([{
            user_id,
            type: 'RECEIVE',
            amount: BUSINESS_RULES.RECEIVE_REWARD,
            ref_round_id: round.id,
            idem_key: receiveIdempotency,
            created_by: 'edge:submit-guess'
          }]);
        coinsEarned = BUSINESS_RULES.RECEIVE_REWARD;
      } catch (e) {
        logError('Failed to give RECEIVE reward', { user_id, round_id: round.id, error: e });
      }

      // 그린 사람에게 SEND 보상
      try {
        await supabase
          .from('coin_tx')
          .insert([{
            user_id: round.drawer_user_id,
            type: 'SEND', 
            amount: BUSINESS_RULES.SEND_REWARD,
            ref_round_id: round.id,
            idem_key: sendIdempotency,
            created_by: 'edge:submit-guess'
          }]);
      } catch (e) {
        logError('Failed to give SEND reward', { user_id: round.drawer_user_id, round_id: round.id, error: e });
      }
    }

    const response: SubmitGuessResponse = {
      guess_id: guessData.id,
      round_id: round.id,
      user_id,
      guess: guess.trim(),
      is_correct: isCorrect,
      is_winner,
      coins_earned: coinsEarned > 0 ? coinsEarned : undefined,
      round_status: isCorrect ? 'ended' : 'playing',
      created_at: guessData.created_at
    };

    logInfo('Guess submitted successfully', response);
    return createResponse(response, 201);

  } catch (error) {
    logError('Submit guess failed', error);
    return createErrorResponse('Failed to submit guess', 500, { 
      message: error.message 
    });
  }
});
