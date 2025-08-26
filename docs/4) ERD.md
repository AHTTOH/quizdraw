What: 소셜 그림 퀴즈 \*\*“너랑 나의 그림퀴즈”\*\*의 데이터베이스 설계를 담은 **ERD 문서(메르메이드 + 표 사양)**
Why: \*\*정합성(단 한 명의 우승자, 중복 보상 불가)\*\*와 **성능(빠른 룸/라운드 읽기)**, \*\*보안(서버 권위/SSV/Idempotency)\*\*를 1주 MVP에 맞게 보장
How-Now: PostgreSQL(Supabase) 3NF 기반, **부분 유니크 인덱스**와 **Idempotency 키**로 경쟁상태/어뷰징 방지, 읽기 최적화 뷰(`coin_balances`) 제공

---

## 목차

* Entity Definitions (ERD)
* Attribute Specifications (엔티티별 스키마/예시)
* Relationship Mappings & PK/FK 구조
* Index Strategy
* Constraints & Business Rules
* Data Types & Validation Rules
* Normalization Analysis
* Performance Optimization (샘플 쿼리 포함)
* Migration & Versioning Strategy
* RLS Overview
* (가정/리스크/백로그)

---

## Entity Definitions (ERD)

**Reasoning → Conclusion**: **핵심 이벤트(정답/보상/광고검증) 원자성**을 위해 별도 로그 테이블과 **부분 유니크 인덱스**를 둔다. 보상은 항상 서버(Edge)에서만 기록한다.

```mermaid
erDiagram
  USERS ||--o{ PLAYERS : participates_in
  USERS ||--o{ ROUNDS  : draws
  USERS ||--o{ GUESSES : submits
  USERS ||--o{ COIN_TX : owns
  USERS ||--o{ AD_RECEIPTS : receives
  USERS ||--o{ USER_PALETTES : unlocks

  ROOMS ||--o{ PLAYERS : has
  ROOMS ||--o{ ROUNDS  : contains

  ROUNDS ||--o| DRAWINGS : has
  ROUNDS ||--o{ GUESSES  : collects
  ROUNDS ||--o{ COIN_TX  : references

  PALETTES ||--o{ USER_PALETTES : is_unlocked

  USERS {
    uuid id PK
    text nickname
    timestamptz created_at
    text created_by
  }

  ROOMS {
    uuid id PK
    text code UNIQUE
    text status
    uuid created_by FK -> USERS.id
    timestamptz created_at
  }

  PLAYERS {
    uuid id PK
    uuid room_id FK -> ROOMS.id
    uuid user_id FK -> USERS.id
    text nickname
    int  score
    timestamptz last_seen
    UNIQUE (room_id, user_id)
  }

  ROUNDS {
    uuid id PK
    uuid room_id FK -> ROOMS.id
    uuid drawer_user_id FK -> USERS.id
    text answer
    text status
    uuid winner_user_id FK -> USERS.id nullable
    timestamptz started_at
    timestamptz ended_at
  }

  DRAWINGS {
    uuid id PK
    uuid round_id FK -> ROUNDS.id
    text storage_path UNIQUE
    int width
    int height
    timestamptz created_at
  }

  GUESSES {
    uuid id PK
    uuid round_id FK -> ROUNDS.id
    uuid user_id FK -> USERS.id
    text text
    text normalized_text
    bool is_correct
    timestamptz created_at
    -- PARTIAL UNIQUE: (round_id) WHERE is_correct = true
  }

  COIN_TX {
    uuid id PK
    uuid user_id FK -> USERS.id
    text type
    int  amount
    uuid ref_round_id FK -> ROUNDS.id nullable
    text ref_ad_tx_id nullable
    text idem_key nullable
    timestamptz created_at
    text created_by
    -- UNIQUE (type, idem_key) WHERE idem_key IS NOT NULL
  }

  AD_RECEIPTS {
    text idempotency_key PK
    uuid user_id FK -> USERS.id
    text provider_tx_id UNIQUE
    text key_id
    text signature
    jsonb payload
    int amount
    timestamptz verified_at
    timestamptz created_at
  }

  PALETTES {
    uuid id PK
    text name UNIQUE
    jsonb swatches
    int price_coins
    bool is_colorblind_safe
    timestamptz created_at
  }

  USER_PALETTES {
    uuid id PK
    uuid user_id FK -> USERS.id
    uuid palette_id FK -> PALETTES.id
    timestamptz unlocked_at
    UNIQUE (user_id, palette_id)
  }

  coin_balances {
    uuid user_id
    int balance
    -- VIEW: SUM(COIN_TX.amount) BY user_id
  }
```

**Note:** AD\_REWARD는 **AdMob SSV**로만 적립. SSV는 `key_id`로 **public keys JSON**을 조회하여 **ECDSA(SHA-256)** 서명을 검증(키 회전 캐시 권장). Target API 35(2025-08-31), iOS 14.5+ ATT 등은 앱 정책·클라에 반영.

---

## Attribute Specifications (엔티티별 사양/예시)

### 1) USERS

| 항목          | 타입          | PK/FK | 인덱스                | 제약                            |
| ----------- | ----------- | ----- | ------------------ | ----------------------------- |
| id          | uuid        | PK    | btree(id)          | not null, gen\_random\_uuid() |
| nickname    | text        |       |                    | 길이 1..24, 이모지 허용              |
| created\_at | timestamptz |       | btree(created\_at) | default now()                 |
| created\_by | text        |       |                    | Edge 함수명/시스템 식별자              |

**예시**

| id(예시) | nickname | created\_at       | created\_by |
| ------ | -------- | ----------------- | ----------- |
| 3a6f…  | “Me”     | 2025-08-24T02:10Z | edge\:init  |

---

### 2) ROOMS

| 항목          | 타입          | PK/FK       | 인덱스                | 제약                                 |
| ----------- | ----------- | ----------- | ------------------ | ---------------------------------- |
| id          | uuid        | PK          | btree(id)          | not null                           |
| code        | text        |             | unique(code)       | `^[A-Z0-9]{6,8}$` CHECK            |
| status      | text        |             | btree(status)      | `IN ('waiting','playing','ended')` |
| created\_by | uuid        | FK→USERS.id | btree(created\_by) | not null                           |
| created\_at | timestamptz |             | btree(created\_at) | default now()                      |

**예시**

| id    | code     | status  | created\_by | created\_at       |
| ----- | -------- | ------- | ----------- | ----------------- |
| 7b1e… | “AB12CD” | waiting | 3a6f…       | 2025-08-24T02:12Z |

---

### 3) PLAYERS

| 항목         | 타입          | PK/FK    | 인덱스                       | 제약        |
| ---------- | ----------- | -------- | ------------------------- | --------- |
| id         | uuid        | PK       | btree(id)                 |           |
| room\_id   | uuid        | FK→ROOMS | btree(room\_id)           |           |
| user\_id   | uuid        | FK→USERS | btree(user\_id)           |           |
| nickname   | text        |          |                           |           |
| score      | int         |          |                           | default 0 |
| last\_seen | timestamptz |          | btree(last\_seen)         |           |
|            |             |          | unique(room\_id,user\_id) |           |

**예시**

| id    | room\_id | user\_id | nickname | score | last\_seen        |
| ----- | -------- | -------- | -------- | ----- | ----------------- |
| 91cc… | 7b1e…    | 3a6f…    | “Me”     | 1     | 2025-08-24T02:20Z |

---

### 4) ROUNDS

| 항목               | 타입          | PK/FK    | 인덱스                          | 제약                      |
| ---------------- | ----------- | -------- | ---------------------------- | ----------------------- |
| id               | uuid        | PK       | btree(id)                    |                         |
| room\_id         | uuid        | FK→ROOMS | btree(room\_id, started\_at) | not null                |
| drawer\_user\_id | uuid        | FK→USERS | btree(drawer\_user\_id)      |                         |
| answer           | text        |          |                              | 1..32, 한글/영문/숫자         |
| status           | text        |          | btree(status)                | `IN('playing','ended')` |
| winner\_user\_id | uuid        | FK→USERS | btree(winner\_user\_id)      | nullable                |
| started\_at      | timestamptz |          | btree(started\_at)           | default now()           |
| ended\_at        | timestamptz |          |                              | nullable                |

**예시**

| id    | room\_id | drawer\_user\_id | answer | status  | winner\_user\_id | started\_at       |
| ----- | -------- | ---------------- | ------ | ------- | ---------------- | ----------------- |
| c201… | 7b1e…    | 3a6f…            | “기린”   | playing | null             | 2025-08-24T02:22Z |

---

### 5) DRAWINGS

| 항목            | 타입          | PK/FK     | 인덱스                   | 제약            |
| ------------- | ----------- | --------- | --------------------- | ------------- |
| id            | uuid        | PK        | btree(id)             |               |
| round\_id     | uuid        | FK→ROUNDS | btree(round\_id)      |               |
| storage\_path | text        |           | unique(storage\_path) | not null      |
| width         | int         |           |                       | 64..4096      |
| height        | int         |           |                       | 64..4096      |
| created\_at   | timestamptz |           | btree(created\_at)    | default now() |

**예시**

| id    | round\_id | storage\_path     | width | height | created\_at       |
| ----- | --------- | ----------------- | ----- | ------ | ----------------- |
| 4df0… | c201…     | drawings/c201.png | 360   | 360    | 2025-08-24T02:23Z |

---

### 6) GUESSES

| 항목               | 타입          | PK/FK     | 인덱스                                          | 제약                 |
| ---------------- | ----------- | --------- | -------------------------------------------- | ------------------ |
| id               | uuid        | PK        | btree(id)                                    |                    |
| round\_id        | uuid        | FK→ROUNDS | btree(round\_id, created\_at)                | not null           |
| user\_id         | uuid        | FK→USERS  | btree(user\_id)                              |                    |
| text             | text        |           |                                              | 1..64              |
| normalized\_text | text        |           | btree(round\_id, normalized\_text)           | lower/trim/특수문자 제거 |
| is\_correct      | boolean     |           | partial unique (round\_id) where is\_correct | **라운드당 1개만 true**  |
| created\_at      | timestamptz |           | btree(created\_at)                           | default now()      |

**예시**

| id    | round\_id | user\_id | text   | normalized\_text | is\_correct | created\_at       |
| ----- | --------- | -------- | ------ | ---------------- | ----------- | ----------------- |
| 8a9e… | c201…     | 55db…    | “기 린!” | “기린”             | true        | 2025-08-24T02:24Z |

---

### 7) COIN\_TX (보상/차감 원장)

| 항목              | 타입          | PK/FK     | 인덱스                                                             | 제약                                          |
| --------------- | ----------- | --------- | --------------------------------------------------------------- | ------------------------------------------- |
| id              | uuid        | PK        | btree(id)                                                       |                                             |
| user\_id        | uuid        | FK→USERS  | btree(user\_id, created\_at)                                    |                                             |
| type            | text        |           | btree(type)                                                     | `IN('SEND','RECEIVE','AD_REWARD','REDEEM')` |
| amount          | int         |           |                                                                 | `<> 0` (가산/감산)                              |
| ref\_round\_id  | uuid        | FK→ROUNDS | btree(ref\_round\_id)                                           | nullable                                    |
| ref\_ad\_tx\_id | text        |           | btree(ref\_ad\_tx\_id)                                          | nullable                                    |
| idem\_key       | text        |           | **partial unique(type, idem\_key) where idem\_key is not null** | Idempotency                                 |
| created\_at     | timestamptz |           | btree(created\_at)                                              | default now()                               |
| created\_by     | text        |           |                                                                 | Edge 함수명                                    |

**예시**

| id    | user\_id | type    | amount | ref\_round\_id | ref\_ad\_tx\_id | idem\_key       | created\_at       |
| ----- | -------- | ------- | ------ | -------------- | --------------- | --------------- | ----------------- |
| 6b77… | 55db…    | RECEIVE | +10    | c201…          | null            | rcpt\:c201:55db | 2025-08-24T02:25Z |

---

### 8) AD\_RECEIPTS (SSV 원본 영수증)

| 항목               | 타입          | PK/FK    | 인덱스                          | 제약            |
| ---------------- | ----------- | -------- | ---------------------------- | ------------- |
| idempotency\_key | text        | **PK**   |                              | not null      |
| user\_id         | uuid        | FK→USERS | btree(user\_id, created\_at) |               |
| provider\_tx\_id | text        |          | unique(provider\_tx\_id)     | not null      |
| key\_id          | text        |          | btree(key\_id)               | 공개키 식별자       |
| signature        | text        |          |                              | 원본 서명         |
| payload          | jsonb       |          | gin(payload)                 | 원본 요청         |
| amount           | int         |          |                              | =50 (정책 상수)   |
| verified\_at     | timestamptz |          |                              | 검증 성공 시각      |
| created\_at      | timestamptz |          | btree(created\_at)           | default now() |

**예시**

| idempotency\_key       | user\_id | provider\_tx\_id | key\_id | amount | verified\_at      |
| ---------------------- | -------- | ---------------- | ------- | ------ | ----------------- |
| admob:20250824\:abc123 | 3a6f…    | caa-88…          | k1      | 50     | 2025-08-24T02:30Z |

---

### 9) PALETTES

| 항목                   | 타입          | PK/FK | 인덱스                         | 제약            |
| -------------------- | ----------- | ----- | --------------------------- | ------------- |
| id                   | uuid        | PK    | btree(id)                   |               |
| name                 | text        |       | unique(name)                |               |
| swatches             | jsonb       |       | gin(swatches)               | 색 목록(6\~8)    |
| price\_coins         | int         |       |                             | >0            |
| is\_colorblind\_safe | boolean     |       | btree(is\_colorblind\_safe) | default false |
| created\_at          | timestamptz |       | btree(created\_at)          | default now() |

**예시**

| id    | name   | swatches(예시)                    | price\_coins | is\_colorblind\_safe |
| ----- | ------ | ------------------------------- | ------------ | -------------------- |
| 1f20… | “Mono” | `["#000","#444","#888","#FFF"]` | 120          | true                 |

---

### 10) USER\_PALETTES

| 항목           | 타입          | PK/FK       | 인덱스                           | 제약            |
| ------------ | ----------- | ----------- | ----------------------------- | ------------- |
| id           | uuid        | PK          | btree(id)                     |               |
| user\_id     | uuid        | FK→USERS    | btree(user\_id)               |               |
| palette\_id  | uuid        | FK→PALETTES | btree(palette\_id)            |               |
| unlocked\_at | timestamptz |             | btree(unlocked\_at)           | default now() |
|              |             |             | unique(user\_id, palette\_id) |               |

**예시**

| id    | user\_id | palette\_id | unlocked\_at      |
| ----- | -------- | ----------- | ----------------- |
| 9d01… | 3a6f…    | 1f20…       | 2025-08-24T02:40Z |

---

### 11) coin\_balances (VIEW)

| 컬럼       | 타입   | 설명                    |
| -------- | ---- | --------------------- |
| user\_id | uuid | 사용자                   |
| balance  | int  | `SUM(COIN_TX.amount)` |

**예시**

| user\_id | balance |
| -------- | ------- |
| 3a6f…    | 160     |

---

## Relationship Mappings & PK/FK 구조

**Reasoning → Conclusion**: **정답 1명**, **보상 중복 차단**, **SSV 중복 차단**이 핵심 제약이다.

* **USERS 1\:N** PLAYERS/GUESSES/ROUNDS/COIN\_TX/AD\_RECEIPTS/USER\_PALETTES
* **ROOMS 1\:N** ROUNDS/PLAYERS
* **ROUNDS 1:1** DRAWINGS, **1\:N** GUESSES/COIN\_TX
* **PALETTES M\:N USERS** via USER\_PALETTES
* **Partial Unique**: `GUESSES(round_id) WHERE is_correct=true` → **라운드당 1명 우승자**
* **Idempotency**: `COIN_TX(type, idem_key) WHERE idem_key IS NOT NULL`, `AD_RECEIPTS(idempotency_key PK)`

---

## Index Strategy

**Reasoning → Conclusion**: **실시간 상태 읽기**와 **경쟁 쓰기**(정답/SSV)에 최적.

* **시간축 조회**: `created_at` 공통 btree
* **관계축**: `room_id`, `round_id`, `user_id` 복합/단일 btree
* **Partial Unique**:

  * `GUESSES_unique_correct_per_round`: `UNIQUE(round_id) WHERE is_correct`
  * `COIN_TX_unique_idem`: `UNIQUE(type, idem_key) WHERE idem_key IS NOT NULL`
* **JSONB**: `PALETTES.swatches` GIN (색 검색·A/B 필요 시)
* **고빈도 읽기**: `ROOMS(code)` UNIQUE, `DRAWINGS(storage_path)` UNIQUE

---

## Constraints & Business Rules

**Reasoning → Conclusion**: **서버 권위 + 제약 + 부분 유니크**로 규칙을 DB에 내재화.

* **정답**: 라운드당 `is_correct=true` **오직 1행**(Partial Unique)
* **보상**: `COIN_TX.amount <> 0`, 타입 제한, **Idempotency 필수**
* **광고**: `AD_RECEIPTS.idempotency_key` PK, `provider_tx_id` UNIQUE
* **팔레트**: `USER_PALETTES(user_id,palette_id)` UNIQUE
* **룸 코드**: `^[A-Z0-9]{6,8}$` CHECK
* **일일 캡**: DB에는 집계 쿼리 + Edge 검증(플래그)로 강제

**Note:** AD\_REWARD는 **SSV 검증 성공 시**만 `COIN_TX` 적립. (서명=ECDSA/SHA-256, 공개키 JSON by `key_id`)

---

## Data Types & Validation Rules

**Reasoning → Conclusion**: Postgres 네이티브 타입/제약으로 **런타임 오류를 사전에 차단**.

* **uuid**(PK/FK), **timestamptz**, **int**, **text**, **jsonb**, **boolean**
* **CHECK**: 상태/코드/금액 범위, width/height 범위
* **Regex**: ROOM `code`
* **정규화 텍스트**: `GUESSES.normalized_text`(lower+trim+특수문자 제거), 필요 시 **functional index**(예: `btree(round_id, normalized_text)`)

---

## Normalization Analysis

**Reasoning → Conclusion**: 3NF 유지, 읽기 최적화는 **뷰**로 분리.

* 엔티티 간 다대일/다대다 관계를 명확화(PLAYERS, USER\_PALETTES 중간 테이블)
* **중복 필드 최소화**: 닉네임 스냅샷은 PLAYERS에 한정(룸 맥락용)
* **뷰**: `coin_balances`로 잔액 계산 최적화(원장=COIN\_TX는 불변)

---

## Performance Optimization (샘플 쿼리)

**Reasoning → Conclusion**: **핵심 쿼리**를 인덱스 친화적으로 정의.

1. **룸 현재 상태 + 최신 라운드/그림**

```sql
SELECT r.id AS room_id, r.status AS room_status,
       rd.id AS round_id, rd.status AS round_status, dr.storage_path
FROM rooms r
LEFT JOIN LATERAL (
  SELECT * FROM rounds WHERE room_id = r.id ORDER BY started_at DESC LIMIT 1
) rd ON true
LEFT JOIN drawings dr ON dr.round_id = rd.id
WHERE r.code = 'AB12CD';
```

2. **정답 제출(동시성 안전)**

```sql
-- 1) INSERT guess
INSERT INTO guesses(id, round_id, user_id, text, normalized_text, is_correct)
VALUES (gen_random_uuid(), $1, $2, $3, $4, $5);

-- 2) is_correct=true면 첫 승자만 성공(Partial Unique 충돌 시 패자)
-- 3) 성공 시 rounds.winner_user_id 업데이트 + award_receive 코인 적립(Edge 트랜잭션)
```

3. **SSV 적립(Idempotency)**

```sql
-- 1) 영수증 삽입(중복이면 충돌)
INSERT INTO ad_receipts(idempotency_key, user_id, provider_tx_id, key_id, signature, payload, amount, verified_at)
VALUES ($idem, $uid, $ptx, $kid, $sig, $payload::jsonb, 50, now());

-- 2) 보상 원장 기록(부분 유니크로 중복 차단)
INSERT INTO coin_tx(id, user_id, type, amount, ref_ad_tx_id, idem_key, created_by)
VALUES (gen_random_uuid(), $uid, 'AD_REWARD', 50, $ptx, $idem, 'edge:ad-ssv');
```

4. **잔액 조회(뷰)**

```sql
SELECT b.balance FROM coin_balances b WHERE b.user_id = $1;
```

---

## Migration & Versioning Strategy

**Reasoning → Conclusion**: **전방 호환**을 유지하고, 뷰/인덱스를 활용해 단계적 배포.

* **버전 태깅**: `schema_version` 테이블 + Git 태그
* **Non-breaking 우선**: ADD COLUMN NULLABLE → 백필 → NOT NULL+DEFAULT
* **뷰 호환**: `coin_balances_v1` 유지 후 `coin_balances`로 스왑
* **인덱스 롤링**: 동시 생성→REINDEX CONCURRENTLY
* **릴리즈 체크**: Partial Unique/권한 변화는 사전 드라이런

---

## RLS Overview

**Reasoning → Conclusion**: **읽기 최소**, \*\*쓰기=Edge(service\_role)\*\*로 단순·안전하게.

* **공통**: 모든 테이블 **RLS ON**
* **선택적 읽기**

  * ROOMS/ROUNDS/DRAWINGS/GUESSES: \*\*룸 멤버(PLAYERS.user\_id=auth.uid())\*\*에게만 SELECT
  * COIN\_TX/AD\_RECEIPTS/USER\_PALETTES: **자기것만 SELECT**
  * PALETTES: 공개 읽기(가격표) 가능
* **쓰기**: INSERT/UPDATE/DELETE는 **Edge 전용**(service\_role)
* **감사**: `created_by`에 Edge 함수명 기록, 보상 실패/충돌은 에러 코드와 함께 로깅

---

## (가정/리스크/백로그)

| 구분  | 내용                                                                 |
| --- | ------------------------------------------------------------------ |
| 가정  | 트래픽은 초기 베타(저\~중), 파티션/샤딩은 불필요                                      |
| 리스크 | SSV 지연/실패, Partial Unique 충돌 처리 미흡 시 UX 이탈                         |
| 백로그 | 라운드 TTL/아카이브, 스트로크 저장(리플레이), Materialized View(상점/통계), 운영용 감사 대시보드 |

**Note:** 플랫폼/정책 관련: **Google Play Target API 35 (2025-08-31)**, **iOS 14.5+ ATT**, \*\*AdMob SSV(공개키 JSON·ECDSA 서명 검증)\*\*는 앱/서버 구현 시 준수되어야 하며, 키 회전/서명 검증 실패 시 보상은 적립되지 않음.
