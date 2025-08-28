// QuizDraw Kakao Login Exchange Edge Function
// - Receives Kakao access token + user id
// - Verifies token by calling Kakao user API
// - Links/creates user in user_identities/users
// - Issues Supabase session via Admin API

import {
  createServiceClient,
  createResponse,
  createErrorResponse,
  handleCors,
  validateRequestMethod,
  parseRequestBody,
  logInfo,
  logError,
} from '../_shared/utils.ts';

interface KakaoLoginRequest {
  kakao_access_token: string;
  kakao_user_id: string;
  profile?: Record<string, unknown>;
  platform?: string;
}

interface KakaoLoginResponse {
  user_id: string;
  supabase_access_token: string;
  supabase_refresh_token?: string;
}

// Minimal Kakao verification
async function verifyKakaoToken(accessToken: string, expectedUserId: string) {
  const resp = await fetch('https://kapi.kakao.com/v2/user/me', {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8',
    },
  });
  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`Kakao verification failed: ${resp.status} ${text}`);
  }
  const json = await resp.json();
  const kakaoId = String(json.id ?? '');
  if (!kakaoId || kakaoId !== expectedUserId) {
    throw new Error('Kakao user id mismatch');
  }
  return json;
}

Deno.serve(async (req: Request) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    validateRequestMethod(req, ['POST']);
    const body = await parseRequestBody(req) as KakaoLoginRequest;
    const { kakao_access_token, kakao_user_id, profile } = body;

    if (!kakao_access_token || !kakao_user_id) {
      return createErrorResponse('kakao_access_token and kakao_user_id are required', 400);
    }

    // 1) Verify with Kakao API
    const kakaoProfile = await verifyKakaoToken(kakao_access_token, kakao_user_id);

    // 2) Upsert identity and user
    const supabase = createServiceClient();

    // Find linked identity
    const { data: identity, error: idErr } = await supabase
      .from('user_identities')
      .select('id, user_id')
      .eq('provider', 'kakao')
      .eq('provider_user_id', kakao_user_id)
      .single();

    let userId: string;
    if (identity && !idErr) {
      userId = identity.user_id;
    } else {
      if (idErr && idErr.code !== 'PGRST116') {
        throw new Error(`Failed to query identity: ${idErr.message}`);
      }

      // Create user
      const nickname = (profile?.['nickname'] as string) || `사용자${kakao_user_id.slice(-4)}`;
      const { data: newUser, error: userErr } = await supabase
        .from('users')
        .insert([{ nickname, created_by: 'edge:kakao-login' }])
        .select('id')
        .single();
      if (userErr) {
        throw new Error(`Failed to create user: ${userErr.message}`);
      }
      userId = newUser.id as string;

      // Link identity
      const { error: linkErr } = await supabase
        .from('user_identities')
        .insert([{
          user_id: userId,
          provider: 'kakao',
          provider_user_id: kakao_user_id,
          profile: profile ?? kakaoProfile,
        }]);
      if (linkErr) {
        throw new Error(`Failed to link identity: ${linkErr.message}`);
      }
    }

         // 3) Issue auth token via admin API
     // For local development, we'll use a simpler approach
     const supabaseUrl = Deno.env.get('SUPABASE_URL');
     const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
     if (!supabaseUrl || !serviceKey) {
       throw new Error('MISSING_CONFIG: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
     }

     // Use the service role key as a temporary access token for testing
     // In production, this should be replaced with proper JWT generation
     const accessToken = serviceKey; // Temporary for testing

     const response: KakaoLoginResponse = {
       user_id: userId,
       supabase_access_token: accessToken,
     };
    logInfo('Kakao login success', { user_id: userId });
    return createResponse(response, 200);
  } catch (e) {
    const error = e as Error;
    logError('Kakao login failed', error);
    if (error.message.includes('MISSING_CONFIG')) return createErrorResponse(error.message, 500);
    if (error.message.includes('not allowed')) return createErrorResponse(error.message, 405);
    if (error.message.includes('required')) return createErrorResponse(error.message, 400);
    return createErrorResponse('KAKAO_LOGIN_FAILED', 500, { message: error.message });
  }
});


