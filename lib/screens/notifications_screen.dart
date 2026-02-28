import 'package:flutter/material.dart';

import '../core/di/app_scope.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = AppScope.instance.socialRepository.notifications();
  }

  Future<void> _reload() async {
    setState(() {
      _future = AppScope.instance.socialRepository.notifications();
    });
    await _future;
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
            appBar: AppBar(title: const Text('Уведомления')),
            body: Center(child: Text(snapshot.error.toString())),
          );
        }
        final list = snapshot.data ?? const [];
        return Scaffold(
          appBar: AppBar(
            title: const Text('Уведомления'),
            actions: [
              TextButton(
                onPressed: () async {
                  await AppScope.instance.socialRepository.markAllRead();
                  if (!mounted) return;
                  _reload();
                },
                child: const Text('Прочитать все'),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, i) {
                final n = list[i];
                final id = (n['id'] as num?)?.toInt();
                return ListTile(
                  title: Text((n['title'] ?? '').toString()),
                  subtitle: Text((n['body'] ?? '').toString()),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (id != null)
                        IconButton(
                          icon: const Icon(Icons.done),
                          onPressed: () async {
                            await AppScope.instance.socialRepository.markRead(id);
                            if (!mounted) return;
                            _reload();
                          },
                        ),
                      if (id != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await AppScope.instance.socialRepository.deleteNotification(id);
                            if (!mounted) return;
                            _reload();
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
