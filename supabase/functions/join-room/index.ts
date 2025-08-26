// QuizDraw Join Room Edge Function
// 개발 헌법 준수: 실제 구현만, 폴백/더미 데이터 절대 금지

import {
  createServiceClient,
  createResponse,
  createErrorResponse,
  handleCors,
  validateRequestMethod,
  parseRequestBody,
  validateNickname,
  validateUUID,
  validateRoomCode,
  logInfo,
  logError,
  BUSINESS_RULES
} from '../_shared/utils.ts';

interface JoinRoomRequest {
  room_code: string;
  user_id: string;
  nickname: string;
}

interface JoinRoomResponse {
  room_id: string;
  room_code: string;
  user_id: string;
  nickname: string;
  player_count: number;
  room_status: string;
  joined_at: string;
}

Deno.serve(async (req: Request) => {
  // CORS 처리
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    // 요청 메소드 검증
    validateRequestMethod(req, ['POST']);

    // 요청 바디 파싱 및 검증
    const body = await parseRequestBody(req) as JoinRoomRequest;
    
    const { room_code, user_id, nickname } = body;

    // 입력 검증
    validateRoomCode(room_code);
    validateUUID(user_id, 'user_id');
    validateNickname(nickname);

    logInfo('Joining room', { room_code, user_id, nickname });

    // Supabase 클라이언트 생성
    const supabase = createServiceClient();

    // 룸이 존재하고 참가 가능한 상태인지 확인
    const { data: room, error: roomError } = await supabase
      .from('rooms')
      .select('id, code, status, created_by, created_at')
      .eq('code', room_code)
      .single();

    if (roomError) {
      if (roomError.code === 'PGRST116') {
        return createErrorResponse('Room not found', 404);
      }
      throw new Error(`Failed to find room: ${roomError.message}`);
    }

    // 룸 상태 확인
    if (room.status === 'ended') {
      return createErrorResponse('Room has ended', 400);
    }

    // 현재 플레이어 수 확인
    const { data: players, error: playersError } = await supabase
      .from('players')
      .select('id, user_id, nickname')
      .eq('room_id', room.id);

    if (playersError) {
      throw new Error(`Failed to get players: ${playersError.message}`);
    }

    // 이미 참가한 사용자인지 확인
    const existingPlayer = players.find(p => p.user_id === user_id);
    if (existingPlayer) {
      // 이미 참가한 경우 현재 정보 반환
      const response: JoinRoomResponse = {
        room_id: room.id,
        room_code: room.code,
        user_id: user_id,
        nickname: existingPlayer.nickname,
        player_count: players.length,
        room_status: room.status,
        joined_at: new Date().toISOString()
      };

      logInfo('User already in room', response);
      return createResponse(response, 200);
    }

    // 룸 정원 확인
    if (players.length >= BUSINESS_RULES.MAX_ROOM_PLAYERS) {
      return createErrorResponse(`Room is full (max ${BUSINESS_RULES.MAX_ROOM_PLAYERS} players)`, 400);
    }

    // 사용자가 존재하는지 확인, 없으면 생성
    let user = null;
    const { data: existingUser, error: userError } = await supabase
      .from('users')
      .select('id, nickname')
      .eq('id', user_id)
      .single();

    if (userError && userError.code === 'PGRST116') {
      // 사용자가 없으면 생성
      const { data: newUser, error: createUserError } = await supabase
        .from('users')
        .insert([{
          id: user_id,
          nickname: nickname,
          created_by: 'edge:join-room'
        }])
        .select('id, nickname')
        .single();

      if (createUserError) {
        throw new Error(`Failed to create user: ${createUserError.message}`);
      }

      user = newUser;
      logInfo('Created new user', { user_id });
    } else if (userError) {
      throw new Error(`Failed to check user: ${userError.message}`);
    } else {
      user = existingUser;
    }

    // 플레이어 추가
    const { data: newPlayer, error: playerError } = await supabase
      .from('players')
      .insert([{
        room_id: room.id,
        user_id: user_id,
        nickname: nickname,
        score: 0
      }])
      .select('id, user_id, nickname, score, last_seen')
      .single();

    if (playerError) {
      throw new Error(`Failed to join room: ${playerError.message}`);
    }

    const response: JoinRoomResponse = {
      room_id: room.id,
      room_code: room.code,
      user_id: user_id,
      nickname: nickname,
      player_count: players.length + 1,
      room_status: room.status,
      joined_at: new Date().toISOString()
    };

    logInfo('Room joined successfully', response);

    return createResponse(response, 201);

  } catch (error) {
    logError('Join room failed', error);
    
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

    return createErrorResponse('Failed to join room', 500, { 
      message: error.message 
    });
  }
});
