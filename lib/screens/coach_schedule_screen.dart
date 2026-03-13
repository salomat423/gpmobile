import 'package:flutter/material.dart';

import '../core/di/app_scope.dart';
import '../theme/app_theme.dart';

class CoachScheduleScreen extends StatefulWidget {
  const CoachScheduleScreen({
    super.key,
    required this.userName,
  });

  final String userName;

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hour = DateTime.now().hour;
    final greeting = hour >= 5 && hour < 12
        ? 'Доброе утро'
        : hour >= 12 && hour < 18
            ? 'Добрый день'
            : hour >= 18 && hour < 23
                ? 'Добрый вечер'
                : 'Доброй ночи';
    final name = widget.userName.isNotEmpty ? widget.userName : 'тренер';

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting,',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$name!',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ниже — ваше расписание и занятия.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.primaryColor),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '${_formatDate(_range.start)} – ${_formatDate(_range.end)}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Выбрать период',
                        onPressed: _pickRange,
                        icon: const Icon(Icons.date_range_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
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
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
            ),
          ],
        ),
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
        .map((p) => {'id': (p['id'] as num?)?.toInt(), 'name': (p['name'] ?? '').toString()})
        .where((p) => p['id'] != null)
        .toList();

    if (parsed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет игроков для создания матча')),
      );
      return;
    }

    final courtId = (booking['court'] as num?)?.toInt();
    final lobbyId = (booking['lobby_id'] as num?)?.toInt();

    final mid = (parsed.length / 2).ceil();
    final teamAIds = parsed.sublist(0, mid).map((p) => p['id'] as int).toList();
    final teamBIds = parsed.sublist(mid).map((p) => p['id'] as int).toList();
    final teamANames = parsed.sublist(0, mid).map((p) => p['name'] as String).toList();
    final teamBNames = parsed.sublist(mid).map((p) => p['name'] as String).toList();

    final sets = List.generate(3, (_) => [TextEditingController(), TextEditingController()]);
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          int setsWonA = 0, setsWonB = 0;
          for (final pair in sets) {
            final a = int.tryParse(pair[0].text);
            final b = int.tryParse(pair[1].text);
            if (a != null && b != null && (a > 0 || b > 0)) {
              if (a > b) setsWonA++;
              else if (b > a) setsWonB++;
            }
          }
          final hasWinner = setsWonA >= 2 || setsWonB >= 2;

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              decoration: BoxDecoration(
                color: Theme.of(ctx).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    )),
                    const Text('Записать результат матча', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                    const SizedBox(height: 16),

                    Row(children: [
                      Expanded(child: _teamColumn('Команда A', teamANames, AppTheme.primaryColor)),
                      const SizedBox(width: 12),
                      const Text('VS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.grey)),
                      const SizedBox(width: 12),
                      Expanded(child: _teamColumn('Команда B', teamBNames, Colors.orange)),
                    ]),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        const SizedBox(width: 60),
                        Expanded(child: Center(child: Text('A', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor.withValues(alpha: 0.7))))),
                        const SizedBox(width: 40),
                        Expanded(child: Center(child: Text('B', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.withValues(alpha: 0.7))))),
                      ],
                    ),
                    const SizedBox(height: 8),

                    ...List.generate(3, (i) {
                      final isOptional = i == 2;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 60,
                              child: Text(
                                'Сет ${i + 1}',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isOptional ? Colors.grey : null),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: sets[i][0],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                onChanged: (_) => setSheet(() {}),
                                decoration: InputDecoration(
                                  hintText: '0',
                                  filled: true,
                                  fillColor: AppTheme.primaryColor.withValues(alpha: 0.06),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
                            ),
                            Expanded(
                              child: TextField(
                                controller: sets[i][1],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                onChanged: (_) => setSheet(() {}),
                                decoration: InputDecoration(
                                  hintText: '0',
                                  filled: true,
                                  fillColor: Colors.orange.withValues(alpha: 0.06),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    if (setsWonA > 0 || setsWonB > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(top: 4, bottom: 12),
                        decoration: BoxDecoration(
                          color: hasWinner ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: hasWinner ? Border.all(color: Colors.green.withValues(alpha: 0.3)) : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (hasWinner) ...[
                              const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 22),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              hasWinner
                                  ? 'Победитель: Команда ${setsWonA > setsWonB ? 'A' : 'B'} ($setsWonA:$setsWonB)'
                                  : 'Счёт по сетам: $setsWonA:$setsWonB',
                              style: TextStyle(fontWeight: FontWeight.w700, color: hasWinner ? Colors.green : Colors.grey),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: (hasWinner && !submitting)
                            ? () async {
                                setSheet(() => submitting = true);

                                final scoreParts = <String>[];
                                for (final pair in sets) {
                                  final a = pair[0].text.trim();
                                  final b = pair[1].text.trim();
                                  if (a.isNotEmpty && b.isNotEmpty && (a != '0' || b != '0')) {
                                    scoreParts.add('$a-$b');
                                  }
                                }
                                final score = scoreParts.join(', ');
                                final winnerTeam = setsWonA > setsWonB ? 'A' : 'B';

                                final messenger = ScaffoldMessenger.of(context);
                                final nav = Navigator.of(ctx);

                                try {
                                  await AppScope.instance.socialRepository.createMatch(
                                    teamA: teamAIds,
                                    teamB: teamBIds,
                                    score: score,
                                    winnerTeam: winnerTeam,
                                    court: courtId,
                                  );

                                  if (lobbyId != null) {
                                    try {
                                      await AppScope.instance.socialRepository.closeLobby(lobbyId);
                                    } catch (_) {}
                                  }

                                  nav.pop();
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Матч записан! ELO обновлено.'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  _reload();
                                } catch (e) {
                                  setSheet(() => submitting = false);
                                  messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                                }
                              }
                            : null,
                        icon: submitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.emoji_events_rounded),
                        label: Text(submitting ? 'Сохранение...' : 'Записать результат'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _teamColumn(String title, List<String> names, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
        const SizedBox(height: 6),
        ...names.map((n) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            CircleAvatar(radius: 12, backgroundColor: color.withValues(alpha: 0.2),
              child: Text(n.isNotEmpty ? n[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color))),
            const SizedBox(width: 6),
            Expanded(child: Text(n, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
          ]),
        )),
      ]),
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
