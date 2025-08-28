import 'package:flutter/foundation.dart';

class AppConfig {
  // ✅ 웹 환경변수 처리 개선
  static String get supabaseUrl {
    const url = String.fromEnvironment('SUPABASE_URL');
    if (url.isEmpty) {
      throw Exception('MISSING_CONFIG: SUPABASE_URL');
    }
    return url;
  }
  
  static String get supabaseAnonKey {
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (key.isEmpty) {
      throw Exception('MISSING_CONFIG: SUPABASE_ANON_KEY');
    }
    return key;
  }
  
  static String get kakaoNativeKey {
    const key = String.fromEnvironment('KAKAO_NATIVE_KEY');
    if (key.isEmpty) {
      throw Exception('MISSING_CONFIG: KAKAO_NATIVE_KEY');
    }
    return key;
  }

  // AdMob 광고 단위 ID (환경변수로 관리)
  static String get androidRewardAdUnit {
    const adUnit = String.fromEnvironment('ANDROID_REWARD_AD_UNIT_ID');
    if (adUnit.isNotEmpty) return adUnit;
    
    // 테스트 광고 단위 ID (폴백)
    return 'ca-app-pub-3940256099942544/5224354917';
  }
  
  static String get iosRewardAdUnit {
    const adUnit = String.fromEnvironment('IOS_REWARD_AD_UNIT_ID');
    if (adUnit.isNotEmpty) return adUnit;
    
    // 테스트 광고 단위 ID (폴백)
    return 'ca-app-pub-3940256099942544/1712485313';
  }

  static void ensure() {
    final missing = <String>[];
    if (supabaseUrl.isEmpty) missing.add('SUPABASE_URL');
    if (supabaseAnonKey.isEmpty) missing.add('SUPABASE_ANON_KEY');
    if (kakaoNativeKey.isEmpty) missing.add('KAKAO_NATIVE_KEY');
    
    if (missing.isNotEmpty) {
      throw Exception('MISSING_CONFIG: ${missing.join(', ')}');
    }
  }
}
