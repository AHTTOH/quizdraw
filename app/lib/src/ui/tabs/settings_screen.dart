import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/rendering.dart';
import '../../state/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        backgroundColor: Colors.grey.shade800,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 접근성 섹션
              _buildSection(
                title: '접근성',
                icon: Icons.accessibility,
                children: [
                  // 고대비 모드
                  SwitchListTile(
                    title: const Text('고대비 모드'),
                    subtitle: const Text('텍스트와 배경의 대비를 높여 가독성을 개선합니다'),
                    value: appState.isHighContrast,
                    onChanged: (value) => appState.updateAccessibilitySettings(isHighContrast: value),
                    secondary: const Icon(Icons.contrast),
                  ),
                  
                  const Divider(),
                  
                  // 큰 텍스트 모드
                  SwitchListTile(
                    title: const Text('큰 텍스트'),
                    subtitle: const Text('텍스트 크기를 키워 가독성을 개선합니다'),
                    value: appState.isLargeText,
                    onChanged: (value) => appState.updateAccessibilitySettings(isLargeText: value),
                    secondary: const Icon(Icons.text_fields),
                  ),
                  
                  const Divider(),
                  
                  // 색맹 친화적 모드
                  SwitchListTile(
                    title: const Text('색맹 친화적'),
                    subtitle: const Text('색맹 사용자를 위한 색상 팔레트를 사용합니다'),
                    value: appState.isColorBlindFriendly,
                    onChanged: (value) => appState.updateAccessibilitySettings(isColorBlindFriendly: value),
                    secondary: const Icon(Icons.visibility),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // 계정 정보 섹션
              _buildSection(
                title: '계정 정보',
                icon: Icons.person,
                children: [
                  // 사용자 ID
                  ListTile(
                    title: const Text('사용자 ID'),
                    subtitle: Text(appState.userId ?? '로그인되지 않음'),
                    leading: const Icon(Icons.badge),
                  ),
                  
                  const Divider(),
                  
                  // 닉네임 설정
                  ListTile(
                    title: const Text('닉네임'),
                    subtitle: Text(appState.userNickname ?? '설정되지 않음'),
                    leading: const Icon(Icons.person),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _showNicknameDialog(context, appState);
                    },
                  ),
                  
                  const Divider(),
                  
                  // 코인 잔액
                  ListTile(
                    title: const Text('코인 잔액'),
                    subtitle: Text('${appState.coinBalance} 코인'),
                    leading: const Icon(Icons.monetization_on, color: Colors.amber),
                    trailing: IconButton(
                      onPressed: () => appState.refreshBalance(),
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // 게임 설정 섹션
              _buildSection(
                title: '게임 설정',
                icon: Icons.games,
                children: [
                  // 기본 팔레트 설정
                  ListTile(
                    title: const Text('기본 팔레트'),
                    subtitle: const Text('게임 시작 시 사용할 기본 색상 팔레트'),
                    leading: const Icon(Icons.palette),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _showPaletteDialog(context);
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // 정보 섹션
              _buildSection(
                title: '정보',
                icon: Icons.info,
                children: [
                  // 앱 버전
                  ListTile(
                    title: const Text('앱 버전'),
                    subtitle: const Text('1.0.0'),
                    leading: const Icon(Icons.app_settings_alt),
                  ),
                  
                  const Divider(),
                  
                  // 개발자 정보
                  ListTile(
                    title: const Text('개발자'),
                    subtitle: const Text('QuizDraw Team'),
                    leading: const Icon(Icons.developer_mode),
                  ),
                  
                  const Divider(),
                  
                  // 라이선스
                  ListTile(
                    title: const Text('라이선스'),
                    subtitle: const Text('MIT License'),
                    leading: const Icon(Icons.description),
                    onTap: () {
                      showLicensePage(context: context);
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // 데이터 관리 섹션
              _buildSection(
                title: '데이터 관리',
                icon: Icons.storage,
                children: [
                  // 캐시 삭제
                  ListTile(
                    title: const Text('캐시 삭제'),
                    subtitle: const Text('저장된 임시 데이터를 삭제합니다'),
                    leading: const Icon(Icons.cleaning_services),
                    onTap: () {
                      _showClearCacheDialog(context);
                    },
                  ),
                  
                  const Divider(),
                  
                  // 데이터 초기화
                  ListTile(
                    title: const Text('데이터 초기화'),
                    subtitle: const Text('모든 설정과 데이터를 초기화합니다'),
                    leading: const Icon(Icons.restore),
                    onTap: () {
                      _showResetDataDialog(context);
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // 로그아웃 버튼
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    _showLogoutDialog(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '로그아웃',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(children: children),
        ),
      ],
    );
  }

  void _showNicknameDialog(BuildContext context, AppState appState) {
    final TextEditingController _nicknameController = TextEditingController(text: appState.userNickname);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('닉네임 변경'),
        content: TextField(
          controller: _nicknameController,
          decoration: const InputDecoration(
            hintText: '닉네임을 입력하세요',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final newNickname = _nicknameController.text.trim();
              if (newNickname.isNotEmpty) {
                try {
                  await appState.updateNickname(newNickname);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('닉네임이 "$newNickname"으로 변경되었습니다')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('닉네임 변경 실패: $e')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('닉네임을 입력해주세요')),
                );
              }
            },
            child: const Text('변경'),
          ),
        ],
      ),
    );
  }

  void _showPaletteDialog(BuildContext context) {
    final List<Map<String, dynamic>> palettes = [
      {'name': '기본 팔레트', 'colors': ['#FF0000', '#00FF00', '#0000FF', '#FFFF00', '#FF00FF', '#00FFFF']},
      {'name': '파스텔 팔레트', 'colors': ['#FFB3BA', '#BAFFC9', '#BAE1FF', '#FFFFBA', '#FFB3F7', '#B3F7FF']},
      {'name': '어두운 팔레트', 'colors': ['#8B0000', '#006400', '#00008B', '#B8860B', '#8B008B', '#008B8B']},
      {'name': '밝은 팔레트', 'colors': ['#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7', '#DDA0DD']},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기본 팔레트 설정'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: palettes.length,
            itemBuilder: (context, index) {
              final palette = palettes[index];
              return ListTile(
                title: Text(palette['name']),
                subtitle: Row(
                  children: (palette['colors'] as List<String>).take(6).map((color) {
                    return Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: Color(int.parse(color.replaceAll('#', '0xFF'))),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                    );
                  }).toList(),
                ),
                onTap: () async {
                  try {
                    // SharedPreferences에 기본 팔레트 저장
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('default_palette', palette['name']);
                    
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('기본 팔레트가 "${palette['name']}"으로 설정되었습니다')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('팔레트 설정 실패: $e')),
                    );
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('캐시 삭제'),
        content: const Text('저장된 임시 데이터를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // SharedPreferences 캐시 삭제
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                
                // 이미지 캐시 삭제 (Flutter 기본 캐시)
                await ImageCache().clear();
                await ImageCache().clearLiveImages();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('캐시가 삭제되었습니다')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('캐시 삭제 실패: $e')),
                );
              }
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showResetDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('데이터 초기화'),
        content: const Text('모든 설정과 데이터가 초기화됩니다. 이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // SharedPreferences 초기화
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                
                // 앱 상태 초기화
                final appState = context.read<AppState>();
                appState.updateAccessibilitySettings(
                  isHighContrast: false,
                  isLargeText: false,
                  isColorBlindFriendly: false,
                );
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('데이터가 초기화되었습니다')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('데이터 초기화 실패: $e')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await Supabase.instance.client.auth.signOut();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('로그아웃되었습니다')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('로그아웃 실패: $e')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
}



