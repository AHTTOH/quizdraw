// QuizDraw Unlock Palette Edge Function
// 개발 헌법 준수: 실제 구현만, 폴백/더미 데이터 절대 금지

import {
  createServiceClient,
  createResponse,
  createErrorResponse,
  handleCors,
  validateRequestMethod,
  parseRequestBody,
  validateUUID,
  generateIdempotencyKey,
  logInfo,
  logError
} from '../_shared/utils.ts';

interface UnlockPaletteRequest {
  user_id: string;
  palette_id: string;
}

interface UnlockPaletteResponse {
  success: boolean;
  palette_id: string;
  palette_name: string;
  price_paid: number;
  remaining_balance: number;
  unlocked_at: string;
}

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    validateRequestMethod(req, ['POST']);
    const body = await parseRequestBody(req) as UnlockPaletteRequest;
    
    const { user_id, palette_id } = body;

    validateUUID(user_id, 'user_id');
    validateUUID(palette_id, 'palette_id');

    const supabase = createServiceClient();

    // 팔레트 정보 조회
    const { data: palette, error: paletteError } = await supabase
      .from('palettes')
      .select('*')
      .eq('id', palette_id)
      .single();

    if (paletteError) {
      return createErrorResponse('Palette not found', 404);
    }

    // 이미 해금했는지 확인
    const { data: existingUnlock, error: checkError } = await supabase
      .from('user_palettes')
      .select('id')
      .eq('user_id', user_id)
      .eq('palette_id', palette_id)
      .single();

    if (existingUnlock) {
      return createErrorResponse('Palette already unlocked', 400);
    }

    // 무료 팔레트인 경우
    if (palette.price_coins === 0) {
      const { data: unlock, error: unlockError } = await supabase
        .from('quizdraw_user_palettes')  // ✅ 수정
        .insert([{
          user_id,
          palette_id,
          unlocked_at: new Date().toISOString()
        }])
        .select('*')
        .single();

      if (unlockError) {
        throw new Error(`Failed to unlock free palette: ${unlockError.message}`);
      }

      const response: UnlockPaletteResponse = {
        success: true,
        palette_id,
        palette_name: palette.name,
        price_paid: 0,
        remaining_balance: 0,
        unlocked_at: unlock.unlocked_at
      };

      return createResponse(response, 201);
    }

    // 유료 팔레트인 경우 - 현재 코인 잔액 확인
    const { data: coinTx, error: balanceError } = await supabase
      .from('coin_tx')
      .select('amount')
      .eq('user_id', user_id);

    if (balanceError) {
      throw new Error(`Failed to get balance: ${balanceError.message}`);
    }

    const currentBalance = coinTx.reduce((sum, tx) => sum + tx.amount, 0);

    if (currentBalance < palette.price_coins) {
      return createErrorResponse(
        `Insufficient coins. Required: ${palette.price_coins}, Available: ${currentBalance}`, 
        400
      );
    }

    // 트랜잭션으로 코인 차감 및 팔레트 해금
    const idempotencyKey = generateIdempotencyKey('REDEEM', palette_id, user_id);
    
    // 코인 차감
    const { error: deductError } = await supabase
      .from('coin_tx')
      .insert([{
        user_id,
        type: 'REDEEM',
        amount: -palette.price_coins,  // 음수로 차감
        idem_key: idempotencyKey,
        created_by: 'edge:unlock-palette'
      }]);

    if (deductError) {
      if (deductError.message.includes('unique')) {
        return createErrorResponse('Palette purchase already in progress', 400);
      }
      throw new Error(`Failed to deduct coins: ${deductError.message}`);
    }

    // 팔레트 해금
    const { data: unlock, error: unlockError } = await supabase
      .from('user_palettes')
      .insert([{
        user_id,
        palette_id,
        unlocked_at: new Date().toISOString()
      }])
      .select('*')
      .single();

    if (unlockError) {
      // 팔레트 해금 실패 시 코인 차감 롤백
      await supabase
        .from('coin_tx')
        .delete()
        .eq('idem_key', idempotencyKey);
      
      throw new Error(`Failed to unlock palette: ${unlockError.message}`);
    }

    const response: UnlockPaletteResponse = {
      success: true,
      palette_id,
      palette_name: palette.name,
      price_paid: palette.price_coins,
      remaining_balance: currentBalance - palette.price_coins,
      unlocked_at: unlock.unlocked_at
    };

    logInfo('Palette unlocked successfully', response);
    return createResponse(response, 201);

  } catch (error) {
    logError('Unlock palette failed', error);
    return createErrorResponse('Failed to unlock palette', 500, { 
      message: error.message 
    });
  }
});
