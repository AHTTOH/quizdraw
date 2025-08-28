// QuizDraw Start Round Edge Function
// 개발 헌법 준수: 실제 구현만, 폴백/더미 데이터 절대 금지

import {
  createServiceClient,
  createResponse,
  createErrorResponse,
  handleCors,
  validateRequestMethod,
  parseRequestBody,
  validateUUID,
  validateAnswer,
  validateRoomCode,
  logInfo,
  logError,
  BUSINESS_RULES
} from '../_shared/utils.ts';

interface StartRoundRequest {
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
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    validateRequestMethod(req, ['POST']);
    const body = await parseRequestBody(req) as StartRoundRequest;
    
    const { room_id, room_code, drawer_user_id, answer, drawing_storage_path, drawing_width, drawing_height } = body;

    validateUUID(drawer_user_id, 'drawer_user_id');
    validateAnswer(answer);

    if (!room_id && !room_code) {
      throw new Error('Either room_id or room_code is required');
    }

    if (room_code) {
      validateRoomCode(room_code);
    }

    const supabase = createServiceClient();

    // 룸 조회
    let room;
    if (room_id) {
      const { data, error } = await supabase
        .from('rooms')
        .select('*')
        .eq('id', room_id)
        .single();
      if (error) throw new Error(`Room not found: ${error.message}`);
      room = data;
    } else {
      const { data, error } = await supabase
        .from('rooms')
        .select('*')
        .eq('code', room_code)
        .single();
      if (error) throw new Error(`Room not found: ${error.message}`);
      room = data;
    }

    // 룸 상태 확인
    if (room.status !== 'waiting') {
      return createErrorResponse('Room is not in waiting status', 400);
    }

    // 그림 정보 저장
    const { data: drawing, error: drawingError } = await supabase
      .from('drawings')
      .insert([{
        round_id: 'temp',  // 라운드 생성 후 업데이트
        storage_path: drawing_storage_path,
        width: drawing_width,
        height: drawing_height
      }])
      .select('*')
      .single();

    if (drawingError) {
      throw new Error(`Failed to save drawing: ${drawingError.message}`);
    }

    // 라운드 생성
    const { data: round, error: roundError } = await supabase
      .from('rounds')
      .insert([{
        room_id: room.id,
        drawer_user_id,
        answer: answer.trim(),
        status: 'playing'
      }])
      .select('*')
      .single();

    if (roundError) {
      throw new Error(`Failed to create round: ${roundError.message}`);
    }

    // 그림의 round_id 업데이트
    await supabase
      .from('drawings')
      .update({ round_id: round.id })
      .eq('id', drawing.id);

    // 룸 상태를 'playing'으로 변경
    await supabase
      .from('rooms')
      .update({ status: 'playing' })
      .eq('id', room.id);

    const response: StartRoundResponse = {
      round_id: round.id,
      room_id: room.id,
      drawer_user_id: round.drawer_user_id,
      status: round.status,
      started_at: round.started_at,
      drawing_id: drawing.id,
      drawing_path: drawing.storage_path
    };

    logInfo('Round started successfully', response);
    return createResponse(response, 201);

  } catch (error) {
    logError('Start round failed', error);
    return createErrorResponse('Failed to start round', 500, { 
      message: error.message 
    });
  }
});
