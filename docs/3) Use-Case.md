What: 전연령 소셜 그림 퀴즈 \*\*“너랑 나의 그림퀴즈”\*\*의 **Use-Case 문서**(핵심/예외/검증 포함)
Why: 1주 MVP에서 **짧은 동선·안정적 보상·접근성**을 보장하고, 운영·보안 리스크를 초기부터 최소화
How-Now: **Flutter + Supabase + Kakao Share + AdMob SSV** 전제로, **모달형 Room 루프**와 **서버 권위(Idempotency/캡)** 중심 설계

---

## 목차

* Actor Definitions
* Use Case Scenarios (Happy/Sad)
* Main Steps (numbered, User/System, Verification)

  * Drawer(라운드 시작→그림→공유→award\_send)
  * Guesser(딥링크→입장→정답→검증→award\_receive)
  * Ad Reward(시청→SSV 콜백→적립)
  * Palette Unlock(코인 차감→해금)
* Alternative Flows & Edge Cases
* Preconditions & Postconditions
* Business Rules & Constraints
* Exception Handling Procedures (tables)
* User Interface Considerations
* Data Requirements & Data Flow
* Security & Privacy Considerations
* (가정/리스크/백로그)

---

## Actor Definitions

**Reasoning → Conclusion**: 행위자 역할을 명확히 분리하면 \*\*경계(권한/책임)\*\*와 **예외 처리**가 단순해진다.

| Actor          | 역할                        | 주요 권한/제약                                      |
| -------------- | ------------------------- | --------------------------------------------- |
| Drawer         | 라운드 생성·그림 업로드·초대          | 라운드당 **award\_send(+10)** 1회 한정               |
| Guesser        | 딥링크로 입장·정답 제출             | **first-correct**일 때만 **award\_receive(+10)** |
| System         | Edge Functions/Storage/DB | 판정·보상·일일 캡·Idempotency **서버 권위**              |
| Ad Network SSV | 보상형 광고 검증 콜백              | **SSV 서명/키검증 필수** 성공 시만 적립                    |
| Kakao Share    | 사용자 주도 공유 채널              | 템플릿/딥링크 파라미터 전달, 자동 DM 금지                     |
| Admin(후순위)     | 신고 대응·비노출 처리              | 베타는 **수동** 운영(자동 NSFW 후순위)                    |

**(가정/리스크/백로그)**

| 구분  | 내용                            |
| --- | ----------------------------- |
| 가정  | 게스트 계정으로도 전 기능 사용 가능          |
| 리스크 | Actor 혼재(동일 단말 다중 계정)로 메트릭 왜곡 |
| 백로그 | Admin 도구(리스트·필터·감사로그)         |

---

## Use Case Scenarios (Happy/Sad)

**Reasoning → Conclusion**: 핵심 루프의 **성공/실패**를 짝으로 정의해 복구 포인트를 노출한다.

* **Happy(핵심)**

  1. Drawer가 라운드 시작 → 그림 업로드 → Kakao 공유 → **award\_send +10**
  2. Guesser가 링크 오픈 → Room 합류 → 정답 입력 → **first-correct** 판정 → **award\_receive +10**
  3. 사용자가 광고 시청 완료 → **SSV 성공** → **+50** 적립
  4. 코인으로 팔레트 해금 → 성공 토스트 + UI 반영
* **Sad(대표)**

  * 업로드 실패/중복, 딥링크 미동작, 동시 정답 경합, 광고 취소/SSV 미수신, 오프라인 시도, 앱 종료 중단

**(가정/리스크/백로그)**

| 구분  | 내용                       |
| --- | ------------------------ |
| 가정  | 실패 시 모두 “재시도/취소” 분기 제공   |
| 리스크 | 잦은 실패 토스트는 피로도 증가        |
| 백로그 | 실패 후 **가이드형 배너**(해결책 제시) |

---

## Main Steps

### A) Drawer: 라운드 시작 → 그리기/업로드 → 공유 → award\_send(+10)

**Reasoning → Conclusion**: Drawer 플로우는 **최소 단계**와 **서버 집행 보상**이 핵심.

1. **User**: Home에서 **\[빠른 시작]** 탭 → Room(대기) 진입
2. **System**: `room_create` 로깅, Room 상태=대기
3. **User**: **\[라운드 시작]** → Draw 모달 오픈
4. **System**: `round_start` 생성, Drawer 권한 확인
5. **User**: 캔버스에 그림 → **\[업로드]**
6. **System**: 이미지 압축/업로드(정책 검증) → Drawing 링크 저장 → **award\_send** 호출
7. **System**: 보상 규칙 검사(라운드당 1회/일일 캡/idem) 통과 시 **+10** 적립, `reward_send` 이벤트
8. **User**: Room으로 복귀, **\[공유]** 버튼으로 Kakao Share 실행(딥링크 포함)

**Verification:**

* `round_start`, `drawing_upload(size_kb,dur_ms)`, `reward_send(idem_key)`, `share_click` 이벤트 생성
* 사용자 잔액 **+10** 반영(잔액 배지/토스트)
* 라운드 상태=플레이 확인

---

### B) Guesser: 딥링크 → 입장 → 정답 제출 → first-correct → award\_receive(+10)

**Reasoning → Conclusion**: **딥링크 성공률**과 **first-correct 판정**이 핵심.

1. **User(Guesser)**: Kakao 메시지의 초대 링크 탭
2. **System**: 딥링크 파라미터 해석 → 미설치 시 **웹 폴백** → 설치/복귀 후 Room Join
3. **User**: Guess 모달에서 그림 확인 → 정답 입력 → **\[제출]**
4. **System**: 정규화(소문자/공백/기호 제거) 비교 → **first-correct** 경쟁 처리(원자적)
5. **System**: 승자라면 **award\_receive** 실행(라운드당 1회/일일 캡/idem) → **+10** 적립
6. **User**: Result 모달에서 정답/보상 확인 → **\[다시하기]** 또는 **\[나가기]**

**Verification:**

* `deeplink_open(r,i)`, `guess_submit`, `guess_correct(first_winner=true)`, `reward_receive` 이벤트
* 잔액 **+10** 반영, 라운드 종료 플래그 확인
* 동시성 테스트(두 클라이언트 동시 제출 시 한쪽만 승자)

---

### C) Ad Reward: 시청 → **SSV 콜백** → 적립(+50, 일일캡/idem)

**Reasoning → Conclusion**: 보상형 광고는 **클라이언트 신호를 신뢰하지 않고** **SSV만** 인정.

1. **User**: Home/Palette에서 **\[광고 보고 +50]** 탭
2. **System**: 광고 로드/표시, `ad_start` 로깅
3. **User**: 영상 시청 완료(또는 취소/닫기)
4. **Ad Network SSV**: 서버로 콜백(서명/`key_id`/거래ID) → **서명·키 검증**
5. **System**: 일일 캡 확인, **idempotency** 체크 → 통과 시 **+50** 적립, `ad_complete_ssv` 로깅
6. **User**: UI에 “적립 완료” 토스트 및 잔액 갱신(실시간/폴링)

**Verification:**

* `ad_complete_ssv(key_id,latency_ms)` 이벤트 비율로 **성공률 ≥95%** 확인
* 동일 거래ID **중복 적립 불가**(idem)
* 일일 캡 도달 시 버튼 비활성/쿨다운

---

### D) Palette Unlock: 코인 차감 → 해금

**Reasoning → Conclusion**: **원자적 차감+소유 기록**이 핵심.

1. **User**: Palette 그리드에서 **\[해금]**
2. **System**: 잔액 ≥ 가격 확인 → **원자적 차감 & 소유 기록** → 성공 응답
3. **User**: 카드 상태가 잠금 → 해금으로 전환, 즉시 캔버스에 색 노출

**Verification:**

* `palette_unlock(palette_id,cost)` 이벤트
* 잔액 감소·소유 목록 동기화
* 이중 탭 시 **idem**으로 중복 해금 방지

---

## Alternative Flows & Edge Cases

**Reasoning → Conclusion**: **조건→행동**을 표준화하면 운영/QA가 단순해진다.

| 상황      | 대안 흐름                                        |
| ------- | -------------------------------------------- |
| 업로드 실패  | Draw 모달 유지 → “재시도/나가기” 분기, 실패 누적 시 네트워크 점검 팁 |
| 딥링크 미동작 | 웹 폴백 랜딩 → 설치 유도 → 첫 실행에 파라미터 전달 보장           |
| 동시 정답   | 서버 타임스탬프/락으로 1명만 승자 처리, 나머지 패자 응답/토스트        |
| 광고 취소   | SSV 없음 → **0 적립**, 버튼 쿨다운/도움말                |
| 오프라인    | 입력 큐에 보관(제출 보류), 온라인 전환 시 자동 재시도             |
| 앱 종료    | 재실행 시 Room 복구 카드 제공(마지막 상태/액션 복귀)            |

**(가정/리스크/백로그)**

| 구분  | 내용                     |
| --- | ---------------------- |
| 가정  | 모든 대안 플로우에서 뒤로가기 동작 일관 |
| 리스크 | 오프라인 큐 충돌(기한 만료된 라운드)  |
| 백로그 | 오프라인 큐 관리 화면(삭제/재시도)   |

---

## Preconditions & Postconditions

**Reasoning → Conclusion**: 각 플로우 전후 상태를 명시하면 **재현성**과 **디버깅**이 쉬워진다.

| 플로우        | 사전조건(Pre)          | 사후조건(Post)                      |
| ---------- | ------------------ | ------------------------------- |
| Drawer 루프  | Room=대기, Drawer 권한 | 라운드=플레이→결과, 코인 **+10**(보상 성공 시) |
| Guesser 루프 | 유효한 딥링크/Room 참여    | 승자 1명 확정, 코인 **+10**(승자)        |
| Ad 보상      | 광고 네트워크 가용, 상한 미도달 | **SSV 성공 시** 코인 **+50**, 상한 갱신  |
| 팔레트 해금     | 잔액 ≥ 가격, 미소유       | 소유 목록에 팔레트 추가, 잔액 차감            |

**(가정/리스크/백로그)**

| 구분  | 내용                         |
| --- | -------------------------- |
| 가정  | 라운드 만료시간(soft TTL) 내부에서 처리 |
| 리스크 | 만료 직전 동작의 경쟁상태             |
| 백로그 | 라운드 TTL 명시(UX 표기)          |

---

## Business Rules & Constraints

**Reasoning → Conclusion**: **상수/캡/권위**를 서버에서 강제해야 초기 어뷰징을 억제.

* 상수: **AD\_REWARD=50, SEND\_REWARD=10, RECEIVE\_REWARD=10**
* 일일 캡(원격 플래그): **ads=5, send=10, receive=10**
* **보상/판정은 서버 전용**(Edge), 항상 **idempotency key** 확인
* 팔레트 가격: **Mono 120 / Pastel 200 / Neon 300**
* 공유는 **사용자 주도**(자동 DM 금지), 소셜 로그인은 **후순위(검증 필요)**

**(가정/리스크/백로그)**

| 구분  | 내용                 |
| --- | ------------------ |
| 가정  | 상수는 런타임 플래그로 조절 가능 |
| 리스크 | 잘못된 플래그 배포로 경제 불안정 |
| 백로그 | 플래그 변경 감사로그/롤백 버튼  |

---

## Exception Handling Procedures

**Reasoning → Conclusion**: 예외는 **조건→행동** 표로 표준화하고, 사용자 메시지는 **간단·행동 유도형**으로.

### 업로드/정답/보상/딥링크/네트워크

| Condition(조건)       | Action(시스템)                 | UX 피드백                      |
| ------------------- | --------------------------- | --------------------------- |
| 동일 라운드 **중복 업로드**   | 최신 1건만 유효, 이전 무효화           | “이미 업로드됨. 다시 그리려면 새 라운드 시작” |
| **동시 정답** 발생        | 서버 락/타임스탬프로 **1명 승자**       | 승자: “정답!”. 패자: “조금 늦었어요”    |
| **광고 조기 종료**        | SSV 미수신 → **0 적립**          | “광고가 완전히 끝나야 코인이 지급돼요”      |
| **SSV 지연**          | 일정 시간 대기 후 폴링, 미수신 시 **실패** | “검증 지연 중… 잠시 후 자동 반영”       |
| **중복 SSV**(같은 거래ID) | **idempotency** 차단          | “이미 지급된 보상입니다”              |
| **일일 캡 도달**         | 버튼 비활성/쿨다운, 로그              | “오늘 보상 한도에 도달했어요”           |
| **딥링크 파라미터 손상**     | 웹 폴백 → 오류 가이드               | “초대가 만료되었어요. 새 초대를 받아주세요”   |
| **오프라인 제출**         | 큐에 적재 → 온라인 시 재시도           | “오프라인. 연결되면 자동 전송돼요”        |
| **앱 종료 중단**         | 재실행 시 복구 카드                 | “이어서 진행하기” 버튼               |

**(가정/리스크/백로그)**

| 구분  | 내용               |
| --- | ---------------- |
| 가정  | 모든 예외에 분석 이벤트 기록 |
| 리스크 | 과도한 재시도로 서버 부하   |
| 백로그 | 지수 백오프·서킷브레이커 적용 |

---

## User Interface Considerations

**Reasoning → Conclusion**: 전연령을 위해 **큰 버튼·고대비·1과업**을 일관 적용.

* 버튼 ≥48dp(태블릿 56dp), 본문 16–18sp
* **고대비 토글**, 색약 안전 팔레트 1종 기본
* 모달 사용 시 **포커스 트랩**·스크린리더 라벨 검증
* **샘플 이미지 제안**:

  * 튜토리얼 3장(그리기/공유/정답) 파스텔 일러스트
  * 결과 화면: 동물 마스코트가 “정답!” 플래카드
  * 공유 썸네일: 스케치북+방 코드 강조(텍스트 대비 7:1)

**(가정/리스크/백로그)**

| 구분  | 내용                     |
| --- | ---------------------- |
| 가정  | 모션 민감 사용자용 “애니 줄이기” 제공 |
| 리스크 | 과도한 색 대비로 눈부심          |
| 백로그 | 다크/고대비 별도 일러스트 세트      |

---

## Data Requirements & Data Flow

**Reasoning → Conclusion**: **객체 최소화 + 서버 권위**로 1주 MVP에 맞춘다(스키마 상세는 제외).

### 핵심 데이터 객체(추상)

* **Room, Round, Drawing, Guess**: 라운드 상태·결과
* **Coin Balance(계산/뷰)**, **Reward Log**(SEND/RECEIVE/AD)
* **Ad Receipt**(SSV 트랜잭션, idempotency key)
* **Palette, Ownership**(해금 기록)

### 데이터 플로우(텍스트 다이어그램)

```
Client ──(upload)──▶ Storage(이미지)
Client ──(actions)──▶ Edge(판정/보상/해금)
Edge ──(write)──▶ DB(라운드/보상/소유)
Ad Network ──(SSV)──▶ Edge(검증) ─▶ DB(보상)
Client ◀─(realtime/poll)── Edge/DB(잔액/상태)
Kakao Share ──(딥링크)──▶ Client(App/Web 폴백)
```

**(가정/리스크/백로그)**

| 구분  | 내용                           |
| --- | ---------------------------- |
| 가정  | 이미지 0.2–1.0MB 압축, 서버 상한 ≤5MB |
| 리스크 | 대용량 이미지로 네트워크 지연             |
| 백로그 | Resumable 업로드·썸네일 변환         |

---

## Security & Privacy Considerations

**Reasoning → Conclusion**: **서버 권위·최소 권한·감사 이벤트**가 초기 방어선.

* **서버 권위**: 판정/보상/차감은 **항상 Edge**. 클라 신호는 보조 UI용
* **Idempotency**: 보상/해금/정답에 **거래 키** 도입, 중복 차단
* **일일 캡 & 레이트 리밋**: 보상/요청 남용 방지
* **키 관리**: 클라에는 **익명 키만**, 서버는 **service\_role** 비공개
* **PII 최소화**: 게스트 기본, 필요 시 토큰/로그 익명화
* **취약점 최소화**: 입력 정규화, 이미지 MIME 검증, URL 스킴 화이트리스트
* **감사 로깅**: 보상 실패/차단/중복 시 **사건 ID** 남김

**(가정/리스크/백로그)**

| 구분  | 내용                       |
| --- | ------------------------ |
| 가정  | Edge에서 보상/해금 트랜잭션 원자성 보장 |
| 리스크 | 키 유출/구성오류로 권한 상승         |
| 백로그 | 모니터링 대시보드(SSV 실패율/락 충돌율) |

---

## (가정/리스크/백로그) — 종합

| 구분  | 핵심 항목                                                                        |
| --- | ---------------------------------------------------------------------------- |
| 가정  | 1주 MVP 범위 내에서 서버 권위·Idempotency·일일 캡만으로도 안정 운영 가능                            |
| 리스크 | 광고 Fill 및 SSV 지연, 딥링크 호환성, 오프라인 큐 충돌                                         |
| 백로그 | Admin 모듈, 오프라인 큐 UI, NSFW 자동화, Realtime 관측(SSV/보상 지표), Deferred Deep Link 계측 |

---
