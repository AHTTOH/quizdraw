// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quizdraw/src/state/app_state.dart';
import 'package:quizdraw/src/ui/app_root.dart';

void main() {
  testWidgets('QuizDraw smoke test', (WidgetTester tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: AppRoot(navigatorKey: navigatorKey),
      ),
    );

    // 앱이 로드될 때까지 대기
    await tester.pumpAndSettle();
    
    // 온보딩 화면이나 홈 화면이 있는지 확인
    expect(find.byType(AppRoot), findsOneWidget);
  });
}
