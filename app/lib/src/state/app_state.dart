import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../api/quizdraw_api.dart';

class AppState extends ChangeNotifier {
  String? _userId;
  int _coinBalance = 0;
  String? _userNickname;
  bool _isHighContrast = false;
  bool _isLargeText = false;
  bool _isColorBlindFriendly = false;

  String? get userId => _userId;
  int get coinBalance => _coinBalance;
  String? get userNickname => _userNickname;
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
        await _loadUserProfile();
        await refreshBalance();
      } else if (newUserId == null && _userId != null) {
        // 로그아웃된 경우
        _userId = null;
        _coinBalance = 0;
        _userNickname = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('세션 로드 실패: $e');
    }
  }

  /// 사용자 프로필 로드
  Future<void> _loadUserProfile() async {
    if (_userId == null) return;
    
    try {
      // ✅ 수정: 올바른 테이블명 사용
      final response = await Supabase.instance.client
          .from('users')
          .select('nickname')
          .eq('id', _userId)
          .single();
      
      _userNickname = response['nickname'] as String?;
      notifyListeners();
    } catch (e) {
      debugPrint('프로필 로드 실패: $e');
      // 프로필이 없는 경우 생성 시도
      if (e.toString().contains('PGRST116') || e.toString().contains('No rows')) {
        // 기본 닉네임으로 사용자 생성
        final defaultNickname = '플레이어${_userId?.substring(0, 6)}';
        try {
          await QuizDrawAPI.createOrUpdateUser(defaultNickname);
          _userNickname = defaultNickname;
          notifyListeners();
        } catch (createError) {
          debugPrint('사용자 생성 실패: $createError');
        }
      }
    }
  }

  /// 닉네임 업데이트
  Future<void> updateNickname(String newNickname) async {
    if (_userId == null) throw Exception('로그인이 필요합니다');
    
    try {
      await QuizDrawAPI.updateNickname(newNickname);
      _userNickname = newNickname;
      notifyListeners();
    } catch (e) {
      throw Exception('닉네임 업데이트 실패: $e');
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

  /// 사용자 로그인 처리 (카카오 또는 익명)
  Future<void> handleUserLogin() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session?.user.id != null) {
        await loadSession();
      }
    } catch (e) {
      debugPrint('로그인 처리 실패: $e');
    }
  }

  /// 코인 추가 (보상 시 호출)
  void addCoins(int amount) {
    _coinBalance += amount;
    notifyListeners();
  }

  /// 코인 차감 (구매 시 호출)
  bool deductCoins(int amount) {
    if (_coinBalance >= amount) {
      _coinBalance -= amount;
      notifyListeners();
      return true;
    }
    return false;
  }
}
