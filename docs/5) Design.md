What: “너랑 나의 그림퀴즈”를 **Cursor** 중심으로 백엔드→DB→프론트엔드까지 ‘문서 주도(문서→코드)’로 빌드하는 실전 작업 방식
Why: 1인·1주에선 **도구 체인 단순화**와 **자동화 가능한 반복 작업의 위임**이 결정적
How-Now: **모노레포 1개** + **Supabase(관리형)** + **Flutter 앱** + **Cursor 프롬프트 시나리오**(백엔드→프론트→광고/SSV→딥링크) 순으로 단계 실행

---

## 0) FAQ 먼저 — “Flutter를 MCP로 연결해야 하나?”

**Reasoning → Conclusion**: MCP(Model Context Protocol)는 “AI ↔ 도구(파일, 셸, DB 등)”를 연결하는 **프로토콜/서버 생태계**야. **Flutter는 프레임워크**이지 MCP 서버가 아님.

* 결론: **Flutter를 MCP로 연결할 필요 없음.**
* 다만, IDE(예: Cursor)가 MCP를 지원한다면 **셸/파일/깃/HTTP/DB** 같은 MCP 서버를 붙여 자동화를 늘릴 수는 있음(선택사항).
* 오늘 설계는 **MCP 없어도** 1주 완주 가능하게 짬.

**(가정/리스크/백로그)**

| 구분  | 내용                                         |
| --- | ------------------------------------------ |
| 가정  | Cursor 기본 기능(파일 편집/터미널/리포 플로우) 사용          |
| 리스크 | MCP 서버 구성에 시간 소요 시 일정 지연                   |
| 백로그 | 로컬 Postgres·Supabase CLI·HTTP 클라이언트 MCP 연동 |

---

## 1) 개발 환경 준비 (한 번만)

**Reasoning → Conclusion**: 충돌을 줄이려면 **SDK·CLI·키/시크릿**을 초기에 고정.

* **필수 설치**:

  * Flutter SDK, Android Studio(AVD), Xcode(iOS), Dart/Java JDK(안드), CocoaPods(iOS)
  * Supabase 프로젝트(관리형) + **Supabase CLI**
  * Deno(Edge Functions)
  * Kakao Developers 앱(네이티브 키·URL 스킴)
* **프로젝트 시크릿**(로컬에 저장):

  * `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SERVICE_ROLE_KEY`(로컬만)
  * Kakao `NATIVE_APP_KEY`, iOS URL 스킴, Android manifest 설정 값
  * AdMob 테스트 단위 ID(실계정은 나중에)

**(가정/리스크/백로그)**

| 구분  | 내용                                |
| --- | --------------------------------- |
| 가정  | Supabase는 **관리형**으로 바로 사용         |
| 리스크 | iOS 서명·프로비저닝 후반부 이슈               |
| 백로그 | DevContainer/VSCode Remote로 환경 고정 |

---

## 2) 저장소 구조(모노레포) & 표준 스크립트

**Reasoning → Conclusion**: **문서→코드** 파이프라인을 유지하려면 **폴더 컨벤션**이 핵심.

```
quizdraw/
├─ app/                     # Flutter
│  ├─ lib/                  # UI, state, API
│  ├─ android/ ios/ web/
│  └─ pubspec.yaml
├─ supabase/
│  ├─ migrations/           # SQL 마이그레이션
│  ├─ seed/                 # 팔레트 등 초기 데이터
│  └─ functions/
│     ├─ start-round/
│     ├─ verify-guess/
│     ├─ award-send/
│     ├─ ad-ssv/
│     └─ redeem/
├─ docs/                    # PRD, IA, Use-Case, ERD, Design (네가 만든 문서들)
├─ scripts/                 # 배포/검증 스크립트
└─ .env.example / .env.local
```

**권장 NPM 스크립트(또는 Makefile)**

* `scripts/dev-backend.sh` : SQL 적용, 로컬 함수 serve
* `scripts/deploy-backend.sh` : Edge deploy + 정책 반영
* `scripts/dev-app.sh` : `flutter run` with `--dart-define` 값 주입
* `scripts/checklist.sh` : 릴리스 체크(딥링크/광고 테스트/빌드)

**(가정/리스크/백로그)**

| 구분  | 내용                    |
| --- | --------------------- |
| 가정  | DB는 마이그레이션 파일로만 변경    |
| 리스크 | 수동 콘솔 변경 → 코드-실환경 불일치 |
| 백로그 | CI에서 마이그레이션 검증 파이프라인  |

---

## 3) Cursor로 “문서→코드” 작업 흐름 (권장 시나리오)

**Reasoning → Conclusion**: **큰 요청 → 파일 생성 → 실행 명령 → 실패 로그 수정** 패턴으로 굴린다.

### 3.1 시작 프롬프트(루트에 붙여 쓰기)

* 목적: \*\*docs/\*\*에 있는 **PRD, IA, Use-Case, ERD, Design**을 읽고, \*\*supabase/\*\*와 \*\*app/\*\*를 생성.
* 붙여넣기(Clipboard-safe):

**“Cursor에게 이렇게 말해줘”**

* “역할: Senior Full-Stack(Flutter+Supabase+Deno).
* 입력: `docs/`의 PRD.md, IA.md, Use-Case.md, ERD.md, DESIGN.md.
* 산출물:

  1. `supabase/migrations/*.sql`(엔티티·인덱스·RLS),
  2. `supabase/functions/{start-round,verify-guess,award-send,ad-ssv,redeem}/index.ts`(Deno),
  3. `app/lib/`에 API 클라이언트/모델/화면 스캐폴딩(IA 준수),
  4. `scripts/` 배포 스크립트.
* 제약:

  * 보상/판정/차감은 Edge만(클라이언트 금지).
  * `GUESSES`에 **부분 유니크**(라운드당 정답 1개).
  * `COIN_TX`에 **idem unique**. `AD_RECEIPTS` **PK=idempotency\_key**.
  * Dart Define로 Supabase/Kakao 키 주입.
  * Kakao 공유는 디폴트 템플릿 호출부만 배치(실 키는 .env).
  * 광고는 `google_mobile_ads` 연동하되 **SSV 성공 후만** 잔액 반영(실 서버 콜).
* 실행 순서:
  ① SQL→`supabase db push` 수준의 마이그 적용 파일 생성,
  ② Edge 함수 로컬 `serve` 준비,
  ③ Flutter 탭/모달 스켈레톤,
  ④ ‘광고+50’은 테스트 버튼 & 더미 SSV(로컬)로 먼저 검증.
* 출력: 변경 파일 목록과 실행 명령을 **블록**으로 요약.”

### 3.2 “파일 생성 후” Cursor에 시킬 체크

* `migrations`에 **Partial Unique/Idem 인덱스**가 들어갔는지
* `functions/ad-ssv/index.ts`에 **ECDSA 검증 스텁**(실 키 주입 포인트) 표기
* `app/lib/`에 **딥링크 라우트**(`app://room/:id`, `app://round/:id?invite=:i`) 스택 존재
* `Palette` 해금이 **원자적 차감 + 소유 기록** 트랜잭션으로 작성됐는지

**(가정/리스크/백로그)**

| 구분  | 내용                           |
| --- | ---------------------------- |
| 가정  | Cursor가 다중 파일 수정/생성에 능숙      |
| 리스크 | 장문 문서 요약 중 누락 발생             |
| 백로그 | 파일별 “수정 diff → 근거 문서 섹션” 링크화 |

---

## 4) 백엔드: Supabase 빠른 구축 순서

**Reasoning → Conclusion**: **관리형 Supabase**에 바로 배포하면 1주 달성이 쉽다.

1. **DB 스키마 적용**: `supabase/migrations/0001_init.sql`에 엔티티/인덱스/RLS 작성 → 배포
2. **Storage**: `drawings` 버킷 생성, PNG 정책(≤5MB)
3. **Edge Functions** (Deno):

   * `start-round`: 라운드 생성
   * `verify-guess`: 정규화 비교, **first-correct** 처리(부분 유니크 충돌 시 409)
   * `award-send`: 라운드당 1회 +10, **idem** 체크
   * `ad-ssv`: SSV 서명검증→`AD_RECEIPTS`→`COIN_TX`(+50)
   * `redeem`: 잔액≥가격 확인→차감→소유 기록
4. **환경변수/시크릿**: 서비스 키, 광고 공개키 JSON 캐시 URL, Kakao 템플릿 ID 등
5. **배포 스크립트**: `scripts/deploy-backend.sh`에서 `supabase functions deploy *`

**(가정/리스크/백로그)**

| 구분  | 내용                                  |
| --- | ----------------------------------- |
| 가정  | Edge는 서비스 롤키로 DB 접근                 |
| 리스크 | RLS 누락/오인으로 403/권한 과노출              |
| 백로그 | observability: 에러 로깅·지표 수집(SSV 실패율) |

---

## 5) 프론트엔드: Flutter 구현 순서

**Reasoning → Conclusion**: \*\*IA(탭 3 + Room 모달)\*\*로 스캐폴딩한 뒤 API만 얹는다.

1. `flutter create app` → `pubspec.yaml`에 `supabase_flutter`, `google_mobile_ads`, `kakao_flutter_sdk_*` 추가
2. 앱 시작 시 `Supabase.initialize(...)` + **Dart Define**로 키 주입
3. **네비 구조**(BottomTabs: Home/Palette/Settings; Room 내부 모달: Draw/Guess/Result)
4. **API 래퍼**: `client.from('...')` + Edge 호출 클라이언트
5. **광고 버튼**: 시청 완료 시 UI는 “검증 중”, **실 적립은 SSV 수신 후** 반영
6. **딥링크 처리**: `uni_links` 등으로 `app://room/:id` 수신
7. **접근성**: ≥48dp, 16–18sp, 고대비 토글(Theme)

**(가정/리스크/백로그)**

| 구분  | 내용                         |
| --- | -------------------------- |
| 가정  | Kakao 공유는 템플릿 호출만 MVP에 포함  |
| 리스크 | iOS 빌드 서명/권한 스텝에서 시간 손실    |
| 백로그 | 스트로크 저장·리플레이, 친구 선택 API 추가 |

---

## 6) 하루 단위 실행 플랜(1주)

**Reasoning → Conclusion**: **백→프론트→보상/광고→딥링크** 순서가 리스크 최소.

| Day | 목표                               | 검증(Verification)        |
| --- | -------------------------------- | ----------------------- |
| D1  | 레포/환경/모노레포·문서 반영                 | `supabase db` 스키마 적용 OK |
| D2  | Edge 3종(start/verify/award-send) | 동시 정답 충돌 테스트(한 명만 승자)   |
| D3  | Flutter 탭/Room/Draw/Guess 스캐폴드   | 업로드→라운드 상태 전이 확인        |
| D4  | `redeem`·Palette/코인 뷰            | 원자적 차감·소유 기록            |
| D5  | 광고 버튼·`ad-ssv`(로컬 키)             | SSV 성공만 잔액 반영, idem 차단  |
| D6  | 딥링크·공유 템플릿·접근성 튜토리얼              | 앱 설치→복귀 경로 OK           |
| D7  | QA(저사양/오프라인/충돌)·릴리스 스크린샷         | KPI 이벤트 파이어링 점검         |

---

## 7) 로컬 실행·배포 “명령 세트”(복붙)

**Reasoning → Conclusion**: 명령 묶음이 있으면 **Cursor 터미널**에서 그대로 돌릴 수 있다.

```bash
# 백엔드
cd supabase
# 1) 마이그레이션 적용(관리형)
supabase db push
# 2) 함수 로컬 테스트
supabase functions serve --env-file ../.env.local
# 3) 배포
supabase functions deploy start-round verify-guess award-send ad-ssv redeem

# 프론트엔드
cd ../app
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=KAKAO_NATIVE_KEY=...
```

**(가정/리스크/백로그)**

| 구분  | 내용                       |
| --- | ------------------------ |
| 가정  | supabase 프로젝트 권한/네트워크 OK |
| 리스크 | 사내 프록시/방화벽으로 함수 serve 실패 |
| 백로그 | CI 파이프라인(포맷/테스트/배포) 추가   |

---

## 8) 검증 체크리스트(런타임)

**Reasoning → Conclusion**: 핵심 제약이 지켜지는지 **실제로 쏴보고** 확인.

* GUESSES: **동시 정답** 2개 전송 → 1개만 `is_correct=true`(409 충돌 로그 존재)
* COIN\_TX: 같은 `idem_key`로 2회 호출 → 1회만 적립
* AD\_RECEIPTS: 동일 `provider_tx_id` 2회 → 2번째 UNIQUE 에러
* `coin_balances` 뷰: SEND/RECEIVE/AD/REDEEM 시 실시간 합계 정확
* 딥링크: 앱 미설치→웹 폴백→설치 후 Room 복귀

**(가정/리스크/백로그)**

| 구분  | 내용                     |
| --- | ---------------------- |
| 가정  | 테스트 단위/스텁 키로 SSV 시뮬 가능 |
| 리스크 | 실 네트워크 SSV 지연으로 UX 혼선  |
| 백로그 | SSV 대기 배너/이벤트 재동기화 버튼  |

---

## 9) “Cursor에게 던질 추가 프롬프트” 모음

**Reasoning → Conclusion**: 반복 작업을 **프롬프트 템플릿**으로 고정하면 속도가 2배.

* **백엔드 정책 리뷰**
  “`supabase/migrations/*.sql`에서 RLS가 ‘내 데이터만 읽기’로 구현됐는지 점검하고, 누락된 SELECT 정책을 제안/패치 PR을 만들어줘. 바뀐 파일과 이유를 요약해.”
* **동시성 테스트**
  “`functions/verify-guess`에 **동시 제출** 부하 테스트 스크립트를 만들어줘. 100동시에서 우승자 1명만 확정되는지 로깅 포함.”
* **프론트 이벤트 매핑**
  “Use-Case의 이벤트 표대로 `analytics.dart` 헬퍼를 만들고, 각 화면에서 호출 지점을 TODO 주석으로 표시해줘.”

**(가정/리스크/백로그)**

| 구분  | 내용                           |
| --- | ---------------------------- |
| 가정  | Cursor가 변경 사유를 PR 설명으로 첨부    |
| 리스크 | 자동 수정이 과도하면 코드 맥락 붕괴         |
| 백로그 | Lint/format/commit-msg 규칙 도입 |

---

## 결론

* **어디서?** 한 저장소(모노레포)에서 **Cursor**로 문서→코드 생성/수정/실행을 반복.
* **어떻게?** ① 문서(`docs/`)를 소스로 삼아 ② Supabase 스키마/함수 생성 ③ Flutter 스캐폴딩 ④ 광고/SSV/딥링크 ⑤ 검증 체크리스트.
* **MCP?** 선택 사항. **필수 아님.** 나중에 “셸·파일·DB” 같은 MCP 서버를 붙여 자동화를 늘리면 됨.

---

(가정/리스크/백로그)

| 구분  | 내용                                                            |
| --- | ------------------------------------------------------------- |
| 가정  | 관리형 Supabase·테스트 AdMob로 1주 내 완주 가능                            |
| 리스크 | iOS 서명·광고 계정 설정·카카오 템플릿 승인 지연                                 |
| 백로그 | MCP 기반 셸/DB/HTTP 서버 연동, CI/CD(프리뷰 앱), 관측 대시보드(SSV 실패율·정답 경합률) |
