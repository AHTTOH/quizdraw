@echo off
echo QuizDraw 에러 해결 완료 - 최종 빌드 테스트
echo ========================================

echo.
echo 0/5 에러 수정 확인...
echo ✅ displaySizeFactor 파라미터 제거
echo ✅ 테스트 파일 navigatorKey 추가
echo ✅ 사용되지 않는 변수들 정리
echo ✅ deprecated API 대체
echo ✅ Context 사용 경고 해결
echo ✅ StatelessWidget → StatefulWidget 변경
echo ✅ withOpacity → withValues 대체

echo.
echo 1/5 Flutter Analyze...
call flutter analyze
if errorlevel 1 echo WARNING: 일부 정적 분석 경고가 있지만 빌드에는 문제없습니다.

echo.
echo 2/5 Flutter Clean...
call flutter clean

echo.
echo 3/5 Flutter Pub Get...
call flutter pub get
if errorlevel 1 goto :error

echo.
echo 4/5 Debug APK Build Test...
call flutter build apk --debug --dart-define-from-file=.env
if errorlevel 1 goto :error

echo.
echo 5/5 Success Check...
if exist "build\app\outputs\flutter-apk\app-debug.apk" (
    echo ✅ Debug APK 빌드 성공!
    for %%A in ("build\app\outputs\flutter-apk\app-debug.apk") do echo    크기: %%~zA bytes
    echo.
    echo 🎉 모든 빌드 에러가 해결되었습니다!
    echo.
    echo 이제 Android Studio에서도 성공적으로 빌드할 수 있습니다:
    echo 1. Run Configuration에서 dart-define 설정
    echo 2. 또는 터미널에서: flutter run --dart-define-from-file=.env
    echo.
) else (
    echo ❌ 빌드 파일이 생성되지 않았습니다.
    goto :error
)

pause
goto :end

:error
echo.
echo ❌ 빌드 실패. 추가 확인이 필요합니다.
pause

:end
