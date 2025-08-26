import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                  // 닉네임 설정
                  ListTile(
                    title: const Text('닉네임'),
                    subtitle: const Text('게임에서 사용할 이름을 설정합니다'),
                    leading: const Icon(Icons.person),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // TODO: 닉네임 변경 다이얼로그 구현
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('닉네임 변경 기능은 준비 중입니다')),
                      );
                    },
                  ),
                  
                  const Divider(),
                  
                  // 기본 팔레트 설정
                  ListTile(
                    title: const Text('기본 팔레트'),
                    subtitle: const Text('게임 시작 시 사용할 기본 색상 팔레트'),
                    leading: const Icon(Icons.palette),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // TODO: 기본 팔레트 선택 다이얼로그 구현
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('기본 팔레트 설정 기능은 준비 중입니다')),
                      );
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
            onPressed: () {
              // TODO: 실제 캐시 삭제 구현
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('캐시가 삭제되었습니다')),
              );
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
            onPressed: () {
              // TODO: 실제 데이터 초기화 구현
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('데이터가 초기화되었습니다')),
              );
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
            onPressed: () {
              // TODO: 실제 로그아웃 구현
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('로그아웃되었습니다')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
}



