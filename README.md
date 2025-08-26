# QuizDraw - 너랑 나의 그림퀴즈

## 🚀 빠른 시작

### 1. 저장소 클론
```bash
git clone [your-repository-url]
cd quizdraw
```

### 2. 환경변수 설정
```bash
# 환경변수 템플릿 복사
cp .env.example app/.env

# 실제 값들로 수정
# - Supabase URL과 API 키: https://supabase.com/dashboard
# - Kakao Native Key: https://developers.kakao.com/console/app
```

### 3. Flutter 앱 실행
```bash
cd app
flutter pub get
flutter run --dart-define-from-file=.env
```

## 📁 프로젝트 구조

```
quizdraw/
├── app/                    # Flutter 앱
├── supabase/              # Supabase 설정 및 함수
├── docs/                  # 프로젝트 문서
├── scripts/               # 유틸리티 스크립트
├── tests/                 # 백엔드 API 테스트
└── .env.example          # 환경변수 템플릿
```

## 🔧 환경변수 설정

### 필요한 환경변수들:

1. **Supabase 설정**
   - `SUPABASE_URL`: Supabase 프로젝트 URL
   - `SUPABASE_ANON_KEY`: Supabase 익명 키

2. **Kakao 설정**
   - `KAKAO_NATIVE_KEY`: Kakao 네이티브 앱 키

### 설정 방법:

1. `.env.example` 파일을 `app/.env`로 복사
2. 각 서비스에서 실제 키 값들을 가져와서 설정:
   - **Supabase**: https://supabase.com/dashboard → Settings → API
   - **Kakao**: https://developers.kakao.com/console/app → 앱 키

## 🛠️ 개발 가이드

자세한 개발 가이드는 다음 문서들을 참조하세요:
- [Flutter 구현 가이드](FLUTTER_IMPLEMENTATION_GUIDE.md)
- [백엔드 README](README_BACKEND.md)
- [프로젝트 완성 인증서](PROJECT_COMPLETION_CERTIFICATE.md)
