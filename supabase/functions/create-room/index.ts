// QuizDraw Create Room Edge Function
// 개발 헌법 준수: 실제 구현만, 폴백/더미 데이터 절대 금지

import {
  createServiceClient,
  generateRoomCode,
  createResponse,
  createErrorResponse,
  handleCors,
  validateRequestMethod,
  parseRequestBody,
  validateNickname,
  validateUUID,
  logInfo,
  logError,
  BUSINESS_RULES
} from '../_shared/utils.ts';

interface CreateRoomRequest {
  creator_user_id: string;
  creator_nickname: string;
}

interface CreateRoomResponse {
  room_id: string;
  room_code: string;
  creator_user_id: string;
  status: string;
  created_at: string;
}

Deno.serve(async (req: Request) => {
  // CORS 처리
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    // 요청 메소드 검증
    validateRequestMethod(req, ['POST']);

    // 요청 바디 파싱 및 검증
    const body = await parseRequestBody(req) as CreateRoomRequest;
    
    const { creator_user_id, creator_nickname } = body;

    // 입력 검증
    validateUUID(creator_user_id, 'creator_user_id');
    validateNickname(creator_nickname);

    logInfo('Creating room', { creator_user_id, creator_nickname });

    // Supabase 클라이언트 생성
    const supabase = createServiceClient();

    // 사용자가 존재하는지 확인, 없으면 생성
    let user = null;
    const { data: existingUser, error: userError } = await supabase
      .from('users')
      .select('id, nickname')
      .eq('id', creator_user_id)
      .single();

    if (userError && userError.code === 'PGRST116') {
      // 사용자가 없으면 생성
      const { data: newUser, error: createUserError } = await supabase
        .from('users')
        .insert([{
          id: creator_user_id,
          nickname: creator_nickname,
          created_by: 'edge:create-room'
        }])
        .select('id, nickname')
        .single();

      if (createUserError) {
        throw new Error(`Failed to create user: ${createUserError.message}`);
      }

      user = newUser;
      logInfo('Created new user', { user_id: creator_user_id });
    } else if (userError) {
      throw new Error(`Failed to check user: ${userError.message}`);
    } else {
      user = existingUser;
    }

    // 고유한 룸 코드 생성 (최대 5회 시도)
    let roomCode = '';
    let attempts = 0;
    const maxAttempts = 5;

    while (attempts < maxAttempts) {
      roomCode = generateRoomCode();
      
      const { data: existingRoom, error: checkError } = await supabase
        .from('rooms')
        .select('id')
        .eq('code', roomCode)
        .single();

      if (checkError && checkError.code === 'PGRST116') {
        // 룸이 없으면 사용 가능한 코드
        break;
      } else if (checkError) {
        throw new Error(`Failed to check room code uniqueness: ${checkError.message}`);
      }

      attempts++;
    }

    if (attempts >= maxAttempts) {
      throw new Error('Failed to generate unique room code after maximum attempts');
    }

    // 룸 생성
    const { data: room, error: roomError } = await supabase
      .from('rooms')
      .insert([{
        code: roomCode,
        status: 'waiting',
        created_by: creator_user_id
      }])
      .select('id, code, status, created_by, created_at')
      .single();

    if (roomError) {
      throw new Error(`Failed to create room: ${roomError.message}`);
    }

    // 생성자를 플레이어로 추가
    const { error: playerError } = await supabase
      .from('players')
      .insert([{
        room_id: room.id,
        user_id: creator_user_id,
        nickname: creator_nickname,
        score: 0
      }]);

    if (playerError) {
      // 룸 생성은 성공했지만 플레이어 추가 실패
      logError('Failed to add creator as player', { room_id: room.id, error: playerError });
      
      // 룸 삭제 (정리)
      await supabase
        .from('rooms')
        .delete()
        .eq('id', room.id);

      throw new Error(`Failed to add creator as player: ${playerError.message}`);
    }

    const response: CreateRoomResponse = {
      room_id: room.id,
      room_code: room.code,
      creator_user_id: room.created_by,
      status: room.status,
      created_at: room.created_at
    };

    logInfo('Room created successfully', response);

    return createResponse(response, 201);

  } catch (error) {
    logError('Create room failed', error);
    
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

    return createErrorResponse('Failed to create room', 500, { 
      message: error.message 
    });
  }
});
