-- QuizDraw Row Level Security (RLS) 정책
-- 개발 헌법 준수: 실제 보안 구현, 임시 방편 금지
-- ERD.md 기반: 선택적 읽기, Edge Functions 전용 쓰기

-- ===================================================================
-- RLS 활성화 (모든 테이블)
-- ===================================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE players ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE drawings ENABLE ROW LEVEL SECURITY;
ALTER TABLE guesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE coin_tx ENABLE ROW LEVEL SECURITY;
ALTER TABLE ad_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE palettes ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_palettes ENABLE ROW LEVEL SECURITY;

-- ===================================================================
-- USERS 정책
-- ===================================================================
-- 사용자는 자신의 정보만 조회 가능
CREATE POLICY users_select_own 
ON users FOR SELECT 
USING (auth.uid() = id);

-- Edge Functions만 사용자 생성/수정 가능
CREATE POLICY users_insert_service 
ON users FOR INSERT 
WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY users_update_service 
ON users FOR UPDATE 
USING (auth.jwt() ->> 'role' = 'service_role');

-- ===================================================================
-- ROOMS 정책  
-- ===================================================================
-- 룸 멤버만 룸 정보 조회 가능
CREATE POLICY rooms_select_members 
ON rooms FOR SELECT 
USING (
    EXISTS (
        SELECT 1 FROM players 
        WHERE players.room_id = rooms.id 
        AND players.user_id = auth.uid()
    )
    OR auth.jwt() ->> 'role' = 'service_role'
);

-- Edge Functions만 룸 생성/수정 가능
CREATE POLICY rooms_modify_service 
ON rooms FOR ALL 
USING (auth.jwt() ->> 'role' = 'service_role')
WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

-- ===================================================================
-- PLAYERS 정책
-- ===================================================================
-- 같은 룸 멤버끼리만 서로 조회 가능
CREATE POLICY players_select_roommates 
ON players FOR SELECT 
USING (
    EXISTS (
        SELECT 1 FROM players p2 
        WHERE p2.room_id = players.room_id 
        AND p2.user_id = auth.uid()
    )
    OR auth.jwt() ->> 'role' = 'service_role'
);

-- Edge Functions만 참가자 관리 가능
CREATE POLICY players_modify_service 
ON players FOR ALL 
USING (auth.jwt() ->> 'role' = 'service_role')
WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

-- ===================================================================
-- ROUNDS 정책
-- ===================================================================
-- 룸 멤버만 라운드 조회 가능
CREATE POLICY rounds_select_room_members 
ON rounds FOR SELECT 
USING (
    EXISTS (
        SELECT 1 FROM players 
        WHERE players.room_id = rounds.room_id 
        AND players.user_id = auth.uid()
    )
    OR auth.jwt() ->> 'role' = 'service_role'
);

-- Edge Functions만 라운드 관리 가능
CREATE POLICY rounds_modify_service 
ON rounds FOR ALL 
USING (auth.jwt() ->> 'role' = 'service_role')
WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

-- ===================================================================
-- DRAWINGS 정책
-- ===================================================================
-- 룸 멤버만 그림 조회 가능
CREATE POLICY drawings_select_room_members 
ON drawings FOR SELECT 
USING (
    EXISTS (
        SELECT 1 FROM players p
        JOIN rounds r ON r.room_id = p.room_id
        WHERE r.id = drawings.round_id 
        AND p.user_id = auth.uid()
    )
    OR auth.jwt() ->> 'role' = 'service_role'
);

-- Edge Functions만 그림 관리 가능
CREATE POLICY drawings_modify_service 
ON drawings FOR ALL 
USING (auth.jwt() ->> 'role' = 'service_role')
WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

-- ===================================================================
-- GUESSES 정책
-- ===================================================================
-- 룸 멤버만 추측 조회 가능
CREATE POLICY guesses_select_room_members 
ON guesses FOR SELECT 
USING (
    EXISTS (
        SELECT 1 FROM players p
        JOIN rounds r ON r.room_id = p.room_id
        WHERE r.id = guesses.round_id 
        AND p.user_id = auth.uid()
    )
    OR auth.jwt() ->> 'role' = 'service_role'
);

-- 사용자는 자신의 추측 제출 가능 (룸 멤버인 경우만)
CREATE POLICY guesses_insert_room_members 
ON guesses FOR INSERT 
WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
        SELECT 1 FROM players p
        JOIN rounds r ON r.room_id = p.room_id
        WHERE r.id = round_id 
        AND p.user_id = auth.uid()
        AND r.status = 'playing'  -- 진행 중인 라운드만
    )
);

-- Edge Functions는 모든 추측 관리 가능
CREATE POLICY guesses_modify_service 
ON guesses FOR ALL 
USING (auth.jwt() ->> 'role' = 'service_role')
WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

-- ===================================================================
-- COIN_TX 정책 (보상 원장)
-- ===================================================================
-- 사용자는 자신의 거래만 조회 가능
CREATE POLICY coin_tx_select_own 
ON coin_tx FOR SELECT 
USING (auth.uid() = user_id OR auth.jwt() ->> 'role' = 'service_role');

-- Edge Functions만 거래 생성 가능 (클라이언트 직접 조작 금지)
CREATE POLICY coin_tx_insert_service 
ON coin_tx FOR INSERT 
WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

-- ===================================================================
-- AD_RECEIPTS 정책 (SSV 영수증)
-- ===================================================================
-- 사용자는 자신의 영수증만 조회 가능
CREATE POLICY ad_receipts_select_own 
ON ad_receipts FOR SELECT 
USING (auth.uid() = user_id OR auth.jwt() ->> 'role' = 'service_role');

-- Edge Functions만 영수증 생성/수정 가능
CREATE POLICY ad_receipts_modify_service 
ON ad_receipts FOR ALL 
USING (auth.jwt() ->> 'role' = 'service_role')
WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

-- ===================================================================
-- PALETTES 정책 (색상 팔레트)
-- ===================================================================
-- 모든 사용자가 팔레트 목록 조회 가능 (가격표)
CREATE POLICY palettes_select_all 
ON palettes FOR SELECT 
USING (true);

-- Edge Functions만 팔레트 관리 가능
CREATE POLICY palettes_modify_service 
ON palettes FOR ALL 
USING (auth.jwt() ->> 'role' = 'service_role')
WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

-- ===================================================================
-- USER_PALETTES 정책 (사용자 해금 팔레트)
-- ===================================================================
-- 사용자는 자신의 해금 팔레트만 조회 가능
CREATE POLICY user_palettes_select_own 
ON user_palettes FOR SELECT 
USING (auth.uid() = user_id OR auth.jwt() ->> 'role' = 'service_role');

-- Edge Functions만 팔레트 해금 처리 가능
CREATE POLICY user_palettes_modify_service 
ON user_palettes FOR ALL 
USING (auth.jwt() ->> 'role' = 'service_role')
WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

-- ===================================================================
-- 성능 최적화: 정책 관련 인덱스
-- ===================================================================
-- auth.uid() 기반 조회 최적화를 위한 추가 인덱스
CREATE INDEX IF NOT EXISTS idx_players_user_id_room_id ON players(user_id, room_id);

-- RLS 정책 완료 로그
INSERT INTO schema_versions (version, description)
VALUES ('20250824021001', 'Row Level Security policies for all tables');
