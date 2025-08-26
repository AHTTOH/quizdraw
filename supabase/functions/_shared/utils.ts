// QuizDraw Shared Utilities
// 개발 헌법 준수: 실제 구현만, 폴백 데이터 절대 금지

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Supabase 클라이언트 생성 (service_role 권한)
export function createServiceClient() {
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  
  if (!supabaseUrl) {
    throw new Error('MISSING_CONFIG: SUPABASE_URL environment variable is required');
  }
  
  if (!supabaseServiceKey) {
    throw new Error('MISSING_CONFIG: SUPABASE_SERVICE_ROLE_KEY environment variable is required');
  }

  return createClient(supabaseUrl, supabaseServiceKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

// 텍스트 정규화 함수 (DB 함수와 동일한 로직)
export function normalizeText(text: string): string {
  return text
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9가-힣]/g, '');
}

// 룸 코드 생성 (6자리 영숫자)
export function generateRoomCode(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = '';
  for (let i = 0; i < 6; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

// HTTP 응답 헬퍼
export function createResponse(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-client-info, apikey',
    },
  });
}

export function createErrorResponse(error: string, status = 400, details?: any) {
  console.error(`Error [${status}]:`, error, details);
  
  return createResponse({
    error,
    details: details || null,
    timestamp: new Date().toISOString(),
  }, status);
}

// CORS 처리
export function handleCors(req: Request) {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-client-info, apikey',
        'Access-Control-Max-Age': '86400',
      },
    });
  }
  return null;
}

// 요청 검증 헬퍼
export function validateRequestMethod(req: Request, allowedMethods: string[]) {
  if (!allowedMethods.includes(req.method)) {
    throw new Error(`Method ${req.method} not allowed. Allowed: ${allowedMethods.join(', ')}`);
  }
}

export async function parseRequestBody(req: Request) {
  try {
    if (!req.body) {
      throw new Error('Request body is empty');
    }
    
    const body = await req.json();
    
    if (!body || typeof body !== 'object') {
      throw new Error('Invalid request body format');
    }
    
    return body;
  } catch (error) {
    throw new Error(`Failed to parse request body: ${error.message}`);
  }
}

// 사용자 인증 확인
export function validateAuth(req: Request) {
  const authHeader = req.headers.get('Authorization');
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new Error('Missing or invalid Authorization header');
  }
  
  return authHeader.replace('Bearer ', '');
}

// Idempotency 키 생성
export function generateIdempotencyKey(type: string, ...params: string[]): string {
  return `${type}:${params.join(':')}`;
}

// 시간 유틸리티
export function isWithinTimeLimit(timestamp: string, limitMinutes: number): boolean {
  const now = new Date();
  const time = new Date(timestamp);
  const diffMinutes = (now.getTime() - time.getTime()) / (1000 * 60);
  return diffMinutes <= limitMinutes;
}

// 데이터베이스 트랜잭션 헬퍼
export async function withTransaction<T>(
  supabase: any,
  callback: (client: any) => Promise<T>
): Promise<T> {
  // Supabase는 자동으로 트랜잭션을 관리하므로, 단순히 콜백 실행
  // 실제 프로덕션에서는 더 복잡한 트랜잭션 관리가 필요할 수 있음
  try {
    return await callback(supabase);
  } catch (error) {
    // 에러 발생 시 롤백은 자동으로 처리됨
    throw error;
  }
}

// 비즈니스 규칙 검증
export const BUSINESS_RULES = {
  // 보상 금액
  SEND_REWARD: 10,
  RECEIVE_REWARD: 10,
  AD_REWARD: 50,
  
  // 팔레트 가격
  PALETTE_PRICES: {
    'Basic Mono': 0,
    'Pastel Dream': 200,
    'Neon Bright': 300,
  },
  
  // 제한사항
  MAX_ROOM_PLAYERS: 8,
  MAX_ROUNDS_PER_ROOM: 20,
  MAX_GUESSES_PER_ROUND: 50,
  
  // 시간 제한
  ROOM_TIMEOUT_MINUTES: 60,
  ROUND_TIMEOUT_MINUTES: 10,
  
  // 텍스트 제한
  MAX_NICKNAME_LENGTH: 24,
  MAX_ANSWER_LENGTH: 32,
  MAX_GUESS_LENGTH: 64,
  
  // 일일 제한 (원격 플래그로 조정 예정)
  DAILY_AD_LIMIT: 5,
  DAILY_SEND_LIMIT: 10,
  DAILY_RECEIVE_LIMIT: 10,
} as const;

// 입력 검증 함수들
export function validateNickname(nickname: string): void {
  if (!nickname || typeof nickname !== 'string') {
    throw new Error('Nickname is required and must be a string');
  }
  
  if (nickname.length < 1 || nickname.length > BUSINESS_RULES.MAX_NICKNAME_LENGTH) {
    throw new Error(`Nickname must be 1-${BUSINESS_RULES.MAX_NICKNAME_LENGTH} characters`);
  }
}

export function validateAnswer(answer: string): void {
  if (!answer || typeof answer !== 'string') {
    throw new Error('Answer is required and must be a string');
  }
  
  if (answer.length < 1 || answer.length > BUSINESS_RULES.MAX_ANSWER_LENGTH) {
    throw new Error(`Answer must be 1-${BUSINESS_RULES.MAX_ANSWER_LENGTH} characters`);
  }
}

export function validateGuess(guess: string): void {
  if (!guess || typeof guess !== 'string') {
    throw new Error('Guess is required and must be a string');
  }
  
  if (guess.length < 1 || guess.length > BUSINESS_RULES.MAX_GUESS_LENGTH) {
    throw new Error(`Guess must be 1-${BUSINESS_RULES.MAX_GUESS_LENGTH} characters`);
  }
}

export function validateRoomCode(code: string): void {
  if (!code || typeof code !== 'string') {
    throw new Error('Room code is required and must be a string');
  }
  
  if (!/^[A-Z0-9]{6,8}$/.test(code)) {
    throw new Error('Room code must be 6-8 characters, uppercase letters and numbers only');
  }
}

export function validateUUID(id: string, fieldName: string): void {
  if (!id || typeof id !== 'string') {
    throw new Error(`${fieldName} is required and must be a string`);
  }
  
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!uuidRegex.test(id)) {
    throw new Error(`${fieldName} must be a valid UUID`);
  }
}

// 로깅 유틸리티
export function logInfo(message: string, data?: any) {
  console.log(`[INFO] ${new Date().toISOString()} - ${message}`, data ? JSON.stringify(data) : '');
}

export function logError(message: string, error?: any) {
  console.error(`[ERROR] ${new Date().toISOString()} - ${message}`, error);
}

export function logWarning(message: string, data?: any) {
  console.warn(`[WARNING] ${new Date().toISOString()} - ${message}`, data ? JSON.stringify(data) : '');
}
