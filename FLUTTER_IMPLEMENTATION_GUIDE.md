# 🎨 QuizDraw Flutter 앱 구현 가이드

> **현재 상황**: 백엔드 완전 구축 완료 + Flutter 기본 구조 세팅 완료  
> **목표**: 사용자가 실제로 사용할 수 있는 완전한 그림 퀴즈 앱 구현

---

## 📋 현재 진행 상황 요약

### ✅ 완료된 항목들
- **백엔드 100% 완성**: DB 스키마, RLS, 6개 Edge Functions API, 테스트
- **Flutter 프로젝트 구조**: 패키지 설치, 폴더 구조, 기본 파일들 생성
- **개발 환경**: Flutter 3.32.8, Supabase CLI, 모든 의존성 패키지 설치

### 🚧 구현이 필요한 항목들
- **UI/UX 구현**: 13개 화면/컴포넌트의 실제 디자인 및 기능
- **API 연동**: 백엔드 6개 API와 Flutter 앱 완전 연결
- **핵심 기능**: 그림 그리기, 카카오톡 공유, AdMob 광고, 오프라인 캐시

---

## 📚 필수 활용 문서들 (docs/ 폴더)

### 📖 1. PRD.md (제품 요구사항) - 전체 기능 명세
**반드시 참고해야 할 내용:**
- **코어 루프**: 그림 그리기 → 카카오톡 공유 → 정답 입력 → 보상 → 팔레트 해금
- **접근성 기본**: 터치 ≥48dp, 본문 16-18sp, 고대비 테마, 3장 튜토리얼
- **기술 스택**: Flutter+Supabase+AdMob SSV+Kakao Talk Share
- **보상 시스템**: SEND(+10), RECEIVE(+10), AD_REWARD(+50)
- **팔레트 가격**: 모노(0), 파스텔(200), 네온(300)
- **일일 제한**: 광고 5회, SEND 10회, RECEIVE 10회
- **비즈니스 룰**: 서버사이드 검증, Idempotency, 실패는 명확하게

### 🗂️ 2. IA.md (정보 아키텍처) - 화면 구조 및 플로우
**반드시 참고해야 할 내용:**
- **화면 전체 구조**: 온보딩 → 홈 → 룸 → 그리기/맞히기 → 결과 → 팔레트 → 설정
- **네비게이션 패턴**: 탭 네비게이션, 모달 오버레이, 딥링크 처리
- **상태 전환**: 대기 → 플레이 → 결과 순환 구조
- **정보 계층**: 전역 상태(사용자/룸) vs 로컬 상태(화면별)
- **데이터 플로우**: 어떤 데이터가 어느 화면에서 필요한지

### 👥 3. Use-Case.md (사용자 시나리오) - 실제 사용 플로우
**반드시 참고해야 할 내용:**
- **드로어 시나리오**: 룸 생성 → 그림 그리기 → 업로드 → 공유 → 대기 → 결과 확인
- **게서 시나리오**: 카카오 링크 → 앱 진입 → 그림 보기 → 정답 입력 → 보상 확인
- **팔레트 해금 시나리오**: 광고 시청 → 코인 획득 → 상점 이용 → 팔레트 구매
- **오프라인 시나리오**: 그림 로컬 저장 → 네트워크 복구 → 자동 업로드
- **엣지 케이스**: 중복 업로드, 동시 정답, 광고 취소, 앱 종료, 연결 끊김
- **에러 처리**: 각 상황별 사용자 안내 메시지 및 복구 방법

### 🗄️ 4. ERD.md (데이터 모델) - API 응답 구조 이해
**반드시 참고해야 할 내용:**
- **테이블 관계**: users ↔ rooms ↔ rounds ↔ drawings/guesses ↔ coin_tx
- **API 응답 구조**: 각 Edge Function의 정확한 request/response 형태
- **데이터 제약**: UUID 형식, 텍스트 길이, 정규화 규칙
- **비즈니스 룰**: 정답자 1명만, Idempotency 키, SSV 검증 과정
- **상태 관리**: 어떤 데이터를 언제 캐시하고 언제 새로 가져올지

### 🎨 5. Design.md (디자인 가이드라인) - UI/UX 세부 명세
**반드시 참고해야 할 내용:**
- **접근성 기준**: 터치 영역, 폰트 크기, 색상 대비, 색맹 지원
- **디자인 시스템**: 색상 팔레트, 타이포그래피, 간격, 둥근 모서리
- **컴포넌트 명세**: 버튼, 카드, 입력 필드, 모달의 구체적 디자인
- **애니메이션 가이드**: 전환 효과, 로딩 인디케이터, 피드백 애니메이션
- **반응형 디자인**: 다양한 화면 크기 대응 방법
- **브랜딩**: 마스코트 활용법, 일러스트 스타일, 톤앤매너

### 🔧 6. README_BACKEND.md (백엔드 API 명세)
**반드시 참고해야 할 내용:**
- **6개 API 완전 명세**: request/response 구조, 에러 코드
- **인증 및 보안**: service_role 키 사용법, RLS 정책 이해
- **에러 처리**: HTTP 상태 코드별 의미 및 사용자 안내 방법
- **비즈니스 룰**: 보상 금액, 제한사항, 검증 로직

---

## 🎯 문서 기반 구현 지침

### 📱 화면별 구현 가이드

#### 🏠 홈 화면 구현
**참고 문서**: IA.md(화면구조) + Design.md(접근성) + Use-Case.md(시나리오)

**IA.md에서 확인할 것:**
- 홈 화면의 정보 계층 구조
- 다른 화면으로의 네비게이션 패턴
- 전역 상태에서 필요한 데이터들

**Design.md에서 확인할 것:**
- 버튼 크기 (최소 48dp), 폰트 크기 (16-18sp)
- 색상 팔레트, 간격, 둥근 모서리 값
- 고대비 모드 지원 방법

**Use-Case.md에서 확인할 것:**
- 빠른 시작 버튼 클릭 시 전체 플로우
- 방 코드 입력 시 검증 및 에러 처리
- 광고 버튼 클릭 시 AdMob 연동 플로우

#### 🎮 룸 화면 구현
**참고 문서**: IA.md(상태전환) + Use-Case.md(드로어/게서) + ERD.md(실시간데이터)

**IA.md에서 확인할 것:**
- 룸 상태별 UI 변화 (대기/플레이/결과)
- 모달 호출 구조 (그리기/맞히기/결과)
- 실시간 상태 업데이트 방법

**Use-Case.md에서 확인할 것:**
- 드로어 시나리오: 그림 그리기 시작 플로우
- 게서 시나리오: 정답 맞히기 시작 플로우
- 카카오톡 공유 시 딥링크 생성 및 처리

#### 🎨 그림 그리기 모달 구현
**참고 문서**: PRD.md(기술명세) + Design.md(캔버스설계) + Use-Case.md(업로드플로우)

**PRD.md에서 확인할 것:**
- Canvas → Image 변환 → Supabase Storage 업로드 정책
- 이미지 압축 요구사항 (0.2-1.0MB)
- start-round API 호출 시점 및 파라미터

**Design.md에서 확인할 것:**
- 캔버스 영역 크기 및 비율
- 팔레트 UI 레이아웃 (8색 + 해금색상)
- 도구 버튼 배치 (펜/지우개/되돌리기)

#### 🤔 정답 맞히기 모달 구현
**참고 문서**: Use-Case.md(게서시나리오) + ERD.md(정답검증) + Design.md(입력UI)

**Use-Case.md에서 확인할 것:**
- 그림 로드 → 정답 입력 → 제출 → 피드백 전체 플로우
- 네트워크 오류, 로딩 지연 시 사용자 경험

**ERD.md에서 확인할 것:**
- submit-guess API의 정확한 request/response
- 텍스트 정규화 로직 (소문자, 공백제거, 특수문자)
- 정답/오답 판정 기준

#### 🏆 결과 화면 구현
**참고 문서**: PRD.md(보상시스템) + Design.md(애니메이션) + Use-Case.md(결과확인)

**PRD.md에서 확인할 것:**
- SEND(+10), RECEIVE(+10) 보상 정확한 조건
- 코인 지급 시점 및 Idempotency 처리

**Design.md에서 확인할 것:**
- 보상 획득 애니메이션 스펙
- 결과 표시 UI (정답/시간/코인)

#### 🎨 팔레트 상점 구현
**참고 문서**: PRD.md(팔레트가격) + ERD.md(unlock-palette) + Design.md(상품카드)

**PRD.md에서 확인할 것:**
- 팔레트별 정확한 가격 (모노 0, 파스텔 200, 네온 300)
- 해금 조건 및 잔액 확인 로직

**ERD.md에서 확인할 것:**
- unlock-palette API 호출 방법
- 팔레트 목록 조회 (palettes 테이블)
- 해금 여부 확인 (user_palettes 테이블)

#### ⚙️ 설정 화면 구현
**참고 문서**: Design.md(접근성설정) + PRD.md(정책준수) + Use-Case.md(신고기능)

**Design.md에서 확인할 것:**
- 접근성 토글들 (고대비, 글자크기, 터치영역)
- 설정값 저장 및 적용 방법

### 🔗 핵심 기능별 구현 가이드

#### 📡 Supabase API 연동
**참고 문서**: README_BACKEND.md(API명세) + ERD.md(데이터구조)

**구현해야 할 6개 API:**
```dart
// README_BACKEND.md의 정확한 명세 따라 구현
class QuizDrawApi {
  // 각 API의 request/response 구조 정확히 매칭
  Future<Map<String, dynamic>> createRoom(CreateRoomRequest request);
  Future<Map<String, dynamic>> joinRoom(JoinRoomRequest request);
  // ... 나머지 4개 API
}
```

#### 📱 카카오톡 공유 + 딥링크
**참고 문서**: PRD.md(카카오공유정책) + Use-Case.md(공유시나리오)

**PRD.md에서 확인할 것:**
- 카카오톡 공유 템플릿 구조
- 딥링크 파라미터 (room_code 포함)
- 사용자 주도 공유 원칙

**Use-Case.md에서 확인할 것:**
- 공유 → 친구 클릭 → 앱 설치/열기 → 룸 입장 전체 플로우
- 딥링크 실패 시 대체 플로우

#### 💰 AdMob 리워드 광고
**참고 문서**: PRD.md(SSV정책) + README_BACKEND.md(verify-ad-reward)

**PRD.md에서 확인할 것:**
- AdMob SSV 검증 과정 (공개키 → ECDSA 서명 검증)
- 일일 광고 시청 제한 (5회)
- AD_REWARD 금액 (+50)

**README_BACKEND.md에서 확인할 것:**
- verify-ad-reward API 정확한 파라미터
- SSV 검증 실패 시 에러 처리

#### 🎨 그림 그리기 엔진
**참고 문서**: Design.md(캔버스명세) + PRD.md(업로드정책)

**Design.md에서 확인할 것:**
- CustomPainter 구현 세부사항
- 터치 감도, 선 굵기, 색상 적용 방법

**PRD.md에서 확인할 것:**
- Canvas → Image 변환 방법
- Supabase Storage 업로드 크기 제한
- 이미지 압축 요구사항

#### 💾 오프라인 캐시
**참고 문서**: Use-Case.md(오프라인시나리오) + ERD.md(데이터구조)

**Use-Case.md에서 확인할 것:**
- 오프라인 상태에서 그림 로컬 저장
- 네트워크 복구 시 자동 동기화 플로우
- 캐시 충돌 해결 방법

#### 📊 상태 관리 설계
**참고 문서**: IA.md(정보계층) + ERD.md(데이터관계)

**IA.md에서 확인할 것:**
- 어떤 데이터가 전역 상태인지 로컬 상태인지
- 화면 간 데이터 전달 방법
- 실시간 업데이트가 필요한 데이터들

**ERD.md에서 확인할 것:**
- 테이블 간 관계를 Flutter 상태 구조에 매핑
- 어떤 데이터를 언제 새로 fetch할지 결정

---

## ⚡ 개발 헌법 적용 지침

### 🚫 1. 폴백/더미 데이터 절대 금지
**각 문서에서 확인할 것:**
- **PRD.md**: "실패는 빠르게, 명확하게, 소리나게" 원칙
- **Use-Case.md**: 각 에러 상황별 실제 에러 처리 방법
- **README_BACKEND.md**: API 실패 시 정확한 HTTP 에러 코드 활용

**절대 금지 패턴:**
```dart
❌ final dummyRooms = [Room(code: "ABC123", status: "waiting")];
❌ if (apiError) return MockData.defaultResponse();
❌ const TEMP_COIN_BALANCE = 999;
```

**올바른 패턴:**
```dart
✅ if (apiError) throw QuizDrawException('API_ERROR: ${apiError.message}');
✅ final rooms = await api.getRooms(); // 실제 API만 사용
✅ if (response.isEmpty) return EmptyStateWidget(); // 빈 상태도 정확히 처리
```

### ✅ 2. 전체 완결 구조 원칙
**각 문서 기반 완결 체크:**
- **IA.md**: 한 화면 구현 시 연결된 모든 화면도 함께 완성
- **Use-Case.md**: 한 시나리오 구현 시 관련 엣지 케이스까지 완성
- **ERD.md**: 한 API 연동 시 관련된 모든 테이블 데이터까지 완성
- **Design.md**: 한 컴포넌트 구현 시 모든 상태(로딩/에러/성공)까지 완성

### 🔍 3. 체계적 분석 기반 구현
**문서 분석 순서:**
1. **PRD.md**로 전체 요구사항 파악
2. **IA.md**로 화면 구조 및 플로우 이해
3. **Use-Case.md**로 사용자 시나리오 상세 분석
4. **ERD.md**로 데이터 구조 및 API 이해
5. **Design.md**로 UI/UX 세부 명세 확인
6. **README_BACKEND.md**로 실제 구현 방법 확인

---

## 🎯 구현 우선순위 및 검증 기준

### 1단계: 핵심 플로우 (문서 기반)
**PRD.md의 코어 루프 완전 구현:**
1. 그림 그리기 → 카카오톡 공유 (Use-Case.md 드로어 시나리오)
2. 친구 초대 → 정답 입력 (Use-Case.md 게서 시나리오)
3. 보상 획득 → 팔레트 해금 (PRD.md 보상 시스템)

### 2단계: API 연동 완성 (README_BACKEND.md)
**6개 API 모두 완전 연동:**
- create-room, join-room, start-round, submit-guess, verify-ad-reward, unlock-palette
- 각 API의 정확한 request/response 구조 준수
- HTTP 에러 코드별 적절한 사용자 안내

### 3단계: 접근성 및 UX (Design.md)
**Design.md의 모든 접근성 기준 준수:**
- 터치 영역 48dp, 폰트 크기 16-18sp, 고대비 4.5:1
- 색맹 지원, 스크린 리더 지원, 키보드 네비게이션

### 4단계: 엣지 케이스 완전 대응 (Use-Case.md)
**Use-Case.md의 모든 엣지 케이스 구현:**
- 오프라인 상황, 네트워크 오류, 앱 백그라운드 전환
- 중복 요청, 동시 접근, 잘못된 입력 등

---

## 📋 완성도 검증 체크리스트

### 📚 문서 활용도 체크
- [ ] **PRD.md**: 모든 요구사항이 앱에 반영됨
- [ ] **IA.md**: 모든 화면과 네비게이션이 명세대로 구현됨
- [ ] **Use-Case.md**: 모든 시나리오와 엣지 케이스가 동작함
- [ ] **ERD.md**: 모든 API가 정확한 구조로 연동됨
- [ ] **Design.md**: 모든 접근성 기준과 디자인 가이드가 적용됨
- [ ] **README_BACKEND.md**: 모든 API 명세가 정확히 구현됨

### 🎯 기능 완성도 체크
- [ ] **코어 루프**: 그리기→공유→정답→보상→해금이 완전히 동작
- [ ] **API 연동**: 6개 모든 API가 에러 처리까지 완벽 구현
- [ ] **접근성**: 48dp 터치, 16-18sp 폰트, 4.5:1 대비, 색맹 지원
- [ ] **에러 처리**: 모든 실패 상황에서 명확한 안내와 복구 방법 제공
- [ ] **오프라인**: 네트워크 끊김 상황에서도 기본 기능 동작

### 🏛️ 개발 헌법 준수 체크
- [ ] **폴백 데이터 0개**: 모든 데이터가 실제 API/DB 연동
- [ ] **전체 완결**: 부분 구현 없이 모든 관련 기능 동시 완성
- [ ] **체계적 분석**: 6개 문서 모두 활용한 정확한 구현

---

## 🚀 시작 지침

### 📖 1. 문서 숙지부터
**반드시 이 순서로 모든 문서를 읽고 이해한 후 구현 시작:**
1. `docs/1) PRD.md` - 전체 그림 이해
2. `docs/2) IA.md` - 화면 구조 이해  
3. `docs/3) Use-Case.md` - 사용자 관점 이해
4. `docs/4) ERD.md` - 데이터 구조 이해
5. `docs/5) Design.md` - UI/UX 세부사항 이해
6. `README_BACKEND.md` - 구현 방법 이해

### 🎯 2. 문서 기반 구현
**각 기능 구현 시 반드시 해당 문서들을 계속 참조하며 진행**
- 홈 화면 구현 시: IA.md(구조) + Design.md(UI) + Use-Case.md(플로우) 동시 참조
- API 연동 시: ERD.md(구조) + README_BACKEND.md(명세) 동시 참조
- 에러 처리 시: Use-Case.md(엣지케이스) + PRD.md(원칙) 동시 참조

### ✅ 3. 완결 구조로 검증
**한 기능을 완성할 때마다 관련 문서들로 완성도 검증:**
- 해당 기능이 모든 관련 문서의 요구사항을 만족하는가?
- 연결된 다른 기능들도 함께 완성되었는가?
- 엣지 케이스와 에러 처리까지 완료되었는가?

---

**🏛️ "문서가 곧 설계도, 설계도 없는 구현은 위험하다!"**

6개 docs 문서는 QuizDraw 앱의 완전한 설계도입니다. 이 문서들을 철저히 활용해야만 사용자가 실제로 만족하며 사용할 수 있는 완전한 앱이 완성됩니다! 📚✨

## 📱 구현해야 할 화면 및 기능

### 🏠 1. 홈 화면 (`home_screen.dart`)
```dart
// 현재 상태: 기본 스켈레톤만 존재
// 구현 필요: 실제 UI + 기능
```

**구현해야 할 요소:**
- **빠른 시작 버튼**: 룸 생성 → `create-room` API 호출
- **방 코드 입력**: 6자리 코드 입력 → `join-room` API 호출
- **내 정보 카드**: 코인 잔액, 해금된 팔레트 수 표시
- **광고 보상 버튼**: "광고 보고 +50 코인" → AdMob 연동
- **하단 네비게이션**: 홈/팔레트/설정 탭

**참고 문서:**
- `docs/2) IA.md` - 홈 화면 구조 및 플로우
- `docs/5) Design.md` - 접근성 가이드 (터치 48dp, 폰트 16-18sp)
- `README_BACKEND.md` - create-room, join-room API 명세

### 🎮 2. 룸 화면 (`room_screen.dart`)
```dart
// 현재 상태: 기본 스켈레톤만 존재  
// 구현 필요: 실시간 상태 관리 + 모달 연동
```

**구현해야 할 요소:**
- **룸 상태 표시**: 대기/플레이 중 상태에 따른 UI 변화
- **플레이어 목록**: 참가자 닉네임, 점수, 온라인 상태
- **카카오톡 공유 버튼**: 딥링크 포함 템플릿 메시지 전송
- **그림 그리기 시작**: draw_modal.dart 호출
- **정답 맞히기**: guess_modal.dart 호출
- **결과 확인**: result_modal.dart 호출

**참고 문서:**
- `docs/3) Use-Case.md` - 드로어/게서 시나리오 상세 플로우
- Kakao Developer 문서 - 카카오톡 공유 템플릿

### 🎨 3. 그림 그리기 모달 (`draw_modal.dart`)
```dart
// 현재 상태: 기본 스켈레톤만 존재
// 구현 필요: CustomPainter + 터치 처리 + 업로드
```

**구현해야 할 핵심 기능:**
- **캔버스 영역**: CustomPainter를 활용한 그림 그리기
- **팔레트 선택**: 8색 기본 + 해금된 팔레트 색상
- **도구 버튼**: 펜/지우개/되돌리기/초기화
- **업로드 처리**: 
  1. Canvas를 이미지로 변환
  2. 압축 (PRD 권장: 0.2-1.0MB)
  3. Supabase Storage 업로드
  4. `start-round` API 호출

**기술적 구현 요소:**
```dart
class DrawingCanvas extends CustomPainter {
  // 그리기 로직 구현
}

class DrawModal extends StatefulWidget {
  // 상태 관리: 현재 색상, 도구, 그리기 경로
}
```

**참고 문서:**
- Flutter CustomPainter 공식 문서
- `docs/1) PRD.md` - 그림 업로드 정책 (Supabase Storage)

### 🤔 4. 정답 맞히기 모달 (`guess_modal.dart`)
```dart
// 현재 상태: 기본 스켈레톤만 존재
// 구현 필요: 그림 표시 + 입력 처리 + 실시간 피드백
```

**구현해야 할 요소:**
- **그림 표시**: Supabase Storage에서 이미지 로드
- **정답 입력 필드**: 한글/영문 입력 지원
- **제출 처리**: `submit-guess` API 호출
- **실시간 피드백**: 정답/오답 즉시 표시
- **보상 안내**: 코인 획득 시 애니메이션

### 🏆 5. 결과 모달 (`result_modal.dart`)
```dart
// 현재 상태: 기본 스켈레톤만 존재
// 구현 필요: 결과 표시 + 보상 안내 + 다음 액션
```

**구현해야 할 요소:**
- **결과 표시**: 정답/오답, 소요 시간, 정답자
- **보상 표시**: 획득한 코인 (SEND: +10, RECEIVE: +10)
- **액션 버튼**: 다시 하기, 홈으로, 팔레트 상점

### 🎨 6. 팔레트 상점 (`palette_screen.dart`)
```dart
// 현재 상태: 기본 스켈레톤만 존재
// 구현 필요: 팔레트 목록 + 미리보기 + 구매 처리
```

**구현해야 할 요소:**
- **팔레트 목록**: DB에서 전체 팔레트 조회
- **미리보기 카드**: 색상 칩 6-8개 표시
- **가격 및 상태**: 가격, 해금 여부, 잔액 부족 표시
- **해금 처리**: `unlock-palette` API 호출
- **색맹 지원**: is_colorblind_safe 표시

### ⚙️ 7. 설정 화면 (`settings_screen.dart`)
```dart
// 현재 상태: 기본 스켈레톤만 존재
// 구현 필요: 접근성 설정 + 정보 페이지
```

**구현해야 할 요소:**
- **접근성 토글**: 고대비 모드, 글자 크기, 터치 영역
- **신고 기능**: 부적절한 그림 신고
- **정보 페이지**: 개인정보 처리방침, 이용약관, 버전 정보

---

## 🔗 API 연동 가이드

### 📡 Supabase 클라이언트 설정 (`quizdraw_api.dart`)
```dart
// 현재 상태: 기본 구조만 존재
// 구현 필요: 6개 Edge Functions 호출 메소드

class QuizDrawApi {
  // 이미 기본 구조는 있음, 실제 API 호출 로직 구현 필요
  
  Future<CreateRoomResponse> createRoom(String userId, String nickname);
  Future<JoinRoomResponse> joinRoom(String roomCode, String userId, String nickname);
  Future<StartRoundResponse> startRound(StartRoundRequest request);
  Future<SubmitGuessResponse> submitGuess(String roundId, String userId, String guess);
  Future<VerifyAdRewardResponse> verifyAdReward(AdRewardRequest request);
  Future<UnlockPaletteResponse> unlockPalette(String userId, String paletteId);
}
```

### 🔌 실제 연동할 API 엔드포인트들
```bash
# 백엔드에서 완전 구현 완료된 API들
POST /functions/v1/create-room      # 룸 생성
POST /functions/v1/join-room        # 룸 참가
POST /functions/v1/start-round      # 라운드 시작  
POST /functions/v1/submit-guess     # 정답 제출
POST /functions/v1/verify-ad-reward # 광고 보상 검증
POST /functions/v1/unlock-palette   # 팔레트 해금
```

**API 응답 예시** (`README_BACKEND.md` 참고):
```json
// create-room 응답
{
  "room_id": "uuid",
  "room_code": "ABC123",
  "creator_user_id": "uuid", 
  "status": "waiting",
  "created_at": "2025-08-24T02:10:00Z"
}
```

---

## 🎯 핵심 기능 구현 가이드

### 1. 🎨 그림 그리기 시스템

**필수 구현 요소:**
```dart
class DrawingPainter extends CustomPainter {
  final List<DrawingPoint> points;
  final Color selectedColor;
  final double strokeWidth;
  
  @override
  void paint(Canvas canvas, Size size) {
    // 그리기 로직 구현
  }
}

class DrawingPoint {
  final Offset point;
  final Color color;
  final double strokeWidth;
  final bool isEraser;
}
```

**구현 단계:**
1. CustomPainter로 캔버스 구현
2. GestureDetector로 터치 이벤트 처리
3. 그리기 점들을 List에 저장
4. 되돌리기 기능 (점 리스트 관리)
5. Canvas → Image 변환 → 압축 → Storage 업로드

### 2. 📱 카카오톡 공유

**필수 구현 요소:**
```dart
Future<void> shareToKakao(String roomCode, String inviterName) async {
  final template = FeedTemplate(
    content: Content(
      title: '$inviterName님이 그림 퀴즈에 초대했습니다!',
      description: '방 코드: $roomCode',
      imageUrl: 'https://your-app-icon-url',
      link: Link(
        mobileWebUrl: 'https://your-app-url',
        androidExecutionParams: {'room_code': roomCode},
        iosExecutionParams: {'room_code': roomCode},
      ),
    ),
  );
  
  await ShareClient.instance.shareDefault(template: template);
}
```

### 3. 💰 AdMob 리워드 광고

**필수 구현 요소:**
```dart
class AdRewardManager {
  RewardedAd? _rewardedAd;
  
  Future<void> loadAd() async {
    await RewardedAd.load(
      adUnitId: 'your-ad-unit-id',
      request: AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (error) => print('Ad failed: $error'),
      ),
    );
  }
  
  Future<void> showAd() async {
    await _rewardedAd?.show(
      onUserEarnedReward: (ad, reward) {
        // SSV 검증을 위한 서버 호출
        _verifyReward(reward);
      },
    );
  }
  
  Future<void> _verifyReward(RewardItem reward) async {
    // verify-ad-reward API 호출
  }
}
```

---

## 🏗️ 상태 관리 구조

### 📊 전역 상태 (`app_state.dart`)
```dart
// 현재 상태: 기본 구조만 존재
// 구현 필요: 실제 상태 변수 및 메소드

class AppState extends ChangeNotifier {
  // 사용자 정보
  String? userId;
  String? nickname; 
  int coins = 0;
  
  // 현재 룸 정보
  String? currentRoomId;
  String? currentRoomCode;
  List<Player> roomPlayers = [];
  
  // 현재 라운드 정보  
  String? currentRoundId;
  String? currentDrawingUrl;
  
  // 팔레트 정보
  List<Palette> allPalettes = [];
  List<String> unlockedPaletteIds = [];
  
  // 메소드들 구현 필요
  Future<void> createRoom(String nickname);
  Future<void> joinRoom(String roomCode, String nickname);
  Future<void> startRound(String answer, String drawingPath);
  Future<void> submitGuess(String guess);
  Future<void> unlockPalette(String paletteId);
}
```

---

## 🎨 디자인 가이드라인

### 📐 접근성 기준 (`docs/5) Design.md` 참고)
- **터치 영역**: 최소 48dp × 48dp
- **폰트 크기**: 본문 16-18sp, 제목 20-24sp
- **고대비**: 배경과 텍스트 명도 차 4.5:1 이상
- **색맹 지원**: 색상만으로 정보 전달 금지

### 🎨 디자인 시스템
```dart
class AppTheme {
  // 컬러 팔레트
  static const primaryColor = Color(0xFF6C7AF7);
  static const secondaryColor = Color(0xFFFF6B9D); 
  static const backgroundColor = Color(0xFFF8F9FF);
  
  // 폰트 크기
  static const double fontSmall = 14.0;
  static const double fontRegular = 16.0;
  static const double fontLarge = 18.0;
  static const double fontTitle = 24.0;
  
  // 간격
  static const double paddingSmall = 8.0;
  static const double paddingRegular = 16.0;
  static const double paddingLarge = 24.0;
  
  // 둥근 모서리
  static const double radiusSmall = 8.0;
  static const double radiusRegular = 12.0;
  static const double radiusLarge = 16.0;
}
```

---

## 🚀 구현 우선순위 및 단계

### 1단계: 핵심 플로우 구현 (최우선)
1. **홈 화면 → 룸 생성/참가** 
2. **룸 화면 → 플레이어 목록 표시**
3. **그림 그리기 → 간단한 캔버스 구현**
4. **정답 맞히기 → 기본적인 입출력**

### 2단계: API 연동 완성
1. **Supabase API 6개 모두 연결**
2. **에러 처리 및 로딩 상태**
3. **실시간 상태 업데이트**

### 3단계: 고급 기능
1. **카카오톡 공유 + 딥링크**
2. **AdMob 광고 + SSV 검증**
3. **팔레트 시스템**

### 4단계: 최적화 및 테스트
1. **오프라인 캐시**
2. **성능 최적화**
3. **사용자 테스트**

---

## 📋 체크리스트

### ✅ 구현 완료 체크리스트

#### 🏠 홈 화면
- [ ] 빠른 시작 버튼 (create-room API 연동)
- [ ] 방 코드 입력 (join-room API 연동)  
- [ ] 내 정보 카드 (코인, 팔레트 수)
- [ ] 광고 보상 버튼 (AdMob 연동)
- [ ] 하단 네비게이션

#### 🎮 룸 화면  
- [ ] 룸 상태 표시 (대기/플레이)
- [ ] 플레이어 목록 (실시간 업데이트)
- [ ] 카카오톡 공유 버튼
- [ ] 모달 호출 (그리기/맞히기/결과)

#### 🎨 그림 그리기 모달
- [ ] CustomPainter 캔버스
- [ ] 8색 팔레트 + 해금 색상
- [ ] 펜/지우개/되돌리기 도구
- [ ] Canvas → Image → Storage 업로드
- [ ] start-round API 호출

#### 🤔 정답 맞히기 모달
- [ ] Storage에서 그림 로드
- [ ] 정답 입력 필드
- [ ] submit-guess API 호출
- [ ] 정답/오답 즉시 피드백

#### 🏆 결과 모달
- [ ] 결과 표시 (정답/시간/보상)
- [ ] 코인 획득 애니메이션
- [ ] 다음 액션 버튼

#### 🎨 팔레트 상점
- [ ] 팔레트 목록 조회
- [ ] 미리보기 카드 (색상 칩)
- [ ] 가격/상태 표시
- [ ] unlock-palette API 호출

#### ⚙️ 설정 화면
- [ ] 접근성 토글들
- [ ] 신고 기능
- [ ] 정보 페이지들

#### 🔗 API 연동
- [ ] create-room API
- [ ] join-room API  
- [ ] start-round API
- [ ] submit-guess API
- [ ] verify-ad-reward API
- [ ] unlock-palette API

#### 🎯 고급 기능
- [ ] 카카오톡 공유 + 딥링크
- [ ] AdMob 리워드 광고
- [ ] 오프라인 캐시 (SQLite)
- [ ] 실시간 상태 동기화

---

## 📚 참고 문서 및 리소스

### 📖 프로젝트 문서
- `docs/1) PRD.md` - 제품 요구사항, 기술 스택, 보상 시스템
- `docs/2) IA.md` - 화면 구조, 네비게이션, 정보 아키텍처
- `docs/3) Use-Case.md` - 사용자 시나리오, 엣지 케이스, 에러 처리
- `docs/4) ERD.md` - 데이터 모델, API 응답 구조
- `docs/5) Design.md` - 디자인 가이드라인, 접근성, UI 컴포넌트
- `README_BACKEND.md` - API 명세서, 에러 코드, 사용법

### 🔧 기술 문서
- **Flutter 공식 문서**: https://docs.flutter.dev/
- **Supabase Flutter**: https://supabase.com/docs/reference/dart/
- **Provider 상태관리**: https://pub.dev/packages/provider
- **Google Mobile Ads**: https://pub.dev/packages/google_mobile_ads
- **Kakao Flutter SDK**: https://pub.dev/packages/kakao_flutter_sdk

### 🎨 디자인 참고
- **Material Design 3**: https://m3.material.io/
- **접근성 가이드라인**: https://www.w3.org/WAI/WCAG21/quickref/
- **색상 대비 도구**: https://webaim.org/resources/contrastchecker/

---

## ⚡ 시작 방법

### 🚀 즉시 시작하기
1. **현재 Flutter 앱 실행**: `cd C:\quizdraw\app && flutter run`
2. **Supabase 로컬 시작**: `cd C:\quizdraw && supabase start`  
3. **가장 중요한 화면부터**: 홈 화면 → 룸 화면 → 그림 그리기 순서로 구현

### 🎯 **개발 헌법 준수**
- **폴백/더미 데이터 절대 금지**: 모든 데이터는 실제 API 연동
- **전체 완결 구조**: 한 화면을 하면 관련된 모든 기능 완전 구현  
- **실제 구현만**: AdMob SSV, 카카오톡 공유, Storage 업로드 실제 연동

---

**🏛️ "사용자가 실제로 사용할 수 있는 완전한 앱을 만들자!"**

현재 백엔드가 완벽하게 구축되어 있고 Flutter 기본 구조도 잘 잡혀 있어서, 이제 실제 UI와 기능만 구현하면 완전한 그림 퀴즈 앱이 완성됩니다! 🎨✨
