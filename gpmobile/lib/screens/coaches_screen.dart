import 'package:flutter/material.dart';

import '../core/di/app_scope.dart';
import '../core/config/app_config.dart';
import '../theme/app_theme.dart';

class CoachesScreen extends StatefulWidget {
  const CoachesScreen({super.key});

  @override
  State<CoachesScreen> createState() => _CoachesScreenState();
}

class _CoachesScreenState extends State<CoachesScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _loadCoaches();
  }

  void _loadCoaches() {
    _future = AppScope.instance.authRepository.coaches();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Тренеры')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Ошибка загрузки', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(snapshot.error.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => setState(_loadCoaches),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }
          final coaches = snapshot.data ?? const [];
          if (coaches.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_search, size: 56, color: Colors.grey.withValues(alpha: 0.4)),
                  const SizedBox(height: 8),
                  const Text('Тренеры не найдены', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(_loadCoaches),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: coaches.length,
              itemBuilder: (context, i) => _buildCoachCard(coaches[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCoachCard(Map<String, dynamic> c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = (c['full_name'] ?? '').toString();
    final specialization = (c['specialization'] ?? 'Индивидуальные занятия').toString();
    final price = (c['coach_price'] ?? '-').toString();
    final rating = (c['rating'] as num?)?.toDouble() ?? 4.5;
    final avatarUrl = (c['avatar'] ?? 'https://i.pravatar.cc/150?img=12').toString();
    final resolvedAvatar = avatarUrl.startsWith('http') ? avatarUrl : '${AppConfig.baseUrl}$avatarUrl';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200],
              backgroundImage: NetworkImage(resolvedAvatar),
              onBackgroundImageError: (_, __) {},
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    specialization,
                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ...List.generate(5, (i) {
                        if (i < rating.floor()) {
                          return const Icon(Icons.star_rounded, size: 18, color: Colors.amber);
                        } else if (i < rating) {
                          return const Icon(Icons.star_half_rounded, size: 18, color: Colors.amber);
                        }
                        return Icon(Icons.star_outline_rounded, size: 18, color: Colors.grey[400]);
                      }),
                      const SizedBox(width: 6),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$price тг/занятие',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () {
                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(context);
                            if (navigator.canPop()) {
                              navigator.pop();
                            }
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Выберите корт и время для бронирования с тренером'),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Записаться', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
