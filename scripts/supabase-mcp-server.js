#!/usr/bin/env node

const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const { CallToolRequestSchema, ListToolsRequestSchema } = require('@modelcontextprotocol/sdk/types.js');
const { createClient } = require('@supabase/supabase-js');

// Supabase client initialization
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables are required');
}

const supabase = createClient(supabaseUrl, supabaseKey);

class QuizDrawSupabaseMCPServer {
  constructor() {
    this.server = new Server(
      {
        name: 'quizdraw-supabase-mcp',
        version: '0.1.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupToolHandlers();
    this.setupErrorHandling();
  }

  setupToolHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'get_room_status',
          description: 'Get room status and current round information',
          inputSchema: {
            type: 'object',
            properties: {
              code: {
                type: 'string',
                description: 'Room code (e.g., AB12CD)',
              },
            },
            required: ['code'],
          },
        },
        {
          name: 'list_active_rooms',
          description: 'List all active rooms with basic info',
          inputSchema: {
            type: 'object',
            properties: {
              status: {
                type: 'string',
                description: 'Filter by room status (waiting, playing, ended)',
                enum: ['waiting', 'playing', 'ended'],
              },
              limit: {
                type: 'number',
                description: 'Maximum number of rooms to return',
                default: 10,
              },
            },
          },
        },
        {
          name: 'get_user_profile',
          description: 'Get user profile with coin balance and unlocked palettes',
          inputSchema: {
            type: 'object',
            properties: {
              user_id: {
                type: 'string',
                description: 'User UUID',
              },
            },
            required: ['user_id'],
          },
        },
        {
          name: 'get_round_details',
          description: 'Get detailed round information including guesses and drawing',
          inputSchema: {
            type: 'object',
            properties: {
              round_id: {
                type: 'string',
                description: 'Round UUID',
              },
            },
            required: ['round_id'],
          },
        },
        {
          name: 'get_coin_transactions',
          description: 'Get coin transaction history for a user',
          inputSchema: {
            type: 'object',
            properties: {
              user_id: {
                type: 'string',
                description: 'User UUID',
              },
              limit: {
                type: 'number',
                description: 'Maximum number of transactions to return',
                default: 20,
              },
            },
            required: ['user_id'],
          },
        },
        {
          name: 'get_palettes',
          description: 'Get all available palettes with unlock status for a user',
          inputSchema: {
            type: 'object',
            properties: {
              user_id: {
                type: 'string',
                description: 'User UUID (optional, to check unlock status)',
              },
            },
          },
        },
        {
          name: 'query_database',
          description: 'Execute a custom SQL query (read-only)',
          inputSchema: {
            type: 'object',
            properties: {
              query: {
                type: 'string',
                description: 'SQL query to execute',
              },
              params: {
                type: 'array',
                description: 'Query parameters',
                items: {
                  type: 'string',
                },
              },
            },
            required: ['query'],
          },
        },
        {
          name: 'get_ad_receipts',
          description: 'Get ad receipt history for debugging SSV issues',
          inputSchema: {
            type: 'object',
            properties: {
              user_id: {
                type: 'string',
                description: 'User UUID (optional)',
              },
              limit: {
                type: 'number',
                description: 'Maximum number of receipts to return',
                default: 10,
              },
            },
          },
        },
      ],
    }));

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'get_room_status':
            return await this.getRoomStatus(args.code);
          
          case 'list_active_rooms':
            return await this.listActiveRooms(args.status, args.limit || 10);
          
          case 'get_user_profile':
            return await this.getUserProfile(args.user_id);
          
          case 'get_round_details':
            return await this.getRoundDetails(args.round_id);
          
          case 'get_coin_transactions':
            return await this.getCoinTransactions(args.user_id, args.limit || 20);
          
          case 'get_palettes':
            return await this.getPalettes(args.user_id);
          
          case 'query_database':
            return await this.queryDatabase(args.query, args.params);
          
          case 'get_ad_receipts':
            return await this.getAdReceipts(args.user_id, args.limit || 10);
          
          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: 'text',
              text: `Error executing ${name}: ${error.message}`,
            },
          ],
          isError: true,
        };
      }
    });
  }

  async getRoomStatus(code) {
    const { data, error } = await supabase
      .from('rooms')
      .select(`
        id,
        code,
        status,
        created_at,
        created_by,
        players(id, nickname, score, last_seen),
        rounds(
          id,
          status,
          answer,
          started_at,
          ended_at,
          winner_user_id,
          drawings(id, storage_path, width, height)
        )
      `)
      .eq('code', code)
      .order('started_at', { foreignTable: 'rounds', ascending: false })
      .limit(1, { foreignTable: 'rounds' })
      .single();

    if (error) throw error;

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(data, null, 2),
        },
      ],
    };
  }

  async listActiveRooms(status, limit) {
    let query = supabase
      .from('rooms')
      .select(`
        id,
        code,
        status,
        created_at,
        players(count)
      `)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (status) {
      query = query.eq('status', status);
    }

    const { data, error } = await query;
    if (error) throw error;

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(data, null, 2),
        },
      ],
    };
  }

  async getUserProfile(userId) {
    // Get user basic info
    const { data: user, error: userError } = await supabase
      .from('users')
      .select('id, nickname, created_at')
      .eq('id', userId)
      .single();

    if (userError) throw userError;

    // Get coin balance
    const { data: balance, error: balanceError } = await supabase
      .from('coin_balances')
      .select('balance')
      .eq('user_id', userId)
      .single();

    // Get unlocked palettes
    const { data: unlockedPalettes, error: palettesError } = await supabase
      .from('user_palettes')
      .select(`
        unlocked_at,
        palettes(id, name, price_coins, is_colorblind_safe)
      `)
      .eq('user_id', userId);

    const profile = {
      ...user,
      coin_balance: balance?.balance || 0,
      unlocked_palettes: unlockedPalettes || [],
    };

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(profile, null, 2),
        },
      ],
    };
  }

  async getRoundDetails(roundId) {
    const { data, error } = await supabase
      .from('rounds')
      .select(`
        id,
        room_id,
        drawer_user_id,
        answer,
        status,
        winner_user_id,
        started_at,
        ended_at,
        drawings(id, storage_path, width, height, created_at),
        guesses(
          id,
          user_id,
          text,
          normalized_text,
          is_correct,
          created_at,
          users(nickname)
        )
      `)
      .eq('id', roundId)
      .order('created_at', { foreignTable: 'guesses', ascending: true })
      .single();

    if (error) throw error;

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(data, null, 2),
        },
      ],
    };
  }

  async getCoinTransactions(userId, limit) {
    const { data, error } = await supabase
      .from('coin_tx')
      .select(`
        id,
        type,
        amount,
        ref_round_id,
        ref_ad_tx_id,
        idem_key,
        created_at,
        created_by
      `)
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (error) throw error;

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(data, null, 2),
        },
      ],
    };
  }

  async getPalettes(userId) {
    const { data: palettes, error } = await supabase
      .from('palettes')
      .select(`
        id,
        name,
        swatches,
        price_coins,
        is_colorblind_safe,
        created_at
      `)
      .order('price_coins', { ascending: true });

    if (error) throw error;

    if (userId) {
      // Get user's unlocked palettes
      const { data: userPalettes, error: userPalettesError } = await supabase
        .from('user_palettes')
        .select('palette_id, unlocked_at')
        .eq('user_id', userId);

      if (!userPalettesError) {
        const unlockedIds = new Set(userPalettes.map(up => up.palette_id));
        palettes.forEach(palette => {
          palette.is_unlocked = unlockedIds.has(palette.id);
          if (palette.is_unlocked) {
            const unlock = userPalettes.find(up => up.palette_id === palette.id);
            palette.unlocked_at = unlock.unlocked_at;
          }
        });
      }
    }

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(palettes, null, 2),
        },
      ],
    };
  }

  async queryDatabase(query, params = []) {
    // Safety check: only allow SELECT queries
    const trimmedQuery = query.trim().toLowerCase();
    if (!trimmedQuery.startsWith('select')) {
      throw new Error('Only SELECT queries are allowed');
    }

    const { data, error } = await supabase.rpc('execute_sql', {
      sql_query: query,
      sql_params: params,
    });

    if (error) throw error;

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(data, null, 2),
        },
      ],
    };
  }

  async getAdReceipts(userId, limit) {
    let query = supabase
      .from('ad_receipts')
      .select(`
        idempotency_key,
        user_id,
        provider_tx_id,
        key_id,
        amount,
        verified_at,
        created_at
      `)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (userId) {
      query = query.eq('user_id', userId);
    }

    const { data, error } = await query;
    if (error) throw error;

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(data, null, 2),
        },
      ],
    };
  }

  setupErrorHandling() {
    this.server.onerror = (error) => {
      console.error('[MCP Error]', error);
    };

    process.on('SIGINT', async () => {
      await this.server.close();
      process.exit(0);
    });
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('QuizDraw Supabase MCP server running on stdio');
  }
}

const server = new QuizDrawSupabaseMCPServer();
server.run().catch(console.error);
