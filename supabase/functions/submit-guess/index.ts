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
  logInfo,
  logError,
  withTransaction,
  BUSINESS_RULES,
  generateIdempotencyKey,
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
  coins_earned: number;
  round_status: string;
  created_at: string;
}

Deno.serve(async (req: Request) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    validateRequestMethod(req, ['POST']);
    const body = await parseRequestBody(req) as SubmitGuessRequest;

    let { round_id, room_id, room_code, user_id, guess } = body;

    // round_id가 없으면 room 단위 최신 라운드 조회 허용 (편의)
    if (!round_id) {
      let resolvedRoomId: string | null = null;
      if (room_id) {
        validateUUID(room_id, 'room_id');
        resolvedRoomId = room_id;
      } else if (room_code) {
        const supa = createServiceClient();
        const { data: room, error: roomErr } = await supa
          .from('rooms')
          .select('id')
          .eq('code', room_code)
          .single();
        if (roomErr) {
          if (roomErr.code === 'PGRST116') return createErrorResponse('Room not found', 404);
          throw new Error(`Failed to resolve room: ${roomErr.message}`);
        }
        resolvedRoomId = room.id;
      }

      if (!resolvedRoomId) return createErrorResponse('round_id or (room_id/room_code) required', 400);

      const supa = createServiceClient();
      const { data: latestRound, error: latestErr } = await supa
        .from('rounds')
        .select('id')
        .eq('room_id', resolvedRoomId)
        .eq('status', 'playing')
        .order('started_at', { ascending: false })
        .limit(1)
        .single();
      if (latestErr) {
        if (latestErr.code === 'PGRST116') return createErrorResponse('No active round', 400);
        throw new Error(`Failed to resolve active round: ${latestErr.message}`);
      }
      round_id = latestRound.id;
    }
    validateUUID(round_id!, 'round_id');
    validateUUID(user_id, 'user_id');
    validateGuess(guess);

    const normalized = normalizeText(guess);
    const supabase = createServiceClient();

    // 라운드/룸/사용자 유효성 확인
    const { data: round, error: roundError } = await supabase
      .from('rounds')
      .select('id, room_id, status, answer, winner_user_id')
      .eq('id', round_id)
      .single();
    if (roundError) {
      if (roundError.code === 'PGRST116') return createErrorResponse('Round not found', 404);
      throw new Error(`Failed to load round: ${roundError.message}`);
    }
    if (round.status !== 'playing') {
      return createErrorResponse('Round is not playing', 400);
    }

    // 룸 멤버인지 확인
    const { data: _player, error: playerError } = await supabase
      .from('players')
      .select('id')
      .eq('room_id', round.room_id)
      .eq('user_id', user_id)
      .single();
    if (playerError) {
      if (playerError.code === 'PGRST116') return createErrorResponse('Player not found in room', 403);
      throw new Error(`Failed to verify player: ${playerError.message}`);
    }

    const isCorrect = normalizeText(round.answer) === normalized;

    const result = await withTransaction(supabase, async (client) => {
      // 추측 저장
      const { data: guessRow, error: guessError } = await client
        .from('guesses')
        .insert([
          {
            round_id,
            user_id,
            text: guess,
            normalized_text: normalized,
            is_correct: isCorrect,
          },
        ])
        .select('id, created_at')
        .single();
      if (guessError) {
        // 동시성: 정답자 unique 충돌 시 409로 표준화
        if (guessError.message.includes('duplicate key value') || guessError.code === '23505') {
          throw new Error('CONFLICT_FIRST_WINNER');
        }
        throw new Error(`Failed to save guess: ${guessError.message}`);
      }

      let isWinner = false;
      let coinsEarned = 0;
      let roundStatus = 'playing';

      if (isCorrect) {
        // 일일 RECEIVE 캡 확인
        const startOfDay = new Date();
        startOfDay.setUTCHours(0, 0, 0, 0);
        const endOfDay = new Date(startOfDay.getTime() + 24 * 60 * 60 * 1000);
        const { count: receiveCountToday } = await client
          .from('coin_tx')
          .select('id', { count: 'exact', head: true })
          .eq('user_id', user_id)
          .eq('type', 'RECEIVE')
          .gte('created_at', startOfDay.toISOString())
          .lt('created_at', endOfDay.toISOString());
        if ((receiveCountToday ?? 0) >= BUSINESS_RULES.DAILY_RECEIVE_LIMIT) {
          // 캡에 걸려도 정답 제출은 성공 처리하되 보상만 0
          isWinner = true;
        }
        // 승자 업데이트 시도 (라운드당 1명)
        const { data: winnerUpdate, error: winnerError } = await client
          .from('rounds')
          .update({ winner_user_id: user_id, status: 'ended', ended_at: new Date().toISOString() })
          .eq('id', round_id as string)
          .is('winner_user_id', null)
          .select('id, status')
          .single();

        if (!winnerError && winnerUpdate) {
          // 내가 첫 승자
          isWinner = true;
          roundStatus = 'ended';
          if ((receiveCountToday ?? 0) < BUSINESS_RULES.DAILY_RECEIVE_LIMIT) {
            const idem = generateIdempotencyKey('RECEIVE', round_id as string, user_id as string);
            const { error: coinError } = await client
              .from('coin_tx')
              .insert([
                {
                  user_id,
                  type: 'RECEIVE',
                  amount: BUSINESS_RULES.RECEIVE_REWARD,
                  ref_round_id: round_id as string,
                  idem_key: idem,
                  created_by: 'edge:submit-guess',
                },
              ]);
            if (coinError && !coinError.message.includes('duplicate key')) {
              throw new Error(`Failed to award RECEIVE coins: ${coinError.message}`);
            }
            coinsEarned = BUSINESS_RULES.RECEIVE_REWARD;
          } else {
            coinsEarned = 0;
          }
        } else {
          // 이미 승자 존재 → 나는 패자
          roundStatus = 'ended';
        }
      }

      return { guessRow, isWinner, coinsEarned, roundStatus } as const;
    });

    const response: SubmitGuessResponse = {
      guess_id: result.guessRow.id as string,
      round_id: round_id as string,
      user_id: user_id as string,
      guess: guess as string,
      is_correct: isCorrect,
      is_winner: result.isWinner,
      coins_earned: result.coinsEarned,
      round_status: result.roundStatus,
      created_at: result.guessRow.created_at as string,
    };

    logInfo('Guess submitted', response);
    return createResponse(response, 201);
  } catch (e) {
    const error = e as Error;
    logError('Submit guess failed', error);

    if (error.message === 'CONFLICT_FIRST_WINNER') return createErrorResponse('Another player already won this round', 409);
    if (error.message.includes('MISSING_CONFIG')) return createErrorResponse(error.message, 500);
    if (error.message.includes('Failed to parse request body')) return createErrorResponse(error.message, 400);
    if (error.message.includes('Method') && error.message.includes('not allowed')) return createErrorResponse(error.message, 405);
    if (error.message.includes('is required') || error.message.includes('must be')) return createErrorResponse(error.message, 400);

    return createErrorResponse('Failed to submit guess', 500, { message: error.message });
  }
});



