import 'package:flutter/material.dart';
import '../core/di/app_scope.dart';
import '../core/config/app_config.dart';
import '../theme/app_theme.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<List<Map<String, dynamic>>> _spaFuture;
  late Future<List<Map<String, dynamic>>> _massageFuture;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _reload() {
    _spaFuture = AppScope.instance.secondaryRepository
        .services(group: 'RECOVERY', category: 'SPA')
        .catchError((_) => <Map<String, dynamic>>[]);
    _massageFuture = AppScope.instance.secondaryRepository
        .services(group: 'RECOVERY', category: 'MASSAGE')
        .catchError((_) => <Map<String, dynamic>>[]);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppTheme.accentColor : AppTheme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Восстановление'),
        actions: [
          IconButton(tooltip: 'Обновить', onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: activeColor,
          indicatorColor: activeColor,
          tabs: const [
            Tab(icon: Icon(Icons.spa_rounded), text: 'СПА'),
            Tab(icon: Icon(Icons.back_hand_rounded), text: 'Массаж'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildTab(_spaFuture, isDark, Icons.spa_rounded),
          _buildTab(_massageFuture, isDark, Icons.back_hand_rounded),
        ],
      ),
    );
  }

  Widget _buildTab(Future<List<Map<String, dynamic>>> future, bool isDark, IconData fallback) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.wifi_off_rounded, size: 42),
              const SizedBox(height: 10),
              const Text('Не удалось загрузить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              ElevatedButton(onPressed: _reload, child: const Text('Повторить')),
            ]),
          );
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return _emptyState(isDark, fallback);
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.78,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) => _card(items[i], isDark, fallback),
          ),
        );
      },
    );
  }

  Widget _emptyState(bool isDark, IconData icon) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 56, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Text('Скоро здесь появятся процедуры', style: TextStyle(fontSize: 15, color: Colors.grey[500])),
      ]),
    );
  }

  Widget _card(Map<String, dynamic> p, bool isDark, IconData fallback) {
    final name = (p['name'] ?? 'Процедура').toString();
    final price = (p['price'] ?? '-').toString();
    final imageUrl = p['image']?.toString() ?? p['image_url']?.toString();
    final desc = (p['description'] ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: SizedBox(
              width: double.infinity,
              child: (imageUrl != null && imageUrl.isNotEmpty)
                  ? Image.network(
                      imageUrl.startsWith('http') ? imageUrl : '${AppConfig.baseUrl}$imageUrl',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(isDark, fallback),
                    )
                  : _placeholder(isDark, fallback),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (desc.isNotEmpty)
                    Text(desc, style: TextStyle(color: Colors.grey[500], fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('$price тг', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primaryColor)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(bool isDark, IconData icon) {
    return Container(
      color: isDark ? Colors.grey[800] : Colors.grey[200],
      child: Center(child: Icon(icon, size: 40, color: isDark ? Colors.white38 : Colors.grey[400])),
    );
  }
}
