import 'package:supabase_flutter/supabase_flutter.dart';

class QuizDrawAPI {
  static final SupabaseClient _client = Supabase.instance.client;

  /// 코인 잔액 조회
  static Future<int> getCoinBalance() async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) throw Exception('로그인이 필요합니다');

      final response = await _client
          .from('coin_balances')
          .select('balance')
          .eq('user_id', uid)
          .single();

      return (response['balance'] as int?) ?? 0;
    } catch (e) {
      // 사용자가 없으면 0 반환
      if (e.toString().contains('PGRST116')) {
        return 0;
      }
      throw Exception('잔액 조회 실패: $e');
    }
  }

  /// 방 생성
  static Future<Map<String, dynamic>?> createRoom() async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) throw Exception('로그인이 필요합니다');

      final response = await _client.functions.invoke(
        'create-room',
        body: {
          'creator_user_id': uid,
          'creator_nickname': '플레이어',
        },
      );

      if (response.data == null) {
        throw Exception('방 생성에 실패했습니다');
      }

      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      throw Exception('방 생성 실패: $e');
    }
  }

  /// 방 참가
  static Future<Map<String, dynamic>?> joinRoom(String roomCode) async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) throw Exception('로그인이 필요합니다');

      final response = await _client.functions.invoke(
        'join-room',
        body: {
          'room_code': roomCode,
          'user_id': uid,
          'nickname': '플레이어',
        },
      );

      if (response.data == null) {
        throw Exception('방 참가에 실패했습니다');
      }

      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      throw Exception('방 참가 실패: $e');
    }
  }

  /// 라운드 시작
  static Future<Map<String, dynamic>?> startRound({
    String? roomId,
    String? roomCode,
    required String answer,
    required String drawingStoragePath,
    required int drawingWidth,
    required int drawingHeight,
  }) async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) throw Exception('로그인이 필요합니다');

      final response = await _client.functions.invoke(
        'start-round',
        body: {
          if (roomId != null) 'room_id': roomId,
          if (roomCode != null) 'room_code': roomCode,
          'drawer_user_id': uid,
          'answer': answer,
          'drawing_storage_path': drawingStoragePath,
          'drawing_width': drawingWidth,
          'drawing_height': drawingHeight,
        },
      );

      if (response.data == null) {
        throw Exception('라운드 시작에 실패했습니다');
      }

      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      throw Exception('라운드 시작 실패: $e');
    }
  }

  /// 정답 제출
  static Future<Map<String, dynamic>?> submitGuess(
    {String? roundId, String? roomId, String? roomCode, required String guess}) async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) throw Exception('로그인이 필요합니다');

      final response = await _client.functions.invoke(
        'submit-guess',
        body: {
          if (roundId != null) 'round_id': roundId,
          if (roomId != null) 'room_id': roomId,
          if (roomCode != null) 'room_code': roomCode,
          'user_id': uid,
          'guess': guess,
        },
      );

      if (response.data == null) {
        throw Exception('정답 제출에 실패했습니다');
      }

      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      throw Exception('정답 제출 실패: $e');
    }
  }

  /// 팔레트 해금
  static Future<Map<String, dynamic>?> unlockPalette(String paletteId) async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) throw Exception('로그인이 필요합니다');

      final response = await _client.functions.invoke(
        'unlock-palette',
        body: {
          'user_id': uid,
          'palette_id': paletteId,
        },
      );

      if (response.data == null) {
        throw Exception('팔레트 해금에 실패했습니다');
      }

      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      throw Exception('팔레트 해금 실패: $e');
    }
  }

  /// AdMob SSV 검증
  static Future<Map<String, dynamic>?> verifyAdReward(
    String idempotencyKey,
    String providerTxId,
    String keyId,
    String signature,
    Map<String, dynamic> payload,
  ) async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) throw Exception('로그인이 필요합니다');

      final response = await _client.functions.invoke(
        'verify-ad-reward',
        body: {
          'user_id': uid,
          'idempotency_key': idempotencyKey,
          'provider_tx_id': providerTxId,
          'key_id': keyId,
          'signature': signature,
          'payload': payload,
        },
      );

      if (response.data == null) {
        throw Exception('광고 보상 검증에 실패했습니다');
      }

      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      throw Exception('광고 보상 검증 실패: $e');
    }
  }

  /// 룸 정보 조회
  static Future<Map<String, dynamic>?> getRoomInfo(String roomCode) async {
    try {
      final response = await _client
          .from('rooms')
          .select('*, players(*)')
          .eq('code', roomCode)
          .single();

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      throw Exception('룸 정보 조회 실패: $e');
    }
  }

  /// 팔레트 목록 조회
  static Future<List<Map<String, dynamic>>> getPalettes() async {
    try {
      final response = await _client
          .from('palettes')
          .select('*')
          .order('price_coins');

      return (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (e) {
      throw Exception('팔레트 목록 조회 실패: $e');
    }
  }

  /// 사용자 팔레트 조회
  static Future<List<Map<String, dynamic>>> getUserPalettes() async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) throw Exception('로그인이 필요합니다');

      final response = await _client
          .from('user_palettes')
          .select('*, palettes(*)')
          .eq('user_id', uid);

      return (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (e) {
      throw Exception('사용자 팔레트 조회 실패: $e');
    }
  }
}



