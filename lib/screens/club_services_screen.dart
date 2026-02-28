import 'package:flutter/material.dart';

import '../core/di/app_scope.dart';

class ClubServicesScreen extends StatefulWidget {
  const ClubServicesScreen({super.key});

  @override
  State<ClubServicesScreen> createState() => _ClubServicesScreenState();
}

class _ClubServicesScreenState extends State<ClubServicesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<List<Map<String, dynamic>>> _settingsFuture;
  late Future<List<Map<String, dynamic>>> _closedDaysFuture;
  late Future<List<Map<String, dynamic>>> _financeFuture;
  late Future<List<Map<String, dynamic>>> _trainingFuture;
  final TextEditingController _sessionController = TextEditingController();

  Map<String, dynamic>? _paymentSession;
  String? _paymentError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _sessionController.dispose();
    super.dispose();
  }

  void _reload() {
    _settingsFuture = AppScope.instance.secondaryRepository.clubSettings();
    _closedDaysFuture = AppScope.instance.secondaryRepository.closedDays();
    _financeFuture = AppScope.instance.secondaryRepository.financeHistory();
    _trainingFuture = AppScope.instance.secondaryRepository.personalTraining();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сервисы клуба'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Настройки'),
            Tab(text: 'Выходные'),
            Tab(text: 'Финансы'),
            Tab(text: 'Тренировки'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildList(_settingsFuture, (item) => ListTile(title: Text('${item['key']}'), subtitle: Text('${item['value']}'))),
          _buildList(_closedDaysFuture, (item) => ListTile(title: Text('${item['date']}'), subtitle: Text('${item['reason'] ?? ''}'))),
          _buildFinance(),
          _buildList(
            _trainingFuture,
            (item) => ListTile(title: Text('Тренировка #${item['id'] ?? '-'}'), subtitle: Text(item.toString(), maxLines: 2)),
          ),
        ],
      ),
    );
  }

  Widget _buildFinance() {
    return Column(
      children: [
        Expanded(
          child: _buildList(
            _financeFuture,
            (item) => ListTile(
              title: Text('${item['description'] ?? item['transaction_type'] ?? ''}'),
              subtitle: Text('${item['created_at'] ?? ''}'),
              trailing: Text('${item['amount'] ?? '-'}'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                controller: _sessionController,
                decoration: const InputDecoration(
                  hintText: 'Payment session id',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final sid = _sessionController.text.trim();
                  if (sid.isEmpty) return;
                  try {
                    final status = await AppScope.instance.secondaryRepository.paymentSessionStatus(sid);
                    if (!mounted) return;
                    setState(() {
                      _paymentSession = status;
                      _paymentError = null;
                    });
                  } catch (e) {
                    if (!mounted) return;
                    setState(() {
                      _paymentError = e.toString();
                      _paymentSession = null;
                    });
                  }
                },
                child: const Text('Проверить платежную сессию'),
              ),
              if (_paymentSession != null) Text(_paymentSession.toString(), maxLines: 2),
              if (_paymentError != null) Text(_paymentError!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList(
    Future<List<Map<String, dynamic>>> future,
    Widget Function(Map<String, dynamic>) itemBuilder,
  ) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final list = snapshot.data ?? const [];
        if (list.isEmpty) return const Center(child: Text('Нет данных'));
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) => itemBuilder(list[i]),
          ),
        );
      },
    );
  }
}
