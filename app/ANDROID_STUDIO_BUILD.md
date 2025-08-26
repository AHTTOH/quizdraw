# Android Studio에서 빌드하기 위한 환경변수 설정 가이드

## 🎯 Android Studio 빌드 설정

### 1. Run/Debug Configurations 설정
1. Android Studio → Run → Edit Configurations...
2. 해당 구성을 선택
3. "Additional run args" 필드에 다음 내용 추가:

```
--dart-define=SUPABASE_URL=https://hdziascbcldyzmxhjaaj.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhkemlhc2NiY2xkeXpteGhqYWFqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU5NzcxOTgsImV4cCI6MjA3MTU1MzE5OH0.dKOIjtYLP6HHIKfjY7aF4KBWPiyZC-XIWUL0aoPsgSo --dart-define=KAKAO_NATIVE_KEY=12345678901234567890123456789012
```

### 2. 또는 터미널에서 직접 실행

```bash
# 디버그 빌드
flutter run --dart-define-from-file=.env

# APK 빌드
flutter build apk --release --dart-define-from-file=.env

# App Bundle 빌드  
flutter build appbundle --release --dart-define-from-file=.env
```

### 3. Android Studio에서 App Bundle 빌드하기

1. Build → Flutter → Build App Bundle
2. 또는 Build → Generate Signed Bundle/APK... → Android App Bundle

단, 환경변수가 설정되어 있어야 합니다!

## 🔧 문제 해결

### 빌드 실패 시 체크사항:
1. `.env` 파일이 `app/` 폴더에 있는지 확인
2. Android Studio Run Configuration에 dart-define 설정 확인
3. `flutter clean` → `flutter pub get` 실행
4. Android SDK와 라이선스가 모두 설치되어 있는지 확인

### 대안: 배치 파일 사용
- `build_debug.bat`: 디버그 APK
- `build_release.bat`: 릴리스 APK  

## 🚀 배포용 빌드
릴리스 빌드는 반드시 환경변수가 설정된 상태에서 실행하세요:

```bash
flutter build appbundle --release --dart-define-from-file=.env
```

빌드 결과물은 `build/app/outputs/bundle/release/app-release.aab`에 생성됩니다.
