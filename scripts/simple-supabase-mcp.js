#!/usr/bin/env node

// 간단한 Supabase MCP 서버 - 의존성 없이 작동
const { createClient } = require('@supabase/supabase-js');

// Supabase 환경 변수
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_KEY) {
  console.error('Error: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY required');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

// MCP 프로토콜 구현
process.stdin.setEncoding('utf8');
process.stdout.setEncoding('utf8');

let buffer = '';

process.stdin.on('data', (chunk) => {
  buffer += chunk;
  
  let lines = buffer.split('\n');
  buffer = lines.pop() || '';
  
  for (let line of lines) {
    if (line.trim()) {
      try {
        const message = JSON.parse(line);
        handleMessage(message);
      } catch (error) {
        console.error('Parse error:', error.message);
      }
    }
  }
});

async function handleMessage(message) {
  try {
    if (message.method === 'initialize') {
      sendResponse(message.id, {
        protocolVersion: '2024-11-05',
        capabilities: {
          tools: {}
        },
        serverInfo: {
          name: 'quizdraw-supabase',
          version: '1.0.0'
        }
      });
    } else if (message.method === 'tools/list') {
      sendResponse(message.id, {
        tools: [
          {
            name: 'execute_sql',
            description: 'Supabase에서 SQL 쿼리 실행',
            inputSchema: {
              type: 'object',
              properties: {
                query: { type: 'string', description: 'SQL 쿼리문' }
              },
              required: ['query']
            }
          },
          {
            name: 'list_tables',
            description: '데이터베이스의 모든 테이블 목록 조회',
            inputSchema: { type: 'object', properties: {} }
          },
          {
            name: 'describe_table',
            description: '테이블 구조 확인',
            inputSchema: {
              type: 'object',
              properties: {
                table: { type: 'string', description: '테이블 이름' }
              },
              required: ['table']
            }
          },
          {
            name: 'select_data',
            description: '테이블에서 데이터 조회',
            inputSchema: {
              type: 'object',
              properties: {
                table: { type: 'string', description: '테이블 이름' },
                columns: { type: 'string', description: '조회할 컬럼 (기본: *)' },
                limit: { type: 'number', description: '결과 개수 제한 (기본: 100)' },
                filters: { type: 'object', description: '필터 조건 (선택사항)' }
              },
              required: ['table']
            }
          }
        ]
      });
    } else if (message.method === 'tools/call') {
      await handleToolCall(message);
    } else {
      sendError(message.id, -32601, 'Method not found');
    }
  } catch (error) {
    sendError(message.id, -32603, error.message);
  }
}

async function handleToolCall(message) {
  const { name, arguments: args } = message.params;
  
  try {
    let result;
    
    switch (name) {
      case 'execute_sql':
        result = await executeSql(args.query);
        break;
      case 'list_tables':
        result = await listTables();
        break;
      case 'describe_table':
        result = await describeTable(args.table);
        break;
      case 'select_data':
        result = await selectData(args.table, args.columns, args.limit, args.filters);
        break;
      default:
        throw new Error(`Unknown tool: ${name}`);
    }
    
    sendResponse(message.id, {
      content: [
        {
          type: 'text',
          text: JSON.stringify(result, null, 2)
        }
      ]
    });
  } catch (error) {
    sendError(message.id, -32603, `Tool error: ${error.message}`);
  }
}

async function executeSql(query) {
  const { data, error } = await supabase.rpc('exec_sql', { query });
  if (error) throw new Error(error.message);
  return { status: 'SQL 실행 완료', data };
}

async function listTables() {
  const { data, error } = await supabase
    .from('information_schema.tables')
    .select('table_name')
    .eq('table_schema', 'public');
  
  if (error) throw new Error(error.message);
  return data;
}

async function describeTable(table) {
  const { data, error } = await supabase
    .from('information_schema.columns')
    .select('column_name, data_type, is_nullable')
    .eq('table_schema', 'public')
    .eq('table_name', table);
  
  if (error) throw new Error(error.message);
  return { table, columns: data };
}

async function selectData(table, columns = '*', limit = 100, filters = {}) {
  let query = supabase.from(table).select(columns).limit(limit);
  
  for (const [key, value] of Object.entries(filters)) {
    query = query.eq(key, value);
  }
  
  const { data, error } = await query;
  if (error) throw new Error(error.message);
  return data;
}

function sendResponse(id, result) {
  const response = {
    jsonrpc: '2.0',
    id,
    result
  };
  process.stdout.write(JSON.stringify(response) + '\n');
}

function sendError(id, code, message) {
  const response = {
    jsonrpc: '2.0',
    id,
    error: { code, message }
  };
  process.stdout.write(JSON.stringify(response) + '\n');
}

console.error('Simple QuizDraw Supabase MCP server starting...');
