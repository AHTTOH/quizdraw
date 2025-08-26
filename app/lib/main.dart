import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'src/core/bootstrap.dart';
import 'src/core/deep_link_handler.dart';
import 'src/state/app_state.dart';
import 'src/ui/app_root.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 핵심 서비스 초기화
  await Bootstrap.initialize();
  
  // 네비게이션 키 생성
  final navigatorKey = GlobalKey<NavigatorState>();
  
  // 딥링크 핸들러 초기화
  DeepLinkHandler.initialize(navigatorKey);
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: AppRoot(navigatorKey: navigatorKey),
    ),
  );
}
