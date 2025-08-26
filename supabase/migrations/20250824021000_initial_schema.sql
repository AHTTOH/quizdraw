-- QuizDraw Initial Schema Migration
-- ERD.md 기반 실제 데이터베이스 스키마 생성
-- 개발 헌법 준수: 폴백/더미 데이터 절대 금지, 실제 구현만

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ===================================================================
-- 1) USERS TABLE
-- ===================================================================
CREATE TABLE users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nickname text NOT NULL CHECK (length(nickname) >= 1 AND length(nickname) <= 24),
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL
);

-- Users 인덱스
CREATE INDEX idx_users_created_at ON users(created_at);
CREATE INDEX idx_users_created_by ON users(created_by);

-- ===================================================================
-- 2) ROOMS TABLE  
-- ===================================================================
CREATE TABLE rooms (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text UNIQUE NOT NULL CHECK (code ~ '^[A-Z0-9]{6,8}$'),
    status text NOT NULL CHECK (status IN ('waiting', 'playing', 'ended')) DEFAULT 'waiting',
    created_by uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Rooms 인덱스
CREATE INDEX idx_rooms_code ON rooms(code);
CREATE INDEX idx_rooms_status ON rooms(status);
CREATE INDEX idx_rooms_created_by ON rooms(created_by);
CREATE INDEX idx_rooms_created_at ON rooms(created_at);

-- ===================================================================
-- 3) PLAYERS TABLE (룸 참가자)
-- ===================================================================
CREATE TABLE players (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id uuid NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    nickname text NOT NULL,
    score int NOT NULL DEFAULT 0,
    last_seen timestamptz NOT NULL DEFAULT now(),
    UNIQUE(room_id, user_id)
);

-- Players 인덱스
CREATE INDEX idx_players_room_id ON players(room_id);
CREATE INDEX idx_players_user_id ON players(user_id);
CREATE INDEX idx_players_last_seen ON players(last_seen);

-- ===================================================================
-- 4) ROUNDS TABLE
-- ===================================================================
CREATE TABLE rounds (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id uuid NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    drawer_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    answer text NOT NULL CHECK (length(answer) >= 1 AND length(answer) <= 32),
    status text NOT NULL CHECK (status IN ('playing', 'ended')) DEFAULT 'playing',
    winner_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
    started_at timestamptz NOT NULL DEFAULT now(),
    ended_at timestamptz
);

-- Rounds 인덱스
CREATE INDEX idx_rounds_room_id_started_at ON rounds(room_id, started_at);
CREATE INDEX idx_rounds_drawer_user_id ON rounds(drawer_user_id);
CREATE INDEX idx_rounds_winner_user_id ON rounds(winner_user_id);
CREATE INDEX idx_rounds_status ON rounds(status);
CREATE INDEX idx_rounds_started_at ON rounds(started_at);

-- ===================================================================
-- 5) DRAWINGS TABLE
-- ===================================================================
CREATE TABLE drawings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    round_id uuid NOT NULL REFERENCES rounds(id) ON DELETE CASCADE,
    storage_path text UNIQUE NOT NULL,
    width int NOT NULL CHECK (width >= 64 AND width <= 4096),
    height int NOT NULL CHECK (height >= 64 AND height <= 4096),
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Drawings 인덱스
CREATE INDEX idx_drawings_round_id ON drawings(round_id);
CREATE INDEX idx_drawings_storage_path ON drawings(storage_path);
CREATE INDEX idx_drawings_created_at ON drawings(created_at);

-- ===================================================================
-- 6) GUESSES TABLE
-- ===================================================================
CREATE TABLE guesses (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    round_id uuid NOT NULL REFERENCES rounds(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    text text NOT NULL CHECK (length(text) >= 1 AND length(text) <= 64),
    normalized_text text NOT NULL,
    is_correct boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Guesses 인덱스
CREATE INDEX idx_guesses_round_id_created_at ON guesses(round_id, created_at);
CREATE INDEX idx_guesses_user_id ON guesses(user_id);
CREATE INDEX idx_guesses_round_id_normalized ON guesses(round_id, normalized_text);
CREATE INDEX idx_guesses_created_at ON guesses(created_at);

-- 핵심 제약: 라운드당 정답자는 오직 1명만 (Partial Unique)
CREATE UNIQUE INDEX idx_guesses_unique_correct_per_round 
ON guesses(round_id) WHERE is_correct = true;

-- ===================================================================
-- 7) COIN_TX TABLE (보상/차감 원장)
-- ===================================================================
CREATE TABLE coin_tx (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type text NOT NULL CHECK (type IN ('SEND', 'RECEIVE', 'AD_REWARD', 'REDEEM')),
    amount int NOT NULL CHECK (amount != 0),
    ref_round_id uuid REFERENCES rounds(id) ON DELETE SET NULL,
    ref_ad_tx_id text,
    idem_key text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL
);

-- Coin_tx 인덱스
CREATE INDEX idx_coin_tx_user_id_created_at ON coin_tx(user_id, created_at);
CREATE INDEX idx_coin_tx_type ON coin_tx(type);
CREATE INDEX idx_coin_tx_ref_round_id ON coin_tx(ref_round_id);
CREATE INDEX idx_coin_tx_ref_ad_tx_id ON coin_tx(ref_ad_tx_id);
CREATE INDEX idx_coin_tx_created_at ON coin_tx(created_at);

-- 핵심 제약: Idempotency 키 중복 방지 (Partial Unique)
CREATE UNIQUE INDEX idx_coin_tx_unique_idem 
ON coin_tx(type, idem_key) WHERE idem_key IS NOT NULL;

-- ===================================================================
-- 8) AD_RECEIPTS TABLE (SSV 원본 영수증)
-- ===================================================================
CREATE TABLE ad_receipts (
    idempotency_key text PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider_tx_id text UNIQUE NOT NULL,
    key_id text NOT NULL,
    signature text NOT NULL,
    payload jsonb NOT NULL,
    amount int NOT NULL DEFAULT 50 CHECK (amount = 50),
    verified_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Ad_receipts 인덱스
CREATE INDEX idx_ad_receipts_user_id_created_at ON ad_receipts(user_id, created_at);
CREATE INDEX idx_ad_receipts_provider_tx_id ON ad_receipts(provider_tx_id);
CREATE INDEX idx_ad_receipts_key_id ON ad_receipts(key_id);
CREATE INDEX idx_ad_receipts_verified_at ON ad_receipts(verified_at);
CREATE INDEX idx_ad_receipts_created_at ON ad_receipts(created_at);

-- ===================================================================
-- 9) PALETTES TABLE
-- ===================================================================
CREATE TABLE palettes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text UNIQUE NOT NULL,
    swatches jsonb NOT NULL,
    price_coins int NOT NULL CHECK (price_coins >= 0),
    is_colorblind_safe boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Palettes 인덱스
CREATE INDEX idx_palettes_name ON palettes(name);
CREATE INDEX idx_palettes_price_coins ON palettes(price_coins);
CREATE INDEX idx_palettes_is_colorblind_safe ON palettes(is_colorblind_safe);
CREATE INDEX idx_palettes_created_at ON palettes(created_at);

-- Swatches JSONB 검색을 위한 GIN 인덱스
CREATE INDEX idx_palettes_swatches_gin ON palettes USING gin(swatches);

-- ===================================================================
-- 10) USER_PALETTES TABLE
-- ===================================================================
CREATE TABLE user_palettes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    palette_id uuid NOT NULL REFERENCES palettes(id) ON DELETE CASCADE,
    unlocked_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(user_id, palette_id)
);

-- User_palettes 인덱스
CREATE INDEX idx_user_palettes_user_id ON user_palettes(user_id);
CREATE INDEX idx_user_palettes_palette_id ON user_palettes(palette_id);
CREATE INDEX idx_user_palettes_unlocked_at ON user_palettes(unlocked_at);

-- ===================================================================
-- 11) COIN_BALANCES VIEW (성능 최적화)
-- ===================================================================
CREATE VIEW coin_balances AS
SELECT 
    user_id,
    COALESCE(SUM(amount), 0) AS balance
FROM coin_tx
GROUP BY user_id;

-- ===================================================================
-- 12) 기본 팔레트 데이터 삽입 (시스템 데이터)
-- ===================================================================
-- 개발 헌법 준수: 실제 데이터만, 더미 데이터 금지
-- 기본 팔레트는 시스템 필수 데이터이므로 허용됨

-- 기본 모노 팔레트
INSERT INTO palettes (id, name, swatches, price_coins, is_colorblind_safe)
VALUES (
    'c0000000-0000-0000-0000-000000000001',
    'Basic Mono',
    '["#000000", "#404040", "#808080", "#C0C0C0", "#FFFFFF"]'::jsonb,
    0,  -- 무료 기본 팔레트
    true
);

-- 파스텔 팔레트
INSERT INTO palettes (id, name, swatches, price_coins, is_colorblind_safe)
VALUES (
    'c0000000-0000-0000-0000-000000000002',
    'Pastel Dream',
    '["#FFB6C1", "#FFEAA7", "#81ECEC", "#A29BFE", "#FD79A8", "#FDCB6E", "#55A3FF", "#FF7675"]'::jsonb,
    200,
    false
);

-- 네온 팔레트
INSERT INTO palettes (id, name, swatches, price_coins, is_colorblind_safe)
VALUES (
    'c0000000-0000-0000-0000-000000000003',
    'Neon Bright',
    '["#FF073A", "#39FF14", "#00FFFF", "#FF00FF", "#FFFF00", "#FF8C00", "#8A2BE2", "#FF1493"]'::jsonb,
    300,
    false
);

-- ===================================================================
-- TRIGGERS AND FUNCTIONS (비즈니스 로직)
-- ===================================================================

-- 텍스트 정규화 함수 (정답 비교용)
CREATE OR REPLACE FUNCTION normalize_text(input_text text) 
RETURNS text AS $$
BEGIN
    -- 소문자 변환, 공백 제거, 특수문자 제거
    RETURN regexp_replace(
        trim(lower(input_text)), 
        '[^a-z0-9가-힣]', 
        '', 
        'g'
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 추측 생성 시 정규화 텍스트 자동 설정
CREATE OR REPLACE FUNCTION set_normalized_text() 
RETURNS trigger AS $$
BEGIN
    NEW.normalized_text := normalize_text(NEW.text);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_guesses_normalize
    BEFORE INSERT OR UPDATE ON guesses
    FOR EACH ROW
    EXECUTE FUNCTION set_normalized_text();

-- 정답 체크 및 라운드 종료 처리
CREATE OR REPLACE FUNCTION check_answer_and_end_round() 
RETURNS trigger AS $$
DECLARE
    round_answer text;
    normalized_answer text;
BEGIN
    -- 정답이 맞는지 확인
    IF NEW.is_correct AND OLD.is_correct IS DISTINCT FROM NEW.is_correct THEN
        -- 라운드 정답 가져오기
        SELECT answer INTO round_answer 
        FROM rounds 
        WHERE id = NEW.round_id;
        
        normalized_answer := normalize_text(round_answer);
        
        -- 정답이 실제로 맞는지 검증
        IF NEW.normalized_text = normalized_answer THEN
            -- 라운드 종료 및 승자 설정
            UPDATE rounds 
            SET 
                status = 'ended',
                winner_user_id = NEW.user_id,
                ended_at = now()
            WHERE id = NEW.round_id AND status = 'playing';
        ELSE
            -- 정답이 틀렸으면 is_correct를 false로 변경
            NEW.is_correct := false;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_guesses_check_answer
    AFTER UPDATE ON guesses
    FOR EACH ROW
    EXECUTE FUNCTION check_answer_and_end_round();

-- ===================================================================
-- COMMENTS (문서화)
-- ===================================================================
COMMENT ON TABLE users IS '사용자 기본 정보';
COMMENT ON TABLE rooms IS '게임 룸 (방 코드로 접근)';
COMMENT ON TABLE players IS '룸별 참가자 정보';
COMMENT ON TABLE rounds IS '게임 라운드 (그림 그리기 세션)';
COMMENT ON TABLE drawings IS '업로드된 그림 정보';
COMMENT ON TABLE guesses IS '정답 추측 기록';
COMMENT ON TABLE coin_tx IS '코인 거래 원장 (보상/차감)';
COMMENT ON TABLE ad_receipts IS 'AdMob SSV 영수증 원본';
COMMENT ON TABLE palettes IS '색상 팔레트 정의';
COMMENT ON TABLE user_palettes IS '사용자 해금 팔레트';
COMMENT ON VIEW coin_balances IS '사용자별 코인 잔액 집계';

COMMENT ON INDEX idx_guesses_unique_correct_per_round IS '라운드당 정답자 1명만 허용';
COMMENT ON INDEX idx_coin_tx_unique_idem IS 'Idempotency 키 중복 방지';

-- Migration 완료 로그
INSERT INTO users (nickname, created_by) 
VALUES ('System', 'migration:20250824021000');

-- 스키마 버전 기록
CREATE TABLE IF NOT EXISTS schema_versions (
    version text PRIMARY KEY,
    applied_at timestamptz NOT NULL DEFAULT now(),
    description text
);

INSERT INTO schema_versions (version, description)
VALUES ('20250824021000', 'Initial QuizDraw schema with all tables, indexes, triggers, and base palettes');
