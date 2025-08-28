# QuizDraw 즉시 실행 체크리스트

## 🔥 3단계로 빠르게 수정하기

### 1단계: Supabase 테이블 생성 (5분)
```
1. https://supabase.com/dashboard/project/hdziascbcldyzmxhjaaj 접속
2. SQL Editor 클릭  
3. quizdraw_database_setup.sql 파일 내용 전체 복사
4. 붙여넣기 후 Run 버튼 클릭
5. ✅ "Success" 확인
```

### 2단계: Edge Functions 배포 (3분)
```bash
cd C:\quizdraw
supabase functions deploy create-room --no-verify-jwt
supabase functions deploy join-room --no-verify-jwt
supabase functions deploy start-round --no-verify-jwt  
supabase functions deploy submit-guess --no-verify-jwt
supabase functions deploy unlock-palette --no-verify-jwt
supabase functions deploy verify-ad-reward --no-verify-jwt
```

### 3단계: 앱 테스트 (2분)
```bash
cd C:\quizdraw\app
flutter run --dart-define-from-file=.env
```

## 🎮 테스트 시나리오
1. 앱 실행
2. "새 방 만들기" 클릭 → 방 코드 확인
3. 다른 기기로 방 참가
4. "게임 시작" → 그림 그리기 → 정답 입력  
5. 정답 맞추기 → 코인 획득 확인

## ⚠️ 문제 시 해결책
- "relation does not exist": 1단계 다시 실행
- "Failed to create room": 2단계 다시 실행  
- "Network error": .env 파일 확인
- 그림 업로드 실패: Storage에서 "drawings" 버킷 생성

✅ 모든 파일 수정 완료. 위 3단계만 실행하면 됨!
