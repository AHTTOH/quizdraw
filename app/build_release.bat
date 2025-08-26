@echo off
echo QuizDraw Release Build Script  
echo =================================

echo.
echo 0/7 환경 설정 확인...
if not exist ".env" (
    echo ERROR: .env 파일이 없습니다!
    echo .env 파일을 생성하고 SUPABASE_URL, SUPABASE_ANON_KEY, KAKAO_NATIVE_KEY를 설정하세요
    pause
    exit /b 1
)

echo.
echo 1/7 Cleaning Flutter Project...
call flutter clean
if errorlevel 1 goto :error

echo.
echo 2/7 Getting Dependencies...  
call flutter pub get
if errorlevel 1 goto :error

echo.  
echo 3/7 Running Flutter Doctor...
call flutter doctor
if errorlevel 1 echo WARNING: Flutter Doctor에서 경고가 있지만 계속 진행합니다...

echo.
echo 4/7 Generating Icons (if needed)...
rem call flutter pub run flutter_launcher_icons:main

echo.
echo 5/7 Building APK (Release)...
call flutter build apk --release --dart-define-from-file=.env
if errorlevel 1 goto :error

echo.
echo 6/7 Build Complete!
echo Release APK: app\build\app\outputs\flutter-apk\app-release.apk

echo.
echo 7/7 Opening output folder...
explorer /select,"build\app\outputs\flutter-apk\app-release.apk"

echo.
echo =================================
echo ✅ Release Build SUCCESS!
echo =================================
echo APK Size:
for %%A in ("build\app\outputs\flutter-apk\app-release.apk") do echo %%~zA bytes
echo.
pause
goto :end

:error
echo.
echo =================================  
echo ❌ Build FAILED!
echo =================================
echo 다음 사항을 확인하세요:
echo 1. .env 파일이 올바르게 설정되었는지
echo 2. Android SDK와 Flutter가 정상 설치되었는지  
echo 3. 에뮬레이터나 기기가 연결되었는지
echo 4. 의존성 충돌이 없는지
echo.
pause

:end
