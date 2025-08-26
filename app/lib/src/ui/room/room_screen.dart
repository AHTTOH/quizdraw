import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../api/quizdraw_api.dart';
import '../../core/kakao_share_service.dart';
import 'draw_modal.dart';
import 'guess_modal.dart';
import 'result_modal.dart';

class RoomScreen extends StatefulWidget {
  final String roomCode;

  const RoomScreen({super.key, required this.roomCode});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  Map<String, dynamic>? _roomInfo;
  List<Map<String, dynamic>> _players = [];
  bool _isLoading = true;
  bool _isStarting = false;
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    _loadRoomInfo();
  }

  Future<String?> _promptAnswer() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('정답 입력'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '정답(한 단어) 입력'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('확인')),
        ],
      ),
    );
    return result;
  }

  Future<void> _loadRoomInfo() async {
    try {
      setState(() => _isLoading = true);
      final roomInfo = await QuizDrawAPI.getRoomInfo(widget.roomCode);
      if (mounted) {
        setState(() {
          _roomInfo = roomInfo;
          _players = List<Map<String, dynamic>>.from(
            roomInfo?['quizdraw_players'] ?? [],
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('룸 정보 로드 실패: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _startRound() async {
    if (_isStarting) return;
    
    setState(() => _isStarting = true);
    
    try {
      // 1) 먼저 DrawModal로 그림을 그리고 업로드 경로를 확보
      final drawResult = await _showDrawModalForPrepare();
      if (drawResult == null || drawResult['storage_path'] == null) {
        throw Exception('그림 업로드가 필요합니다');
      }

      // 2) 정답 입력 받기(간단 입력 다이얼로그)
      final answer = await _promptAnswer();
      if (!mounted) return;
      if (answer == null || answer.trim().isEmpty) {
        throw Exception('정답이 필요합니다');
      }

      final result = await QuizDrawAPI.startRound(
        roomCode: widget.roomCode,
        answer: answer.trim(),
        drawingStoragePath: drawResult['storage_path'] as String,
        drawingWidth: (drawResult['width'] as int?) ?? 360,
        drawingHeight: (drawResult['height'] as int?) ?? 360,
      );
      if (result != null && mounted) {
        // 라운드 시작 후 Guess 모달로 전환
        await _showGuessModal();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('라운드 시작 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _showDrawModalForPrepare() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DrawModal(),
    );
    return result;
  }

  Future<void> _showGuessModal() async {
    // 최신 라운드 정보와 그림 URL 가져오기
    String? imageUrl;
    String? roundId;
    
    try {
      final roomInfo = await QuizDrawAPI.getRoomInfo(widget.roomCode);
      // 실제로는 현재 진행중인 라운드의 그림 URL을 가져와야 함
      // 여기서는 임시로 처리
      roundId = 'temp-round-id';
      imageUrl = roomInfo?['current_drawing_url'];
    } catch (e) {
      debugPrint('라운드 정보 가져오기 실패: $e');
    }

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GuessModal(
        imageUrl: imageUrl,
        roundId: roundId ?? 'temp-round-id',
      ),
    );

    if (result != null && mounted) {
      // 정답 제출 후 결과 모달 열기
      await _showResultModal(result);
    }
  }

  Future<void> _showResultModal(Map<String, dynamic> result) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ResultModal(result: result),
    );
  }

  Future<void> _shareRoom() async {
    try {
      final isAvailable = await KakaoShareService.isKakaoTalkSharingAvailable();
      
      if (!isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('카카오톡이 설치되지 않았습니다')),
          );
        }
        return;
      }

      await KakaoShareService.shareRoomInvite(
        roomCode: widget.roomCode,
        roomId: _roomInfo?['id'] ?? '',
        creatorName: _players.firstWhere(
          (p) => p['user_id'] == _roomInfo?['created_by'],
          orElse: () => {'nickname': '플레이어'},
        )['nickname'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카카오톡으로 초대장을 보냈습니다!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('공유 실패: $e')),
        );
      }
    }
  }

  Future<void> _leaveRoom() async {
    if (_isLeaving) return;
    
    setState(() => _isLeaving = true);
    
    try {
      // TODO: 방 나가기 API 호출
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('방 나가기 실패: $e')),
        );
        setState(() => _isLeaving = false);
      }
    }
  }

  bool get _isCreator {
    final currentUserId = context.read<AppState>().userId;
    return _roomInfo?['created_by'] == currentUserId;
  }

  String get _roomStatus {
    return _roomInfo?['status'] ?? 'waiting';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('방 코드: ${widget.roomCode}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // 카카오 공유 버튼
          IconButton(
            onPressed: _shareRoom,
            icon: const Icon(Icons.share),
            tooltip: '친구 초대하기',
          ),
          IconButton(
            onPressed: _isLeaving ? null : _leaveRoom,
            icon: _isLeaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.exit_to_app),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 룸 상태 표시
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getStatusColor()),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getStatusIcon(),
                          color: _getStatusColor(),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getStatusText(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 플레이어 목록
                  const Text(
                    '플레이어 목록',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Expanded(
                    child: _players.isEmpty
                        ? const Center(
                            child: Text(
                              '아직 플레이어가 없습니다',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _players.length,
                            itemBuilder: (context, index) {
                              final player = _players[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue,
                                    child: Text(
                                      player['nickname']?[0] ?? '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(player['nickname'] ?? '알 수 없음'),
                                  subtitle: Text('점수: ${player['score'] ?? 0}'),
                                  trailing: player['user_id'] == _roomInfo?['created_by']
                                      ? const Chip(
                                          label: Text('방장'),
                                          backgroundColor: Colors.orange,
                                          labelStyle: TextStyle(color: Colors.white),
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 시작 버튼 (방장만)
                  if (_isCreator && _roomStatus == 'waiting')
                    ElevatedButton(
                      onPressed: _isStarting ? null : _startRound,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isStarting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              '게임 시작',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  
                  // 대기 메시지 (방장이 아닌 경우)
                  if (!_isCreator && _roomStatus == 'waiting')
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '방장이 게임을 시작할 때까지 기다려주세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Color _getStatusColor() {
    switch (_roomStatus) {
      case 'waiting':
        return Colors.blue;
      case 'playing':
        return Colors.green;
      case 'ended':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (_roomStatus) {
      case 'waiting':
        return Icons.people;
      case 'playing':
        return Icons.play_circle;
      case 'ended':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  String _getStatusText() {
    switch (_roomStatus) {
      case 'waiting':
        return '대기 중';
      case 'playing':
        return '게임 진행 중';
      case 'ended':
        return '게임 종료';
      default:
        return '알 수 없음';
    }
  }
}



