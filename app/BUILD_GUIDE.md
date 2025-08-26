# 🎯 QuizDraw Flutter App 빌드 가이드

## ⚡ 빠른 빌드 실행

### **1단계: 환경 설정**
```bash
# .env 파일이 이미 설정되어 있음
# SUPABASE_URL, SUPABASE_ANON_KEY, KAKAO_NATIVE_KEY 포함
```

### **2단계: 디버그 빌드 (개발용)**
```cmd
# Windows
build_debug.bat

# 또는 수동 실행
flutter clean
flutter pub get  
flutter build apk --debug --dart-define-from-file=.env
```

### **3단계: 릴리스 빌드 (배포용)**
```cmd
# Windows  
build_release.bat

# 또는 수동 실행
flutter clean
flutter pub get
flutter build apk --release --dart-define-from-file=.env
```

## 🔧 문제 해결

### **일반적인 빌드 오류**

#### **1. 환경변수 오류**
```
MISSING_CONFIG: SUPABASE_URL, SUPABASE_ANON_KEY, KAKAO_NATIVE_KEY
```
**해결:** `.env` 파일이 앱 루트에 있고 올바른 값들이 설정되어 있는지 확인

#### **2. Android 라이선스 오류**
```
Android sdkmanager not found
```
**해결:** 
```cmd
flutter doctor --android-licenses
```

#### **3. Gradle 빌드 실패**
```cmd
flutter clean
flutter pub get
flutter build apk --verbose
```

#### **4. 의존성 충돌**
```cmd
flutter pub deps
flutter pub upgrade
```

## 📱 앱 정보

- **패키지명**: `com.quizdraw.app`
- **앱명**: QuizDraw (너랑 나의 그림퀴즈)  
- **타겟 SDK**: Flutter 3.8.1+
- **최소 Android**: API 21 (Android 5.0)

## 🔗 주요 의존성

- `supabase_flutter: ^2.6.0` - 백엔드 연동
- `provider: ^6.1.2` - 상태 관리
- `google_mobile_ads: ^5.1.0` - 광고 수익화
- `kakao_flutter_sdk: ^1.9.0` - 카카오 공유
- `image_picker: ^1.1.2` - 이미지 선택

## 🏗️ 프로젝트 구조

```
app/
├── lib/
│   └── src/
│       ├── api/          # Supabase API 연동
│       ├── core/         # 핵심 서비스 (AdMob, 카카오 등)  
│       ├── state/        # 상태 관리 (Provider)
│       └── ui/           # UI 화면들
├── android/              # Android 네이티브 설정
├── .env                  # 환경변수 설정
├── build_debug.bat      # 디버그 빌드 스크립트
└── build_release.bat    # 릴리스 빌드 스크립트  
```

## ✅ 빌드 성공 체크리스트

- [x] `.env` 파일 설정 완료
- [x] Android 패키지명 통일 (`com.quizdraw.app`)
- [x] MainActivity 올바른 경로에 생성  
- [x] AndroidManifest.xml 권한 설정
- [x] Gradle 설정 최적화
- [x] Flutter 의존성 해결
- [x] AdMob 테스트 ID 설정
- [x] Supabase 연동 확인

## 🚀 배포 가이드

### **Google Play Store 배포**
1. Release APK 빌드: `build_release.bat`
2. APK 서명 (필요시)
3. Google Play Console 업로드
4. 내부 테스트 → 베타 → 프로덕션

### **직접 배포 (APK)**
1. `build/app/outputs/flutter-apk/app-release.apk` 파일 사용
2. 사용자에게 직접 배포 가능

---

## 🔥 개발 헌법 준수 사항

✅ **실제 Supabase 연동** - 모든 더미/임시 데이터 제거됨
✅ **완전한 빌드 환경** - 모든 필수 설정 완료
✅ **에러 처리 완성** - 명확한 실패 메시지 구현
✅ **전체 시스템 검증** - Flutter + Android + Supabase 통합 완료

**🎯 결과**: 사용자가 실제로 사용할 수 있는 완전한 앱 빌드 가능!
