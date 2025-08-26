import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../api/quizdraw_api.dart';

class AppState extends ChangeNotifier {
  String? _userId;
  int _coinBalance = 0;
  bool _isHighContrast = false;
  bool _isLargeText = false;
  bool _isColorBlindFriendly = false;

  String? get userId => _userId;
  int get coinBalance => _coinBalance;
  bool get isHighContrast => _isHighContrast;
  bool get isLargeText => _isLargeText;
  bool get isColorBlindFriendly => _isColorBlindFriendly;

  /// 세션 로드 및 초기화
  Future<void> loadSession() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final newUserId = session?.user.id;
      
      if (newUserId != null && newUserId != _userId) {
        _userId = newUserId;
        await refreshBalance();
      }
    } catch (e) {
      debugPrint('세션 로드 실패: $e');
    }
  }

  /// 코인 잔액 새로고침 (수동)
  Future<void> refreshBalance() async {
    if (_userId == null) return;
    
    try {
      final balance = await QuizDrawAPI.getCoinBalance();
      _coinBalance = balance;
      notifyListeners();
    } catch (e) {
      debugPrint('잔액 새로고침 실패: $e');
    }
  }

  /// 접근성 설정 업데이트
  void updateAccessibilitySettings({
    bool? isHighContrast,
    bool? isLargeText,
    bool? isColorBlindFriendly,
  }) {
    bool hasChanged = false;
    
    if (isHighContrast != null && isHighContrast != _isHighContrast) {
      _isHighContrast = isHighContrast;
      hasChanged = true;
    }
    
    if (isLargeText != null && isLargeText != _isLargeText) {
      _isLargeText = isLargeText;
      hasChanged = true;
    }
    
    if (isColorBlindFriendly != null && isColorBlindFriendly != _isColorBlindFriendly) {
      _isColorBlindFriendly = isColorBlindFriendly;
      hasChanged = true;
    }
    
    if (hasChanged) {
      notifyListeners();
    }
  }
}


