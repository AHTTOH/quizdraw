import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _my = [];
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _achievements = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) throw Exception('로그인이 필요합니다');
      final res = await client.functions.invoke('get-gallery', body: {
        'user_id': uid,
        'limit': 50,
      });
      final data = res.data as Map<String, dynamic>;
      _my = List<Map<String, dynamic>>.from(data['my_drawings'] ?? []);
      _friends = List<Map<String, dynamic>>.from(data['friends_drawings'] ?? []);

      // 업적 조회 (읽기 전용)
      final ach = await client
          .from('user_achievements')
          .select('completed, progress, earned_at, achievements!inner(code, name, description, icon, points)')
          .eq('user_id', uid)
          .order('earned_at', { ascending: false });
      _achievements = List<Map<String, dynamic>>.from(ach as List);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('내 그림', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildGrid(_my),
          const SizedBox(height: 24),
          const Text('친구 그림', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildGrid(_friends),
          const SizedBox(height: 24),
          const Text('업적', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildAchievements(_achievements),
        ],
      ),
    );
  }

  Widget _buildGrid(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const Text('표시할 항목이 없습니다', style: TextStyle(color: Colors.grey));
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final path = item['storage_path'] as String?;
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: path == null
              ? const Center(child: Icon(Icons.image_not_supported))
              : Center(child: Text(path.split('/').last, maxLines: 2, textAlign: TextAlign.center)),
        );
      },
    );
  }

  Widget _buildAchievements(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const Text('달성한 업적이 없습니다', style: TextStyle(color: Colors.grey));
    }
    return Column(
      children: items.map((e) {
        final ach = e['achievements'] as Map<String, dynamic>;
        final completed = (e['completed'] as bool?) ?? false;
        final progress = (e['progress'] as int?) ?? 0;
        return ListTile(
          leading: Text(ach['icon']?.toString() ?? '🏅', style: const TextStyle(fontSize: 24)),
          title: Text(ach['name']?.toString() ?? '업적'),
          subtitle: Text(ach['description']?.toString() ?? '업적 설명'),
          trailing: completed
              ? const Icon(Icons.check_circle, color: Colors.green)
              : Text('진행도 ${progress}', style: const TextStyle(color: Colors.grey)),
        );
      }).toList(),
    );
  }
}


