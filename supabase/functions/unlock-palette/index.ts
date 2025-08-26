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
  logInfo,
  logError,
  withTransaction,
  generateIdempotencyKey
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
  // CORS 처리
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    // 요청 메소드 검증
    validateRequestMethod(req, ['POST']);

    // 요청 바디 파싱 및 검증
    const body = await parseRequestBody(req) as UnlockPaletteRequest;
    
    const { user_id, palette_id } = body;

    // 입력 검증
    validateUUID(user_id, 'user_id');
    validateUUID(palette_id, 'palette_id');

    logInfo('Unlocking palette', { user_id, palette_id });

    // Supabase 클라이언트 생성
    const supabase = createServiceClient();

    // 사용자 존재 확인
    const { data: user, error: userError } = await supabase
      .from('users')
      .select('id, nickname')
      .eq('id', user_id)
      .single();

    if (userError) {
      if (userError.code === 'PGRST116') {
        return createErrorResponse('User not found', 404);
      }
      throw new Error(`Failed to find user: ${userError.message}`);
    }

    // 팔레트 존재 확인
    const { data: palette, error: paletteError } = await supabase
      .from('palettes')
      .select('id, name, swatches, price_coins, is_colorblind_safe')
      .eq('id', palette_id)
      .single();

    if (paletteError) {
      if (paletteError.code === 'PGRST116') {
        return createErrorResponse('Palette not found', 404);
      }
      throw new Error(`Failed to find palette: ${paletteError.message}`);
    }

    // 이미 해금된 팔레트인지 확인
    const { data: existingUnlock, error: unlockCheckError } = await supabase
      .from('user_palettes')
      .select('id, unlocked_at')
      .eq('user_id', user_id)
      .eq('palette_id', palette_id)
      .single();

    if (existingUnlock && !unlockCheckError) {
      const response: UnlockPaletteResponse = {
        success: true,
        palette_id: palette.id,
        palette_name: palette.name,
        price_paid: 0, // 이미 해금됨
        remaining_balance: 0, // 현재 잔액은 별도 조회 필요
        unlocked_at: existingUnlock.unlocked_at
      };

      // 현재 잔액 조회
      const { data: balance } = await supabase
        .from('coin_balances')
        .select('balance')
        .eq('user_id', user_id)
        .single();

      response.remaining_balance = balance?.balance || 0;

      logInfo('Palette already unlocked', response);
      return createResponse(response, 200);
    }

    // 현재 잔액 확인
    const { data: balanceData, error: balanceError } = await supabase
      .from('coin_balances')
      .select('balance')
      .eq('user_id', user_id)
      .single();

    if (balanceError && balanceError.code !== 'PGRST116') {
      throw new Error(`Failed to get balance: ${balanceError.message}`);
    }

    const currentBalance = balanceData?.balance || 0;

    // 잔액 부족 확인
    if (currentBalance < palette.price_coins) {
      return createErrorResponse(
        `Insufficient coins. Required: ${palette.price_coins}, Available: ${currentBalance}`, 
        400
      );
    }

    // 무료 팔레트가 아닌 경우에만 차감 처리
    let pricePaid = 0;
    let remainingBalance = currentBalance;

    // 트랜잭션으로 해금 처리
    const result = await withTransaction(supabase, async (client) => {
      // 팔레트 해금 기록
      const { data: unlock, error: unlockError } = await client
        .from('user_palettes')
        .insert([{
          user_id: user_id,
          palette_id: palette_id
        }])
        .select('id, user_id, palette_id, unlocked_at')
        .single();

      if (unlockError) {
        if (unlockError.message.includes('duplicate key')) {
          // 동시 요청으로 인한 중복
          throw new Error('ALREADY_UNLOCKED');
        }
        throw new Error(`Failed to unlock palette: ${unlockError.message}`);
      }

      // 무료가 아닌 경우 코인 차감
      if (palette.price_coins > 0) {
        const redeemIdempotencyKey = generateIdempotencyKey(
          'REDEEM', 
          palette_id, 
          user_id, 
          unlock.unlocked_at
        );

        const { error: coinError } = await client
          .from('coin_tx')
          .insert([{
            user_id: user_id,
            type: 'REDEEM',
            amount: -palette.price_coins, // 음수로 차감
            ref_round_id: null,
            ref_ad_tx_id: null,
            idem_key: redeemIdempotencyKey,
            created_by: 'edge:unlock-palette'
          }]);

        if (coinError) {
          if (coinError.message.includes('duplicate key')) {
            // 코인은 이미 차감되었지만 해금은 새로 기록됨
            logWarning('Coins already deducted but unlock was new', { 
              palette_id, 
              user_id 
            });
          } else {
            throw new Error(`Failed to deduct coins: ${coinError.message}`);
          }
        }

        pricePaid = palette.price_coins;
        remainingBalance = currentBalance - palette.price_coins;
      }

      return unlock;
    });

    const response: UnlockPaletteResponse = {
      success: true,
      palette_id: palette.id,
      palette_name: palette.name,
      price_paid: pricePaid,
      remaining_balance: remainingBalance,
      unlocked_at: result.unlocked_at
    };

    logInfo('Palette unlocked successfully', {
      ...response,
      user_nickname: user.nickname
    });

    return createResponse(response, 201);

  } catch (error) {
    logError('Unlock palette failed', error);
    
    if (error.message === 'ALREADY_UNLOCKED') {
      return createErrorResponse('Palette already unlocked', 409);
    }
    
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

    return createErrorResponse('Failed to unlock palette', 500, { 
      message: error.message 
    });
  }
});

function logWarning(message: string, data?: any) {
  console.warn(`[WARNING] ${new Date().toISOString()} - ${message}`, data ? JSON.stringify(data) : '');
}
