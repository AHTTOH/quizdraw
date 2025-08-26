class AppConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String kakaoNativeKey = String.fromEnvironment('KAKAO_NATIVE_KEY');

  static const String androidTestRewardAdUnit = 'ca-app-pub-3940256099942544/5224354917';
  static const String iosTestRewardAdUnit = 'ca-app-pub-3940256099942544/1712485313';

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



