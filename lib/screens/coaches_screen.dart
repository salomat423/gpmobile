import 'package:flutter/material.dart';

import '../core/di/app_scope.dart';

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
    _future = AppScope.instance.authRepository.coaches();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Тренеры')),
            body: Center(child: Text(snapshot.error.toString())),
          );
        }
        final coaches = snapshot.data ?? const [];
        return Scaffold(
          appBar: AppBar(title: const Text('Тренеры')),
          body: ListView.builder(
            itemCount: coaches.length,
            itemBuilder: (context, i) {
              final c = coaches[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(
                    (c['avatar'] ?? 'https://i.pravatar.cc/150?img=12').toString(),
                  ),
                ),
                title: Text((c['full_name'] ?? '').toString()),
                subtitle: Text('Цена: ${c['coach_price'] ?? '-'}'),
              );
            },
          ),
        );
      },
    );
  }
}
