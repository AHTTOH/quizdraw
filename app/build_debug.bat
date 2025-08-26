@echo off
echo QuizDraw Flutter Build Script
echo ============================

echo.
echo 1/6 Cleaning Flutter Project...
call flutter clean

echo.
echo 2/6 Getting Dependencies...  
call flutter pub get

echo.
echo 3/6 Running Flutter Doctor...
call flutter doctor

echo.
echo 4/6 Building APK (Debug)...
call flutter build apk --debug --dart-define-from-file=.env

echo.
echo 5/6 Build Complete!
echo Check: app\build\app\outputs\flutter-apk\app-debug.apk

echo.
echo 6/6 Installing to Device (if connected)...
call flutter install

echo.
echo ============================
echo Build Process Complete!
echo ============================
pause
