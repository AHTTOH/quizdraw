import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../api/quizdraw_api.dart';

class PaletteScreen extends StatefulWidget {
  const PaletteScreen({super.key});

  @override
  State<PaletteScreen> createState() => _PaletteScreenState();
}

class _PaletteScreenState extends State<PaletteScreen> {
  List<Map<String, dynamic>> _palettes = [];
  List<Map<String, dynamic>> _userPalettes = [];
  bool _isLoading = true;
  bool _isUnlocking = false;

  @override
  void initState() {
    super.initState();
    _loadPalettes();
  }

  Future<void> _loadPalettes() async {
    try {
      setState(() => _isLoading = true);
      
      final palettes = await QuizDrawAPI.getPalettes();
      final userPalettes = await QuizDrawAPI.getUserPalettes();
      
      if (mounted) {
        setState(() {
          _palettes = palettes;
          _userPalettes = userPalettes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('팔레트 로드 실패: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _unlockPalette(String paletteId) async {
    if (_isUnlocking) return;
    
    setState(() => _isUnlocking = true);
    
    try {
      final result = await QuizDrawAPI.unlockPalette(paletteId);
      if (result != null && mounted) {
        // 코인 잔액 새로고침
        await context.read<AppState>().refreshBalance();
        
        // 팔레트 목록 새로고침
        await _loadPalettes();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('팔레트가 해금되었습니다!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('팔레트 해금 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUnlocking = false);
      }
    }
  }

  bool _isPaletteUnlocked(String paletteId) {
    return _userPalettes.any((up) => up['palette_id'] == paletteId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('색상 팔레트'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadPalettes,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 코인 잔액 표시
                Consumer<AppState>(
                  builder: (context, appState, child) {
                    return Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.amber.shade300, Colors.amber.shade600],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.monetization_on, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            '${appState.coinBalance} 코인',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                
                // 팔레트 목록
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _palettes.length,
                    itemBuilder: (context, index) {
                      final palette = _palettes[index];
                      final isUnlocked = _isPaletteUnlocked(palette['id']);
                      final price = palette['price_coins'] ?? 0;
                      final isFree = price == 0;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 팔레트 이름과 상태
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      palette['name'],
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (isUnlocked)
                                    const Chip(
                                      label: Text('보유'),
                                      backgroundColor: Colors.green,
                                      labelStyle: TextStyle(color: Colors.white),
                                    )
                                  else if (isFree)
                                    const Chip(
                                      label: Text('무료'),
                                      backgroundColor: Colors.blue,
                                      labelStyle: TextStyle(color: Colors.white),
                                    )
                                  else
                                    Chip(
                                      label: Text('$price 코인'),
                                      backgroundColor: Colors.orange,
                                      labelStyle: const TextStyle(color: Colors.white),
                                    ),
                                ],
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // 색상 스와치들
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: (palette['swatches'] as List<dynamic>?)
                                        ?.map((color) => Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: _parseColor(color),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.grey.shade300,
                                                ),
                                              ),
                                            ))
                                        .toList() ??
                                    [],
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // 해금 버튼
                              if (!isUnlocked)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isUnlocking
                                        ? null
                                        : () => _unlockPalette(palette['id']),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isFree ? Colors.blue : Colors.orange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: _isUnlocking
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : Text(
                                            isFree ? '무료 해금' : '$price 코인으로 해금',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Color _parseColor(dynamic colorValue) {
    if (colorValue is String) {
      // Hex color string (e.g., "#FF0000")
      if (colorValue.startsWith('#')) {
        return Color(int.parse(colorValue.substring(1), radix: 16) + 0xFF000000);
      }
    }
    return Colors.grey; // fallback
  }
}



