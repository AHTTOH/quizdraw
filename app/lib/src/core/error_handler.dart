import 'package:flutter/material.dart';

class ErrorHandler {
  static void handleError(BuildContext context, dynamic error, {String? customMessage}) {
    debugPrint('Error occurred: $error');
    
    String userFriendlyMessage = customMessage ?? _getErrorMessage(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(userFriendlyMessage)),
          ],
        ),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: '닫기',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
      ),
    );
  }

  static String _getErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // 네트워크 오류
    if (errorString.contains('network') || 
        errorString.contains('connection') ||
        errorString.contains('timeout')) {
      return '인터넷 연결을 확인해주세요';
    }
    
    // 인증 오류
    if (errorString.contains('auth') || 
        errorString.contains('login') ||
        errorString.contains('unauthorized')) {
      return '로그인이 필요합니다';
    }
    
    // 서버 오류
    if (errorString.contains('500') || 
        errorString.contains('server') ||
        errorString.contains('internal')) {
      return '서버에 문제가 발생했습니다. 잠시 후 다시 시도해주세요';
    }
    
    // 잘못된 요청
    if (errorString.contains('400') || 
        errorString.contains('bad request') ||
        errorString.contains('invalid')) {
      return '잘못된 요청입니다';
    }
    
    // 리소스 없음
    if (errorString.contains('404') || 
        errorString.contains('not found')) {
      return '요청한 정보를 찾을 수 없습니다';
    }
    
    // Supabase 관련 오류
    if (errorString.contains('supabase') || 
        errorString.contains('postgres') ||
        errorString.contains('relation')) {
      return '데이터베이스 연결에 문제가 발생했습니다';
    }
    
    // 권한 오류
    if (errorString.contains('permission') || 
        errorString.contains('forbidden') ||
        errorString.contains('403')) {
      return '권한이 없습니다';
    }
    
    // 룸 관련 오류
    if (errorString.contains('room not found')) {
      return '존재하지 않는 방입니다';
    }
    
    if (errorString.contains('room is full')) {
      return '방이 가득 찼습니다';
    }
    
    if (errorString.contains('already in room')) {
      return '이미 참가한 방입니다';
    }
    
    // 게임 관련 오류
    if (errorString.contains('round not active')) {
      return '진행 중인 게임이 없습니다';
    }
    
    if (errorString.contains('drawer cannot submit')) {
      return '그림을 그린 사람은 정답을 제출할 수 없습니다';
    }
    
    // 코인 관련 오류
    if (errorString.contains('insufficient coins')) {
      return '코인이 부족합니다';
    }
    
    if (errorString.contains('palette already unlocked')) {
      return '이미 해금한 팔레트입니다';
    }
    
    // 일반적인 오류
    return '알 수 없는 오류가 발생했습니다';
  }
}

/// 글로벌 에러 핸들러 위젯
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget? fallback;
  
  const ErrorBoundary({
    super.key, 
    required this.child,
    this.fallback,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;
  dynamic _error;

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.fallback ?? Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                '앱에 오류가 발생했습니다',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                ErrorHandler._getErrorMessage(_error),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _error = null;
                  });
                },
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
  
  void _handleError(dynamic error) {
    setState(() {
      _hasError = true;
      _error = error;
    });
  }
}
