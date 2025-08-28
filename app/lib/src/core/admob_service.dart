import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'app_config.dart';

class AdMobService {
  static RewardedAd? _rewardedAd;
  static bool _isAdLoaded = false;
  static bool _isLoading = false;

  static String get _rewardedAdUnitId {
    if (kIsWeb) {
      throw UnsupportedError('웹에서는 AdMob이 지원되지 않습니다');
    }
    if (Platform.isAndroid) {
      if (AppConfig.androidRewardAdUnit.isEmpty) {
        throw Exception('MISSING_CONFIG: ANDROID_REWARD_AD_UNIT_ID');
      }
      return AppConfig.androidRewardAdUnit;
    }
    if (Platform.isIOS) {
      if (AppConfig.iosRewardAdUnit.isEmpty) {
        throw Exception('MISSING_CONFIG: IOS_REWARD_AD_UNIT_ID');
      }
      return AppConfig.iosRewardAdUnit;
    }
    throw UnsupportedError('지원되지 않는 플랫폼입니다');
  }

  /// 보상형 광고 로드
  static Future<bool> loadRewardedAd() async {
    if (_isLoading || _isAdLoaded) return _isAdLoaded;
    
    _isLoading = true;
    
    try {
      await RewardedAd.load(
        adUnitId: _rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _isAdLoaded = true;
            _isLoading = false;
            debugPrint('보상형 광고 로드 완료');
          },
          onAdFailedToLoad: (error) {
            _rewardedAd = null;
            _isAdLoaded = false;
            _isLoading = false;
            debugPrint('보상형 광고 로드 실패: ${error.message}');
          },
        ),
      );
    } catch (e) {
      _isLoading = false;
      debugPrint('보상형 광고 로드 중 오류: $e');
    }
    
    return _isAdLoaded;
  }

  /// 보상형 광고 표시
  static Future<bool> showRewardedAd() async {
    if (!_isAdLoaded || _rewardedAd == null) {
      debugPrint('보상형 광고가 로드되지 않았습니다');
      return false;
    }

    try {
      bool rewardEarned = false;
      
      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          rewardEarned = true;
          debugPrint('보상 획득: ${reward.amount} ${reward.type}');
        },
      );
      
      _rewardedAd = null;
      _isAdLoaded = false;
      
      return rewardEarned;
    } catch (e) {
      debugPrint('보상형 광고 표시 중 오류: $e');
      return false;
    }
  }

  /// 광고 로드 상태 확인
  static bool get isAdLoaded => _isAdLoaded;
  
  /// 광고 로딩 중 상태 확인
  static bool get isLoading => _isLoading;

  /// 광고 초기화 (앱 시작시 호출)
  static Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('웹에서는 AdMob이 지원되지 않습니다');
      return;
    }
    
    try {
      await MobileAds.instance.initialize();
      debugPrint('AdMob 초기화 완료');
    } catch (e) {
      debugPrint('AdMob 초기화 실패: $e');
    }
  }
}
