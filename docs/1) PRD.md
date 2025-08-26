What: 전연령 소셜 그림 퀴즈 앱 \*\*“너랑 나의 그림퀴즈”\*\*의 1주 MVP PRD
Why: 큰 터치·고대비·단순 플로우로 진입장벽을 낮추고, **광고 보상+코인→팔레트 해금** 경제로 가벼운 재미/리텐션 확보
How-Now: **Flutter+Supabase+AdMob SSV+Kakao Talk Share**로 핵심 루프/접근성/보상 안전장치를 1주 내 완성

---

## 목차

1. 상세 제품 설명
2. 레퍼런스 서비스 & 정책 근거
3. 코어 기능과 사양
4. 추가 제안 기능
5. 유저 페르소나 & 시나리오
6. 기술 스택 권고
7. **경제 설계**(보상 상수·상한·악용 시나리오/방어)
8. **엣지 케이스**(중복 업로드·동시 정답·광고 취소/SSV 실패·앱 종료·오프라인)

---

## 1) 상세 제품 설명

**Reasoning → Conclusion**: 전연령 대상은 **작은 학습부담/큰 UI/짧은 절차**가 핵심이다. 따라서 MVP는 “그리기→카카오 공유→정답→보상→팔레트 해금”에만 집중하고, 모든 화면을 **1화면 1과업**으로 단순화한다.
**제품 요약**:

* **코어 루프**: 그림 그리기 → **Kakao Talk Share**로 초대/딥링크 입장 → 친구가 정답 입력 → 서버가 정규화 판정 → **코인 보상(보낸/맞힌/광고)** → **팔레트 해금**
* **접근성 기본**: 터치 ≥48dp, 본문 16–18sp, 고대비 테마, 3장 튜토리얼
* **정책 기본**: 공유는 **사용자 주도**(디폴트 템플릿), 보상은 **서버사이드 검증(SSV)** 후 적립.
* **플랫폼**: Flutter(안드/iOS), Supabase(Storage/Edge), AdMob(Rewarded+SSV)

**(가정/리스크/백로그)**

| 구분  | 내용                                 |
| --- | ---------------------------------- |
| 가정  | 카카오 공유는 디폴트 템플릿으로 사용자 주도 전송        |
| 리스크 | SSV 세팅/서명 검증 실패 시 보상 지연            |
| 백로그 | 친구 선택 API·자동화 템플릿, 모더레이션 자동화(NSFW) |

---

## 2) 레퍼런스 서비스 & 정책 근거

**Reasoning → Conclusion**: 시의성·정책 준수는 대체 불가. **공식 문서**를 기준으로 MVP 규칙을 못 박는다.

* **Kakao Talk Share(디폴트/커스텀 템플릿, Flutter 지원)**: **사용자 주도 공유**를 전제로 JSON 템플릿 구성 및 딥링크 포함. *Note: Kakao Developers – Talk Share 개요/템플릿 가이드.* ([Kakao Developers][1])
* **AdMob SSV**: 콜백의 `key_id`로 **공개키 JSON 매칭 → ECDSA(SHA-256) 서명 검증 → 서버 적립** 순서. *Note: Google AdMob SSV 문서(공개키 매핑·서명 검증 메서드 예시).* ([Google for Developers][2])
* **Android Target API 35**: **2025-08-31** 이후 신규/업데이트 앱은 **API 35(안드 15)** 요구. *Note: Google Play/Android Developers 공식 안내.* ([구글 헬프][3], [Android Developers][4])
* **Android 13 AD\_ID 권한**: **API 33+ 타깃**이며 광고 ID 사용 시 `AD_ID` 선언 필요. 일부 GMA SDK 버전은 **매니페스트 머지로 자동 선언**. *Note: Android 13 동작변경·AdMob Quick Start·Play Console 도움말.* ([Android Developers][5], [Google for Developers][6], [구글 헬프][7])
* **iOS 14.5+ ATT**: 추적 권한은 **ATT**로 요청, HIG 프라이버시 카피 준수. *Note: AppTrackingTransparency·HIG·User Privacy 안내.* ([Apple Developer][8])
* **Supabase Storage 업로드 정책**: **표준 업로드 ≤5GB**(6MB↑는 **Resumable** 권장). 이미지 정책은 앱에서 압축(0.2–1.0MB) 후 업로드. *Note: Supabase Storage 업로드 크기/Resumable 권장.* ([Supabase][9])

**(가정/리스크/백로그)**

| 구분  | 내용                        |
| --- | ------------------------- |
| 가정  | SSV 공개키는 주기 캐시, 만료/회전 대비  |
| 리스크 | 카카오/스토어 정책 변동으로 템플릿/쿼터 변경 |
| 백로그 | 플랫폼별 심사 가이드 정리(스크린샷·문구)   |

---

## 3) 코어 기능과 사양

**Reasoning → Conclusion**: 1주/1인 제약에서 **핵심 루프를 방해하는 요소를 제거**하고, 필수 방어(SSV/idem/상한)만 포함한다.

### 3.1 화면(IA) 개요

* **Onboarding**: 3장 카드(①그리기 ②공유 ③정답) / “큰 시작 버튼”
* **Home**: \[빠른 시작], \[방 코드], \[내 코인/팔레트], \[광고 보고 +50]
* **Room**: 상태(대기/플레이)·\[카카오 공유]·딥링크 입장 확인
* **Draw**: 펜/지우개/되돌리기/8색·\[업로드]
* **Guess**: 그림 보기·정답 입력(정규화)·처리 상태
* **Result**: 정답/소요시간/보상(코인)·다시 하기
* **Palette(상점)**: 팔레트 카드(미리보기/가격/해금)
* **Settings**: 접근성 토글, 신고, 개인정보 안내

> **샘플 이미지 아이디어**:
>
> * 튜토리얼 카드: **따뜻한 파스텔 일러스트**(연필 잡은 손, 카카오 말풍선, 정답 체크 아이콘).
> * 팔레트 카드: 6\~8색 **칩 미리보기**와 “잠금 자물쇠 → 해금 체크” 애니메이션.
> * 공유 썸네일: **귀여운 동물 마스코트**가 스케치북을 들고 있는 장면(고대비/굵은 윤곽선).

### 3.2 기능 사양(요약)

* **그림 캔버스**: 펜·지우개·되돌리기·8색, 이미지 압축 후 Storage 업로드(정책 한도 내). *Note: Supabase 업로드 권장 방식.* ([Supabase][9])
* **공유/딥링크**: **Kakao Talk Share(디폴트 템플릿)** 사용, 방 코드/라운드 ID 포함. *Note: Kakao Talk Share 가이드.* ([Kakao Developers][1])
* **정답 판정**: 서버에서 **정규화(소문자/공백/기호 제거)** 비교, **첫 정답자만 승자**
* **보상 처리**: **서버 전용**(클라 신호 금지), **idempotency** 보장
* **광고 보상(SSV)**: AdMob 콜백 서명 **ECDSA 검증** 후 +50 적립, 일일 **상한/쿨다운** 적용. *Note: AdMob SSV 검증 플로우.* ([Google for Developers][2])
* **팔레트 해금**: 코인 차감→영구 해금, 실패 시 잔액 부족 토스트
* **접근성**: 고대비 테마·글자 확대·핵심 버튼 하단 고정

**(가정/리스크/백로그)**

| 구분  | 내용                       |
| --- | ------------------------ |
| 가정  | 팔레트 3종(모노/파스텔/네온)부터 시작   |
| 리스크 | 광고 네트워크 초기 충전 지연·Fill 저하 |
| 백로그 | 힌트 아이템·리플레이 애니메이션        |

---

## 4) 추가 제안 기능

**Reasoning → Conclusion**: **안전/운영 편의**를 빠르게 확보하되, 구현량을 최소화한다.

* **신고·관리자 숨김(베타 수동)**: 신고 수 임계치 도달 시 리스트 비노출
* **선택적 로그인**: 게스트 기본, 이후 소셜 연동(카카오/애플/구글)
* **튜토리얼 음성 안내**: 시니어 대상 *짧은* 음성 가이드

**(가정/리스크/백로그)**

| 구분  | 내용                             |
| --- | ------------------------------ |
| 가정  | 로그인 미도입 시에도 코인/해금은 단말+익명ID로 관리 |
| 리스크 | 신고 악용(어뷰징)                     |
| 백로그 | NSFW 자동 감지, 클라우드 모더레이션 연동      |

---

## 5) 유저 페르소나 & 시나리오

**Reasoning → Conclusion**: 유저군(시니어/아동/캐주얼)의 **공통 최소 경로**는 동일하다. **스크린 수·텍스트 량**을 제한해 모두에게 유효하게 만든다.

### 페르소나

* **시니어**: 큰 버튼·고대비 필요, 단계 안내 선호
* **아동**: 단일 과업 화면, 짧은 튜토리얼 선호
* **파티 캐주얼**: 즉시성, 빠른 초대/입장

### 대표 시나리오(요약)

1. **드로어**: 홈→방 생성→그림→업로드→공유→결과(+10 SEND)
2. **게서(친구)**: 카카오 링크→앱 열림→그림 보기→정답 입력→정답(+10 RECEIVE)
3. **팔레트 해금**: 광고 시청(+50)×n → 잔액 충족→해금 성공
4. **오프라인**: 그림 로컬 보관→연결 복구 시 업로드

**(가정/리스크/백로그)**

| 구분  | 내용                            |
| --- | ----------------------------- |
| 가정  | 딥링크는 앱 설치 유도 후 지정 화면으로 복귀     |
| 리스크 | 힐테스트 단말(저해상도·저사양)에서 캔버스 지연    |
| 백로그 | 초대 수락 퍼널 A/B(미리보기 포함 vs 텍스트만) |

---

## 6) 기술 스택 권고

**Reasoning → Conclusion**: **1주/1인**은 통합 스택이 필수. **Flutter** 단일 코드베이스 + **Supabase** 관리형 백엔드로 리스크를 줄인다.

* **클라이언트**: Flutter(안드/iOS 동시)
* **백엔드**: Supabase(Storage·Edge Functions) — *데이터 모델은 개념 수준만 사용(본 문서 DB 설계 제외)*
* **공유**: Kakao Talk Share **디폴트 템플릿**(+딥링크 파라미터) *Note: Kakao Docs.* ([Kakao Developers][1])
* **광고/보상**: AdMob Rewarded + **SSV**(공개키 JSON/ECDSA, idem, 일일 상한) *Note: AdMob SSV 공식 문서.* ([Google for Developers][2])
* **분석**: 최소 이벤트 사전(루프/광고/해금/접근성/ATT)

**플랫폼 최소/정책**

* **Android**: minSdk **23(6.0+)**, **Target API 35** 요구(2025-08-31) *Note: Play/Android 공식.* ([구글 헬프][3], [Android Developers][4])
* **AD\_ID**: API 33+에서 권한 필요, **GMA SDK 20.4.0+ 자동 선언** 가능 *Note: Android 동작변경·AdMob Quick Start.* ([Android Developers][5], [Google for Developers][6])
* **iOS**: 14.5+ ATT 권한 요청/HIG 카피 *Note: Apple 문서.* ([Apple Developer][8])
* **Storage**: 표준 업로드 ≤5GB, 6MB↑ Resumable 권장 *Note: Supabase.* ([Supabase][9])

**(가정/리스크/백로그)**

| 구분  | 내용                                |
| --- | --------------------------------- |
| 가정  | Edge Functions에서만 보상/정답 처리(클라 금지) |
| 리스크 | SSV 서명 검증 오류·키 로테이션 미대응           |
| 백로그 | 서버 로깅/관측성 대시보드(SSV 실패율 모니터)       |

---

## 7) **경제 설계** (보상 상수·상한·악용 시나리오/방어)

**Reasoning → Conclusion**: **간단한 상수**와 **서버 집행**만으로도 초기 어뷰징을 억제할 수 있다. 상한·쿨다운은 **원격 플래그**로 조정한다.

### 보상 상수(고정)

* **AD\_REWARD**: +50 코인 (**SSV 성공 후** 적립)
* **SEND\_REWARD**: +10 코인(드로어, 라운드당 1회)
* **RECEIVE\_REWARD**: +10 코인(해당 라운드 **첫 정답자**, 1회)
* **팔레트 해금 비용**: **모노 120 / 파스텔 200 / 네온 300**
* **일일 상한(기본)**: 광고 5회 / SEND 10회 / RECEIVE 10회 — **원격 플래그**로 조정

### 악용 시나리오 & 방어

* **광고 스푸핑**: 클라 이벤트만 전송 → **SSV만 인정**, `key_id→공개키 JSON→ECDSA` 검증, **idempotency 키** 중복 차단. *Note: AdMob SSV 검증 흐름.* ([Google for Developers][2])
* **라운드 보상 농사**: 동일 라운드 반복 업로드/정답 → **라운드당 1회 보상** 규칙, **쿨다운**
* **딥링크 남용**: 임의 방 입장 → **코드 유효시간/최대 참가 수 제한**

**(가정/리스크/백로그)**

| 구분  | 내용                    |
| --- | --------------------- |
| 가정  | 상수 조정은 원격 플래그로 무중단 적용 |
| 리스크 | 광고 Fill 저하로 코인 수급 편차  |
| 백로그 | 시즌 퀘스트/일일 미션(균형화)     |

---

## 8) **엣지 케이스**

**Reasoning → Conclusion**: **서버 권위+idem+상한**만 지켜도 대부분의 오류를 무해화할 수 있다.

* **중복 업로드**: 동일 라운드 업로드는 **최신 1개만 유효**, 서버에서 상태 체크
* **동시 정답**: **첫 성공 타임스탬프**만 인정, 이후는 실패 응답
* **광고 취소**: 취소/닫힘 시 **SSV 미발생 → 적립 없음**, UI는 “검증 중/취소” 분기
* **SSV 실패**: 검증 실패는 **0 적립** + 재시도 버튼(쿨다운)
* **앱 종료/백그라운드**: 진행 중 라운드는 **복구 화면** 제공
* **오프라인**: 캔버스 로컬 저장→재연결 시 업로드(크기/형식 정책 준수). *Note: Supabase 업로드 권장.* ([Supabase][9])
* **AD\_ID 미선언/차단**: 광고 ID가 **제로 스트링** 가능 → **ATT/AD\_ID 상태에 따른 대체 분기**. *Note: Play Console/Android 동작.* ([구글 헬프][7], [Android Developers][5])

**(가정/리스크/백로그)**

| 구분  | 내용                     |
| --- | ---------------------- |
| 가정  | 재시도는 지수 백오프·토스트로 안내    |
| 리스크 | 장시간 백그라운드→토큰 만료로 복구 실패 |
| 백로그 | 오프라인 큐 시각화(스낵바→리스트)    |

---

## KPI 매핑(요약)

**Reasoning → Conclusion**: 최소 이벤트로 **측정-학습** 루프를 가능하게 한다.

| KPI                 | 정의              | 트리거 이벤트(예시)                     |
| ------------------- | --------------- | ------------------------------- |
| D1 Retention ≥ 28%  | 첫 방문+1일 후 재방문   | `app_open`(T+1 재방문)             |
| Invite→Join ≥ 20%   | 공유 클릭 대비 딥링크 오픈 | `share_click` → `deeplink_open` |
| Rounds/user/day ≥ 3 | 24h 내 라운드 시작 수  | `round_start`                   |
| Rewarded SSV ≥ 95%  | SSV 성공률         | `ad_complete_ssv / ad_start`    |
| Crash-free ≥ 99.5%  | 크래시 없는 사용자 비율   | `crash_free_users`(SDK 지표)      |

**(가정/리스크/백로그)**

| 구분  | 내용                 |
| --- | ------------------ |
| 가정  | 퍼널: 초대→입장→정답→보상→해금 |
| 리스크 | 초기 트래픽 적어 통계 변동성 큼 |
| 백로그 | 이벤트 샘플링/세션 정의 정교화  |

---

### 부록: 정책/플랫폼 **주의 노트**

* **Play Target API 35(2025-08-31)**: 제출/업데이트 요건 확인. *Note:* ([구글 헬프][3], [Android Developers][4])
* **Android 13 AD\_ID**: 권한 미선언 시 0 반환 가능; GMA SDK 20.4.0+는 자동 선언. *Note:* ([Android Developers][5], [Google for Developers][6])
* **iOS 14.5+ ATT**: `requestTrackingAuthorization` 타이밍·HIG 카피 준수. *Note:* ([Apple Developer][8])
* **AdMob SSV**: `key_id`→공개키 JSON→ECDSA 검증 후 보상. *Note:* ([Google for Developers][2])
* **Storage**: 표준 ≤5GB, 6MB↑ Resumable 권장(클라 압축 정책 수립). *Note:* ([Supabase][9])

---

🔄 **Self-Reflection**: DB·ERD는 의도적으로 제외했고(요구사항), 정책 항목은 **공식 문서 기반**으로 적시했다. 카카오 메시지 쿼터/승인 조건과 광고 Fill/SSV 실패율은 시의성이 높아 **런칭 직전 재검증**이 필요하다. **확신도: 높음(플랫폼/정책 근거)**, 다만 실제 심사/쿼터 수치는 앱별로 달라질 수 있다.

[1]: https://developers.kakao.com/docs/latest/en/kakaotalk-share/common?utm_source=chatgpt.com "Concepts | Kakao Developers Docs"
[2]: https://developers.google.com/admob/android/ssv?utm_source=chatgpt.com "Validate server-side verification (SSV) callbacks | Android"
[3]: https://support.google.com/googleplay/android-developer/answer/11926878?hl=en&utm_source=chatgpt.com "Target API level requirements for Google Play apps"
[4]: https://developer.android.com/google/play/requirements/target-sdk?utm_source=chatgpt.com "Meet Google Play's target API level requirement - Android Developers"
[5]: https://developer.android.com/about/versions/13/behavior-changes-13?utm_source=chatgpt.com "Behavior changes: Apps targeting Android 13 or higher"
[6]: https://developers.google.com/admob/android/quick-start?utm_source=chatgpt.com "Get Started | Android"
[7]: https://support.google.com/googleplay/android-developer/answer/6048248?hl=en&utm_source=chatgpt.com "Advertising ID - Play Console Help"
[8]: https://developer.apple.com/documentation/apptrackingtransparency?utm_source=chatgpt.com "App Tracking Transparency"
[9]: https://supabase.com/docs/guides/storage/uploads/standard-uploads?utm_source=chatgpt.com "Standard Uploads | Supabase Docs"
