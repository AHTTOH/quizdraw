# 🎨 QuizDraw Backend 구축 완료!

> **개발 헌법 준수**: 실제 구현만, 폴백/더미 데이터 절대 금지, 전체 완결 구조

## 📁 구축된 백엔드 구조

```
C:\quizdraw\
├── supabase/
│   ├── migrations/
│   │   ├── 20250824021000_initial_schema.sql    # 데이터베이스 스키마
│   │   └── 20250824021001_rls_policies.sql      # 보안 정책
│   ├── functions/
│   │   ├── _shared/
│   │   │   └── utils.ts                         # 공통 유틸리티
│   │   ├── create-room/
│   │   │   └── index.ts                         # 룸 생성
│   │   ├── join-room/
│   │   │   └── index.ts                         # 룸 참가
│   │   ├── start-round/
│   │   │   └── index.ts                         # 라운드 시작
│   │   ├── submit-guess/
│   │   │   └── index.ts                         # 정답 제출
│   │   ├── verify-ad-reward/
│   │   │   └── index.ts                         # AdMob SSV 검증
│   │   └── unlock-palette/
│   │       └── index.ts                         # 팔레트 해금
│   └── config.toml                              # Supabase 설정
├── tests/
│   └── backend-api-tests.ts                     # API 테스트
├── .env.example                                 # 환경변수 템플릿
└── rules/
    └── quizdraw_development_constitution.md     # 개발 헌법
```

## 🗄️ 데이터베이스 스키마

### 핵심 테이블

1. **users** - 사용자 정보
2. **rooms** - 게임 룸 (코드 기반 입장)
3. **players** - 룸별 참가자
4. **rounds** - 게임 라운드 (그림 그리기 세션)
5. **drawings** - 업로드된 그림 정보
6. **guesses** - 정답 추측 기록
7. **coin_tx** - 코인 거래 원장 (보상/차감)
8. **ad_receipts** - AdMob SSV 영수증
9. **palettes** - 색상 팔레트 정의
10. **user_palettes** - 사용자 해금 팔레트

### 핵심 제약사항

- **정답자 1명만**: `UNIQUE(round_id) WHERE is_correct = true`
- **Idempotency**: `UNIQUE(type, idem_key) WHERE idem_key IS NOT NULL`
- **AdMob 중복방지**: `PRIMARY KEY(idempotency_key)`

## 🔐 보안 (RLS 정책)

- **읽기**: 룸 멤버만 룸 관련 데이터 조회 가능
- **쓰기**: Edge Functions(service_role)만 데이터 수정 가능
- **코인**: 사용자는 자신의 거래만 조회 가능
- **팔레트**: 모든 사용자가 가격표 조회 가능

## 🚀 Edge Functions API

### 1. 룸 생성 - `/functions/v1/create-room`

```json
POST /functions/v1/create-room
{
  "creator_user_id": "uuid",
  "creator_nickname": "string"
}

Response:
{
  "room_id": "uuid",
  "room_code": "ABC123",  // 6자리 영숫자
  "creator_user_id": "uuid",
  "status": "waiting",
  "created_at": "2025-08-24T02:10:00Z"
}
```

### 2. 룸 참가 - `/functions/v1/join-room`

```json
POST /functions/v1/join-room
{
  "room_code": "ABC123",
  "user_id": "uuid",
  "nickname": "string"
}

Response:
{
  "room_id": "uuid",
  "room_code": "ABC123",
  "user_id": "uuid", 
  "nickname": "string",
  "player_count": 2,
  "room_status": "waiting",
  "joined_at": "2025-08-24T02:15:00Z"
}
```

### 3. 라운드 시작 - `/functions/v1/start-round`

```json
POST /functions/v1/start-round
{
  "room_id": "uuid",
  "drawer_user_id": "uuid",
  "answer": "고양이",
  "drawing_storage_path": "drawings/abc.png",
  "drawing_width": 360,
  "drawing_height": 360
}

Response:
{
  "round_id": "uuid",
  "room_id": "uuid",
  "drawer_user_id": "uuid",
  "status": "playing",
  "started_at": "2025-08-24T02:20:00Z",
  "drawing_id": "uuid",
  "drawing_path": "drawings/abc.png"
}
```

### 4. 정답 제출 - `/functions/v1/submit-guess`

```json
POST /functions/v1/submit-guess
{
  "round_id": "uuid",
  "user_id": "uuid",
  "guess": "고양이"
}

Response:
{
  "guess_id": "uuid",
  "round_id": "uuid",
  "user_id": "uuid",
  "guess": "고양이",
  "is_correct": true,
  "is_winner": true,
  "coins_earned": 10,  // RECEIVE_REWARD
  "round_status": "ended",
  "created_at": "2025-08-24T02:25:00Z"
}
```

### 5. 광고 보상 검증 - `/functions/v1/verify-ad-reward`

```json
POST /functions/v1/verify-ad-reward
{
  "user_id": "uuid",
  "ad_network": "5450213213286189855",
  "ad_unit": "ca-app-pub-xxx~xxx",
  "reward_amount": 50,
  "reward_item": "coins",
  "timestamp": "1692860400",
  "transaction_id": "unique-tx-id",
  "signature": "base64-signature",
  "key_id": "3335740509"
}

Response:
{
  "verified": true,
  "coins_awarded": 50,
  "total_balance": 150,
  "receipt_id": "admob:unique-tx-id",
  "verified_at": "2025-08-24T02:30:00Z"
}
```

### 6. 팔레트 해금 - `/functions/v1/unlock-palette`

```json
POST /functions/v1/unlock-palette
{
  "user_id": "uuid",
  "palette_id": "uuid"
}

Response:
{
  "success": true,
  "palette_id": "uuid",
  "palette_name": "Pastel Dream",
  "price_paid": 200,
  "remaining_balance": 50,
  "unlocked_at": "2025-08-24T02:35:00Z"
}
```

## 💰 보상 시스템

### 보상 금액 (BUSINESS_RULES)
- **SEND_REWARD**: 10 코인 (그림 그린 사람)
- **RECEIVE_REWARD**: 10 코인 (정답 맞힌 사람) 
- **AD_REWARD**: 50 코인 (광고 시청, SSV 검증 후)

### 팔레트 가격
- **Basic Mono**: 0 코인 (무료 기본)
- **Pastel Dream**: 200 코인
- **Neon Bright**: 300 코인

### 일일 제한 (원격 플래그로 조정)
- 광고 보상: 5회/일
- SEND 보상: 10회/일
- RECEIVE 보상: 10회/일

## 🛡️ 보안 및 검증

### AdMob SSV 검증 과정
1. 공개키 JSON 가져오기 (`gstatic.com/admob/reward/verifier-keys.json`)
2. `key_id`로 해당 공개키 찾기
3. 요청 파라미터로 검증 메시지 구성
4. ECDSA-SHA256 서명 검증
5. 타임스탬프 검증 (5분 이내)
6. Idempotency 키로 중복 방지
7. 검증 성공 시 코인 지급

### 경쟁 상태 방지
- **정답 1명만**: PostgreSQL Partial Unique 제약
- **보상 중복 방지**: Idempotency 키 + Unique 제약
- **광고 중복 방지**: Transaction ID를 Primary Key로 사용

### 입력 검증
- UUID 형식 검증
- 텍스트 길이 제한
- 룸 코드 형식 (`^[A-Z0-9]{6,8}$`)
- 그림 크기 제한 (64-4096px)

## 🏗️ 배포 가이드

### 1. 로컬 개발 환경 시작

```bash
# Supabase 로컬 시작
cd C:\quizdraw
supabase start

# 마이그레이션 실행
supabase db reset

# Edge Functions 배포 (로컬)
supabase functions deploy create-room
supabase functions deploy join-room
supabase functions deploy start-round
supabase functions deploy submit-guess
supabase functions deploy verify-ad-reward
supabase functions deploy unlock-palette
```

### 2. 환경변수 설정

```bash
# .env 파일 생성
cp .env.example .env

# 필수 설정값 입력
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

### 3. API 테스트 실행

```bash
# 테스트 실행 전 SERVICE_ROLE_KEY 설정
deno test tests/backend-api-tests.ts --allow-net
```

### 4. 프로덕션 배포

```bash
# Supabase 프로젝트 연결
supabase link --project-ref your-project-ref

# 마이그레이션 배포
supabase db push

# Edge Functions 배포
supabase functions deploy --no-verify-jwt

# 환경변수 설정
supabase secrets set ADMOB_PUBLIC_KEYS_URL=https://gstatic.com/admob/reward/verifier-keys.json
```

## 🧪 테스트 시나리오

### 완전한 게임 플로우 테스트
1. ✅ 사용자1이 룸 생성
2. ✅ 사용자2가 룸 참가
3. ✅ 사용자1이 라운드 시작 (그림 + 정답)
4. ✅ 사용자2가 틀린 추측
5. ✅ 사용자2가 정답 제출 → 승리 + 10코인
6. ✅ 중복 정답 시도 → 실패
7. ✅ 광고 시청 → SSV 검증 → 50코인
8. ✅ 팔레트 해금 → 200코인 차감

### 에러 처리 테스트
- ❌ 잘못된 UUID 형식
- ❌ 필수 필드 누락
- ❌ 존재하지 않는 룸
- ❌ 잘못된 HTTP 메소드
- ❌ 잔액 부족 시 팔레트 해금

## 📊 성능 최적화

### 데이터베이스 인덱스
- 시간 기반 조회: `created_at` btree 인덱스
- 관계 조회: `room_id`, `user_id` 복합 인덱스  
- 고유성: Partial Unique 인덱스 (정답/Idempotency)
- JSONB 검색: GIN 인덱스 (팔레트 색상)

### 캐시 전략
- AdMob 공개키: 1시간 메모리 캐시
- 룸 상태: 실시간 조회 (캐시 없음)
- 코인 잔액: View를 통한 집계 최적화

## 🚨 에러 코드 및 처리

### HTTP 상태 코드
- **200**: 성공 (이미 처리된 요청)
- **201**: 생성 성공
- **400**: 잘못된 요청 (검증 실패)
- **403**: 권한 없음 (SSV 실패, 룸 멤버 아님)
- **404**: 리소스 없음 (룸/사용자 없음)
- **405**: 잘못된 메소드
- **409**: 충돌 (중복 요청)
- **500**: 서버 오류

### 에러 응답 형식
```json
{
  "error": "Room not found",
  "details": {
    "room_code": "NOTFND"
  },
  "timestamp": "2025-08-24T02:40:00Z"
}
```

## 🔄 다음 단계 (프론트엔드 구현)

### Flutter 앱 구현 예정
1. **UI/UX**: Material Design 3 기반 접근성 최적화
2. **상태관리**: Provider/Riverpod을 통한 상태 관리
3. **네트워킹**: Dio + Retrofit을 통한 API 연동
4. **그림 그리기**: CustomPainter + GestureDetector
5. **스토리지**: Supabase Storage 연동
6. **카카오 공유**: 딥링크 + 템플릿 메시지
7. **AdMob**: 리워드 광고 + SSV 연동
8. **오프라인**: SQLite 로컬 캐시

## 🔥 핵심 성과

### ✅ 개발 헌법 준수 완료
- **폴백/더미 데이터 절대 금지**: 모든 데이터는 실제 DB/API 연동
- **전체 완결 구조**: DB 스키마 → 보안 → API → 테스트까지 완전 구현
- **실제 구현만**: AdMob SSV, PostgreSQL 제약, Edge Functions 비즈니스 로직

### 🛡️ 보안 및 안정성
- Row Level Security로 데이터 접근 제어
- Idempotency 키로 중복 요청 방지
- PostgreSQL 제약으로 비즈니스 룰 강제
- AdMob SSV 실제 서명 검증 구조

### ⚡ 성능 및 확장성  
- 최적화된 인덱스 전략
- Edge Functions으로 서버리스 확장
- View를 통한 집계 쿼리 최적화
- 공개키 캐시로 외부 API 호출 최소화

---

**🏛️ 개발 헌법 선언문 이행 완료**
> "실제 데이터는 독이고, 부분 완결은 실패, 성급한 판단은 오판이다!"
> 
> **폴백/임시/더미 데이터 0개, 전체 시스템 완결, 체계적 분석 완료** ✅
