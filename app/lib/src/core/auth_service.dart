import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;
import 'package:supabase_flutter/supabase_flutter.dart';

/// 실제 카카오 로그인 → 액세스 토큰 획득 → 엣지함수 교환 → Supabase 세션 수립
class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<Session> signInWithKakao() async {
    // 1) 카카오 토큰 확보 (웹/네이티브 분기)
    kakao.OAuthToken kakaoToken;
    if (kIsWeb) {
      // 웹: JavaScript SDK 기반 (kakao_flutter_sdk가 래핑)
      kakaoToken = await kakao.UserApi.instance.loginWithKakaoAccount();
    } else {
      final bool isKakaoTalkInstalled = await kakao.isKakaoTalkInstalled();
      if (isKakaoTalkInstalled) {
        kakaoToken = await kakao.UserApi.instance.loginWithKakaoTalk();
      } else {
        kakaoToken = await kakao.UserApi.instance.loginWithKakaoAccount();
      }
    }

    // 2) 사용자 정보 조회 (provider_user_id 확보)
    final kakaoUser = await kakao.UserApi.instance.me();
    final kakaoUserId = kakaoUser.id?.toString() ?? '';
    if (kakaoUserId.isEmpty) {
      throw Exception('Kakao user id is empty');
    }

    // 3) 엣지 함수로 교환 요청 (서비스 키 내부 검증 → 세션 토큰 반환)
    final res = await _client.functions.invoke(
      'kakao-login',
      body: {
        'kakao_access_token': kakaoToken.accessToken,
        'kakao_user_id': kakaoUserId,
        'profile': {
          'nickname': kakaoUser.kakaoAccount?.profile?.nickname,
          'thumbnailImageUrl': kakaoUser.kakaoAccount?.profile?.thumbnailImageUrl,
          'profileImageUrl': kakaoUser.kakaoAccount?.profile?.profileImageUrl,
        },
        'platform': kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other')),
      },
    );

    final data = res.data as Map<String, dynamic>?;
    if (data == null || data['supabase_access_token'] == null) {
      throw Exception('로그인 교환 실패: invalid response from kakao-login');
    }

    final String accessToken = data['supabase_access_token'] as String;
    final String? refreshToken = data['supabase_refresh_token'] as String?;

    // 4) Supabase 세션 설정
    // AuthSession 대신 직접 토큰 설정
    await _client.auth.setSession(accessToken);
    
    // 세션 확인
    final session = _client.auth.currentSession;
    if (session == null) {
      throw Exception('Supabase 세션 설정 실패');
    }

    return session;
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }
}


