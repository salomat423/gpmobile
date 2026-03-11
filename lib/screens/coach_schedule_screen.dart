import 'package:flutter/material.dart';

import '../core/di/app_scope.dart';
import '../theme/app_theme.dart';

class CoachScheduleScreen extends StatefulWidget {
  const CoachScheduleScreen({super.key});

  @override
  State<CoachScheduleScreen> createState() => _CoachScheduleScreenState();
}

class _CoachScheduleScreenState extends State<CoachScheduleScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now().add(const Duration(days: 14)),
  );

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    final from = _iso(_range.start);
    final to = _iso(_range.end);
    return AppScope.instance.bookingRepository.coachSchedule(from: from, to: to);
  }

  void _reload() => setState(() => _future = _load());

  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      initialDateRange: _range,
      locale: const Locale('ru'),
    );
    if (picked != null) {
      _range = picked;
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Моё расписание'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_rounded),
            tooltip: 'Выбрать период',
            onPressed: _pickRange,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(snap.error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _reload, child: const Text('Повторить')),
              ]),
            );
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                const Text('Нет занятий в этом периоде', style: TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 8),
                Text(
                  '${_formatDate(_range.start)} – ${_formatDate(_range.end)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ]),
            );
          }

          final grouped = _groupByDate(items);
          final dates = grouped.keys.toList()..sort();

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: dates.length,
              itemBuilder: (context, i) {
                final date = dates[i];
                final bookings = grouped[date]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (i > 0) const SizedBox(height: 20),
                    _dateHeader(date, isDark),
                    const SizedBox(height: 8),
                    ...bookings.map((b) => _bookingTile(b, isDark)),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupByDate(List<Map<String, dynamic>> items) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final b in items) {
      final raw = (b['start_time'] ?? '').toString();
      final dt = DateTime.tryParse(raw)?.toLocal();
      final key = dt != null ? _iso(dt) : 'Без даты';
      map.putIfAbsent(key, () => []).add(b);
    }
    return map;
  }

  Widget _dateHeader(String dateIso, bool isDark) {
    final dt = DateTime.tryParse(dateIso);
    final label = dt != null ? _formatDate(dt) : dateIso;
    final isToday = dt != null && _iso(dt) == _iso(DateTime.now());

    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isToday
              ? AppTheme.primaryColor.withValues(alpha: 0.15)
              : (isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          isToday ? 'Сегодня, $label' : label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: isToday ? AppTheme.primaryColor : null,
          ),
        ),
      ),
    ]);
  }

  Widget _bookingTile(Map<String, dynamic> b, bool isDark) {
    final courtName = (b['court_name'] ?? b['court'] ?? 'Корт').toString();
    final clientName = (b['client_name'] ?? '').toString();
    final status = (b['status'] ?? '').toString().toUpperCase();
    final startRaw = (b['start_time'] ?? '').toString();
    final endRaw = (b['end_time'] ?? '').toString();
    final participants = (b['participants_names'] as List?)?.cast<String>() ?? [];
    final playersForMatch = (b['players_for_match'] as List?) ?? [];
    final isPaid = b['is_paid'] == true;
    final price = (b['price'] ?? b['total_cost'] ?? '').toString();

    final startDt = DateTime.tryParse(startRaw)?.toLocal();
    final endDt = DateTime.tryParse(endRaw)?.toLocal();
    final timeLabel = startDt != null
        ? '${_hm(startDt)}${endDt != null ? ' – ${_hm(endDt)}' : ''}'
        : startRaw;

    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.access_time_rounded, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 6),
          Text(timeLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusLabel(status),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.sports_tennis_rounded, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          Text(courtName, style: const TextStyle(fontSize: 14)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.person_rounded, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              clientName.isNotEmpty ? clientName : 'Клиент не указан',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ]),
        if (participants.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.group_rounded, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                participants.join(', '),
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          ]),
        ],
        const SizedBox(height: 8),
        Row(children: [
          if (price.isNotEmpty && price != '0' && price != '0.00') ...[
            Icon(Icons.payments_outlined, size: 16, color: isPaid ? Colors.green : Colors.orange),
            const SizedBox(width: 4),
            Text(
              '$price тг',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isPaid ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              isPaid ? '(оплачено)' : '(не оплачено)',
              style: TextStyle(fontSize: 12, color: isPaid ? Colors.green : Colors.orange),
            ),
          ],
          const Spacer(),
          if (playersForMatch.isNotEmpty)
            TextButton.icon(
              onPressed: () => _showPlayersForMatch(playersForMatch, b),
              icon: const Icon(Icons.scoreboard_outlined, size: 16),
              label: const Text('Матч', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ]),
      ]),
    );
  }

  void _showPlayersForMatch(List players, Map<String, dynamic> booking) {
    final parsed = players
        .whereType<Map>()
        .map((p) => {'id': p['id'], 'name': (p['name'] ?? '').toString()})
        .toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Игроки для матча', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 16),
          ...parsed.map((p) => ListTile(
                leading: CircleAvatar(child: Text((p['name'] as String).isNotEmpty ? (p['name'] as String)[0] : '?')),
                title: Text(p['name'] as String),
                subtitle: Text('ID: ${p['id']}'),
              )),
          const SizedBox(height: 12),
          const Text(
            'Используйте этих игроков при создании матча на вкладке "Матчи"',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  String _hm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _formatDate(DateTime d) {
    const months = [
      '', 'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'CONFIRMED':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'CANCELED':
        return Colors.red;
      case 'COMPLETED':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'CONFIRMED':
        return 'Подтверждено';
      case 'PENDING':
        return 'Ожидание';
      case 'CANCELED':
        return 'Отменено';
      case 'COMPLETED':
        return 'Завершено';
      default:
        return s;
    }
  }
}
