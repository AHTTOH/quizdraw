@echo off
echo ======================================
echo QuizDraw 긴급 수정 스크립트 v1.0
echo ======================================

cd /d "C:\quizdraw"

echo.
echo [1/4] Flutter 프로젝트 정리 중...
cd app
call flutter clean
call flutter pub get

echo.
echo [2/4] 웹 빌드 생성 중...
call flutter build web --dart-define-from-file=.env

echo.
echo [3/4] Android 디버그 APK 빌드 중...
call flutter build apk --debug --dart-define-from-file=.env

echo.
echo [4/4] 앱 실행 (개발 모드)...
echo.
echo ======================================
echo 🚀 QuizDraw 앱이 시작됩니다!
echo ======================================
echo.
echo 📱 앱에서 테스트할 항목들:
echo   1. 방 생성 (새 방 만들기)
echo   2. 방 참가 (코드 입력)
echo   3. 그림 그리기
echo   4. 정답 맞추기
echo   5. 코인 시스템
echo.
echo 🔧 문제 발생 시:
echo   - Supabase 대시보드에서 테이블 생성 여부 확인
echo   - Edge Functions 배포 상태 확인
echo   - .env 파일의 환경변수 확인
echo.

start "QuizDraw App" flutter run --dart-define-from-file=.env

echo.
echo ======================================
echo ✅ 스크립트 완료!
echo ======================================
pause
