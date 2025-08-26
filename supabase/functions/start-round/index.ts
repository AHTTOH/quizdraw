// QuizDraw Start Round Edge Function
// 개발 헌법 준수: 실제 구현만, 폴백/더미 데이터 절대 금지

import {
  createServiceClient,
  createResponse,
  createErrorResponse,
  handleCors,
  validateRequestMethod,
  parseRequestBody,
  validateAnswer,
  validateUUID,
  logInfo,
  logError,
  withTransaction,
  BUSINESS_RULES,
  generateIdempotencyKey
} from '../_shared/utils.ts';

interface StartRoundRequest {
  // 클라이언트는 room_code 또는 room_id 중 하나를 보낼 수 있음
  room_id?: string;
  room_code?: string;
  drawer_user_id: string;
  answer: string;
  drawing_storage_path: string;
  drawing_width: number;
  drawing_height: number;
}

interface StartRoundResponse {
  round_id: string;
  room_id: string;
  drawer_user_id: string;
  status: string;
  started_at: string;
  drawing_id: string;
  drawing_path: string;
}

Deno.serve(async (req: Request) => {
  // CORS 처리
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    // 요청 메소드 검증
    validateRequestMethod(req, ['POST']);

    // 요청 바디 파싱 및 검증
    const body = await parseRequestBody(req) as StartRoundRequest;
    
    let { 
      room_id, 
      room_code,
      drawer_user_id, 
      answer, 
      drawing_storage_path,
      drawing_width,
      drawing_height 
    } = body;

    // 입력 검증
    if (room_id) {
      validateUUID(room_id, 'room_id');
    }
    
    if (!room_id && room_code) {
      // room_code로 room_id 조회
      const supabaseLookup = createServiceClient();
      const { data: roomByCode, error: codeErr } = await supabaseLookup
        .from('rooms')
        .select('id')
        .eq('code', room_code)
        .single();
      if (codeErr) {
        if (codeErr.code === 'PGRST116') {
          return createErrorResponse('Room not found', 404);
        }
        throw new Error(`Failed to resolve room by code: ${codeErr.message}`);
      }
      room_id = roomByCode.id;
    }
    
    if (!room_id) {
      return createErrorResponse('room_id or room_code is required', 400);
    }
    validateUUID(drawer_user_id, 'drawer_user_id');
    validateAnswer(answer);

    if (!drawing_storage_path || typeof drawing_storage_path !== 'string') {
      throw new Error('drawing_storage_path is required and must be a string');
    }

    if (!drawing_width || !drawing_height || drawing_width < 64 || drawing_height < 64 || 
        drawing_width > 4096 || drawing_height > 4096) {
      throw new Error('drawing dimensions must be between 64 and 4096 pixels');
    }

    logInfo('Starting round', { room_id, drawer_user_id, answer });

    // Supabase 클라이언트 생성
    const supabase = createServiceClient();

    // 룸 존재 및 상태 확인
    const { data: room, error: roomError } = await supabase
      .from('rooms')
      .select('id, status, created_by')
      .eq('id', room_id)
      .single();

    if (roomError) {
      if (roomError.code === 'PGRST116') {
        return createErrorResponse('Room not found', 404);
      }
      throw new Error(`Failed to find room: ${roomError.message}`);
    }

    if (room.status === 'ended') {
      return createErrorResponse('Room has ended', 400);
    }

    // 그림 그린이가 룸 멤버인지 확인
    const { data: player, error: playerError } = await supabase
      .from('players')
      .select('id, user_id, nickname')
      .eq('room_id', room_id)
      .eq('user_id', drawer_user_id)
      .single();

    if (playerError) {
      if (playerError.code === 'PGRST116') {
        return createErrorResponse('Player not found in room', 403);
      }
      throw new Error(`Failed to verify player: ${playerError.message}`);
    }

    // 현재 진행중인 라운드가 있는지 확인
    const { data: activeRound, error: activeRoundError } = await supabase
      .from('rounds')
      .select('id, status')
      .eq('room_id', room_id)
      .eq('status', 'playing')
      .single();

    if (activeRound && !activeRoundError) {
      return createErrorResponse('Another round is already in progress', 400);
    }

    // 룸의 라운드 수 확인
    const { data: roundsCount, error: countError } = await supabase
      .from('rounds')
      .select('id', { count: 'exact' })
      .eq('room_id', room_id);

    if (countError) {
      throw new Error(`Failed to count rounds: ${countError.message}`);
    }

    if ((roundsCount?.length || 0) >= BUSINESS_RULES.MAX_ROUNDS_PER_ROOM) {
      return createErrorResponse(`Maximum rounds per room exceeded (${BUSINESS_RULES.MAX_ROUNDS_PER_ROOM})`, 400);
    }

    // 트랜잭션으로 라운드와 그림 생성
    const result = await withTransaction(supabase, async (client) => {
      // 라운드 생성
      const { data: round, error: roundError } = await client
        .from('rounds')
        .insert([{
          room_id: room_id,
          drawer_user_id: drawer_user_id,
          answer: answer,
          status: 'playing'
        }])
        .select('id, room_id, drawer_user_id, answer, status, started_at')
        .single();

      if (roundError) {
        throw new Error(`Failed to create round: ${roundError.message}`);
      }

      // 그림 정보 저장
      const { data: drawing, error: drawingError } = await client
        .from('drawings')
        .insert([{
          round_id: round.id,
          storage_path: drawing_storage_path,
          width: drawing_width,
          height: drawing_height
        }])
        .select('id, round_id, storage_path, width, height, created_at')
        .single();

      if (drawingError) {
        throw new Error(`Failed to save drawing: ${drawingError.message}`);
      }

      // 룸 상태를 playing으로 변경
      const { error: updateRoomError } = await client
        .from('rooms')
        .update({ status: 'playing' })
        .eq('id', room_id);

      if (updateRoomError) {
        throw new Error(`Failed to update room status: ${updateRoomError.message}`);
      }

      // SEND 보상 지급 (드로어에게)
      const sendIdempotencyKey = generateIdempotencyKey('SEND', round.id, drawer_user_id);
      // 일일 SEND 캡 확인
      const startOfDay = new Date();
      startOfDay.setUTCHours(0, 0, 0, 0);
      const endOfDay = new Date(startOfDay.getTime() + 24 * 60 * 60 * 1000);
      const { count: sendCountToday } = await client
        .from('coin_tx')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', drawer_user_id)
        .eq('type', 'SEND')
        .gte('created_at', startOfDay.toISOString())
        .lt('created_at', endOfDay.toISOString());
      if ((sendCountToday ?? 0) >= BUSINESS_RULES.DAILY_SEND_LIMIT) {
        throw new Error('DAILY_SEND_LIMIT_REACHED');
      }

      const { error: coinError } = await client
        .from('coin_tx')
        .insert([{
          user_id: drawer_user_id,
          type: 'SEND',
          amount: BUSINESS_RULES.SEND_REWARD,
          ref_round_id: round.id,
          idem_key: sendIdempotencyKey,
          created_by: 'edge:start-round'
        }]);

      if (coinError && !coinError.message.includes('duplicate key value')) {
        // Idempotency 키 중복이 아닌 경우만 에러로 처리
        throw new Error(`Failed to award SEND coins: ${coinError.message}`);
      }

      return {
        round: round,
        drawing: drawing
      };
    });

    const response: StartRoundResponse = {
      round_id: result.round.id,
      room_id: result.round.room_id,
      drawer_user_id: result.round.drawer_user_id,
      status: result.round.status,
      started_at: result.round.started_at,
      drawing_id: result.drawing.id,
      drawing_path: result.drawing.storage_path
    };

    logInfo('Round started successfully', response);

    return createResponse(response, 201);

  } catch (error) {
    logError('Start round failed', error);
    
    if (error.message.includes('MISSING_CONFIG')) {
      return createErrorResponse(error.message, 500);
    }
    
    if (error.message.includes('Failed to parse request body')) {
      return createErrorResponse(error.message, 400);
    }
    
    if (error.message.includes('Method') && error.message.includes('not allowed')) {
      return createErrorResponse(error.message, 405);
    }
    
    if (error.message.includes('is required') || error.message.includes('must be')) {
      return createErrorResponse(error.message, 400);
    }

    return createErrorResponse('Failed to start round', 500, { 
      message: error.message 
    });
  }
});
