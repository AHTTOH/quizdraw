import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';
import 'admob_service.dart';

class Bootstrap {
  static Future<void> initialize() async {
    AppConfig.ensure();

    // Supabase
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );

    // 로그인은 사용자 액션으로만 진행 (익명 로그인 비활성화 정책 준수)

    // Kakao
    kakao.KakaoSdk.init(nativeAppKey: AppConfig.kakaoNativeKey);

    // AdMob 초기화
    await AdMobService.initialize();
    
    // 보상형 광고 미리 로드
    if (!kIsWeb) {
      await AdMobService.loadRewardedAd();
    }
  }
}


