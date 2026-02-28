// lib/screens/sportbar.dart
import 'package:flutter/material.dart';
import '../core/di/app_scope.dart';

class SportBarScreen extends StatefulWidget {
  const SportBarScreen({super.key});

  @override
  State<SportBarScreen> createState() => _SportBarScreenState();
}

class _SportBarScreenState extends State<SportBarScreen> {
  late Future<List<dynamic>> _future;

  Future<List<dynamic>> fetchProducts() async {
    return AppScope.instance.secondaryRepository.services();
  }

  void _reload() {
    setState(() {
      _future = fetchProducts();
    });
  }

  @override
  void initState() {
    super.initState();
    _future = fetchProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Спорт-бар'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            final err = snap.error.toString();
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 42),
                    const SizedBox(height: 10),
                    const Text(
                      'Товары временно недоступны',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      err,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: _reload,
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }

          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'Нет товаров',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final raw = items[i];

              // На всякий: если API вернул не Map
              if (raw is! Map) {
                return ListTile(
                  leading: const Icon(Icons.fastfood),
                  title: Text('Товар #$i'),
                  subtitle: const Text('Неверный формат данных'),
                );
              }

              final p = Map<String, dynamic>.from(raw);

              final name = (p['name'] ?? 'Товар').toString();
              final price = (p['price'] ?? '-').toString();
              final imageUrl = p['image_url']?.toString();

              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: (imageUrl != null && imageUrl.isNotEmpty)
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      imageUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 56,
                        height: 56,
                        child: Icon(Icons.fastfood),
                      ),
                    ),
                  )
                      : const SizedBox(width: 56, height: 56, child: Icon(Icons.fastfood)),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('$price ₸'),
                  trailing: ElevatedButton(
                    onPressed: () {
                      // TODO: корзина/заказ
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Добавлено в корзину: $name')),
                      );
                    },
                    child: const Text('В корзину'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}