import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// import 'package:uni_links/uni_links.dart'; // 주석 해제 필요 시
import '../ui/room/room_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeepLinkHandler {
  static StreamSubscription<dynamic>? _linkSubscription;
  static GlobalKey<NavigatorState>? navigatorKey;
  static bool _isInitialized = false;

  static void initialize(GlobalKey<NavigatorState> navKey) {
    if (_isInitialized) return;
    
    navigatorKey = navKey;
    _initializeDeepLinks();
    _isInitialized = true;
  }

  static void _initializeDeepLinks() {
    if (kIsWeb) {
      // 웹에서는 URL 변경 감지로 딥링크 처리
      debugPrint('Initializing web deep links');
      _handleWebDeepLinks();
    } else {
      // 모바일에서는 uni_links 사용
      debugPrint('Initializing mobile deep links');
      _handleMobileDeepLinks();
    }
  }

  static void _handleWebDeepLinks() {
    // 웹에서는 현재 URL을 확인해서 딥링크 처리
    final currentUrl = Uri.base;
    debugPrint('Current web URL: $currentUrl');
    
    // URL에 room 파라미터가 있으면 방으로 이동
    final roomCode = currentUrl.queryParameters['r'] ?? currentUrl.queryParameters['room'];
    if (roomCode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToRoom(roomCode);
      });
    }
    
    // URL에 round 파라미터가 있으면 라운드로 이동
    final roundId = currentUrl.queryParameters['round'];
    final inviteId = currentUrl.queryParameters['i'] ?? currentUrl.queryParameters['invite'];
    if (roundId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToRound(roundId, inviteId);
      });
    }
  }

  static void _handleMobileDeepLinks() {
    try {
      // 앱 시작 시 초기 딥링크 확인
      // getInitialUri().then((uri) {
      //   if (uri != null) {
      //     debugPrint('Initial deep link: $uri');
      //     _handleDeepLink(uri);
      //   }
      // }).catchError((error) {
      //   debugPrint('Failed to get initial link: $error');
      // });
      
      // 앱 실행 중 딥링크 수신
      // _linkSubscription = uriLinkStream.listen((Uri uri) {
      //   debugPrint('Received deep link: $uri');
      //   _handleDeepLink(uri);
      // }, onError: (error) {
      //   debugPrint('Deep link error: $error');
      // });
      
      debugPrint('Mobile deep links initialization completed (stubbed)');
    } catch (e) {
      debugPrint('Failed to initialize mobile deep links: $e');
    }
  }

  // 웹에서 딥링크 테스트용 함수
  static void testDeepLink(String roomCode) {
    debugPrint('Testing deep link for room: $roomCode');
    _navigateToRoom(roomCode);
  }

  static void _navigateToRoom(String roomCode) {
    debugPrint('Navigating to room: $roomCode');
    final context = navigatorKey?.currentContext;
    if (context != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => RoomScreen(roomCode: roomCode),
        ),
      );
      
      // 딥링크로 입장했음을 알림
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('초대를 통해 방 $roomCode에 입장했습니다!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  static void _navigateToRound(String roundId, String? inviteId) {
    debugPrint('Navigating to round: $roundId, invite: $inviteId');
    
    final context = navigatorKey?.currentContext;
    if (context != null) {
      // 라운드가 있는 방을 찾아서 입장
      _findRoomByRoundId(roundId).then((roomCode) {
        if (roomCode != null) {
          _navigateToRoom(roomCode);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('해당 라운드를 찾을 수 없습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  static Future<String?> _findRoomByRoundId(String roundId) async {
    try {
      // Supabase에서 라운드 ID로 방 코드 조회
      final response = await Supabase.instance.client
          .from('rounds')
          .select('rooms!inner(code)')
          .eq('id', roundId)
          .single();
      
      return response['rooms']['code'] as String?;
    } catch (e) {
      debugPrint('Failed to find room by round ID: $e');
      return null;
    }
  }

  static void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
    _isInitialized = false;
  }
}
