// QuizDraw Get Gallery Edge Function
// - Returns my drawings and friends' drawings related to rooms I joined

import {
  createServiceClient,
  createResponse,
  createErrorResponse,
  handleCors,
  validateRequestMethod,
  parseRequestBody,
  validateUUID,
  logError,
} from '../_shared/utils.ts';

interface GetGalleryRequest {
  user_id: string;
  limit?: number;
}

interface GalleryItem {
  drawing_id: string;
  storage_path: string;
  room_id: string;
  round_id: string;
  drawer_user_id: string;
  created_at: string;
}

interface GetGalleryResponse {
  my_drawings: GalleryItem[];
  friends_drawings: GalleryItem[];
}

Deno.serve(async (req: Request) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    validateRequestMethod(req, ['POST']);
    const { user_id, limit } = await parseRequestBody(req) as GetGalleryRequest;
    validateUUID(user_id, 'user_id');
    const pageSize = typeof limit === 'number' && limit > 0 && limit <= 100 ? limit : 30;

    const supabase = createServiceClient();

    // 내가 참여한 방 목록
    const { data: myRooms, error: roomErr } = await supabase
      .from('players')
      .select('room_id')
      .eq('user_id', user_id);
    if (roomErr) throw new Error(`Failed to load my rooms: ${roomErr.message}`);
    const roomIds = (myRooms ?? []).map((r: any) => r.room_id);
    if (roomIds.length === 0) {
      return createResponse({ my_drawings: [], friends_drawings: [] } as GetGalleryResponse, 200);
    }

    // 내 그림
    const { data: myDrawings, error: myErr } = await supabase
      .from('drawings')
      .select('id, round_id, storage_path, created_at, rounds!inner(room_id, drawer_user_id)')
      .eq('rounds.drawer_user_id', user_id)
      .in('rounds.room_id', roomIds)
      .order('created_at', { ascending: false })
      .limit(pageSize);
    if (myErr) throw new Error(`Failed to load my drawings: ${myErr.message}`);

    // 친구 그림 (같은 방, 내가 아닌 사람의 그림)
    const { data: friendDrawings, error: frErr } = await supabase
      .from('drawings')
      .select('id, round_id, storage_path, created_at, rounds!inner(room_id, drawer_user_id)')
      .neq('rounds.drawer_user_id', user_id)
      .in('rounds.room_id', roomIds)
      .order('created_at', { ascending: false })
      .limit(pageSize);
    if (frErr) throw new Error(`Failed to load friends drawings: ${frErr.message}`);

    const mapItem = (d: any): GalleryItem => ({
      drawing_id: d.id,
      storage_path: d.storage_path,
      room_id: d.rounds.room_id,
      round_id: d.round_id,
      drawer_user_id: d.rounds.drawer_user_id,
      created_at: d.created_at,
    });

    return createResponse({
      my_drawings: (myDrawings ?? []).map(mapItem),
      friends_drawings: (friendDrawings ?? []).map(mapItem),
    } as GetGalleryResponse, 200);
  } catch (e) {
    const error = e as Error;
    logError('Get gallery failed', error);
    if (error.message.includes('not allowed')) return createErrorResponse(error.message, 405);
    if (error.message.includes('required') || error.message.includes('must be')) return createErrorResponse(error.message, 400);
    return createErrorResponse('GET_GALLERY_FAILED', 500, { message: error.message });
  }
});


