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

    // 익명 세션 확보
    final supabase = Supabase.instance.client;
    if (supabase.auth.currentSession == null) {
      await supabase.auth.signInAnonymously();
    }

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


