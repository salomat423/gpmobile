import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/di/app_scope.dart';
import '../theme/app_theme.dart';

class LobbyDetailScreen extends StatefulWidget {
  final int lobbyId;

  const LobbyDetailScreen({super.key, required this.lobbyId});

  @override
  State<LobbyDetailScreen> createState() => _LobbyDetailScreenState();
}

class _LobbyDetailScreenState extends State<LobbyDetailScreen> {
  late Future<Map<String, dynamic>> _detailFuture;
  late Future<List<Map<String, dynamic>>> _proposalsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _detailFuture = AppScope.instance.socialRepository.lobbyDetail(widget.lobbyId);
    _proposalsFuture = AppScope.instance.socialRepository.lobbyProposals(widget.lobbyId);
  }

  Future<void> _doAction(Future<dynamic> Function() action, [String? successMsg]) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (!mounted) return;
      if (successMsg != null) messenger.showSnackBar(SnackBar(content: Text(successMsg)));
      setState(_reload);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Лобби')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detailFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snap.error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: () => setState(_reload), child: const Text('Повторить')),
                ],
              ),
            );
          }
          final lobby = snap.data ?? {};
          final title = (lobby['title'] ?? 'Лобби').toString();
          final status = (lobby['status'] ?? '').toString();
          final playersCount = (lobby['players_count'] as num?)?.toInt() ?? 0;
          final maxPlayers = (lobby['max_players'] as num?)?.toInt() ?? 4;
          final format = (lobby['game_format'] ?? '').toString();
          final players = ((lobby['players'] as List?) ?? []).cast<Map<String, dynamic>>();
          final isFull = playersCount >= maxPlayers;

          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _headerCard(context, isDark, title, status, format, playersCount, maxPlayers),
                const SizedBox(height: 16),
                _playersSection(players, isDark),
                const SizedBox(height: 16),
                _actionsSection(status, isFull, lobby),
                const SizedBox(height: 16),
                if (status == 'FULL' || status == 'VOTING') ...[
                  _proposalsSection(isDark, lobby),
                ],
                if (status == 'BOOKED' || status == 'READY') ...[
                  _paymentSection(lobby),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _headerCard(BuildContext context, bool isDark, String title, String status, String format, int playersCount, int maxPlayers) {
    final statusColor = _statusColor(status);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1B5E20), const Color(0xFF0A2618)]
              : [const Color(0xFF2E7D32), const Color(0xFF1B5E20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
                child: Text(_statusLabel(status), style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.people, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Text('$playersCount / $maxPlayers игроков', style: const TextStyle(color: Colors.white70)),
              const SizedBox(width: 16),
              const Icon(Icons.sports_tennis, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Text(format == 'DOUBLE' ? 'Парный' : 'Одиночный', style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _playersSection(List<Map<String, dynamic>> players, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Игроки', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        if (players.isEmpty)
          const Text('Нет данных об игроках', style: TextStyle(color: Colors.grey))
        else
          ...players.map((p) {
            final name = '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
            final avatar = p['avatar']?.toString();
            final elo = (p['rating_elo'] ?? '').toString();
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: NetworkImage(
                      (avatar != null && avatar.isNotEmpty) ? avatar : 'https://i.pravatar.cc/150?img=${(p['id'] ?? 1) % 70}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(name.isEmpty ? (p['username'] ?? '').toString() : name, style: const TextStyle(fontWeight: FontWeight.w600))),
                  if (elo.isNotEmpty) Text('ELO $elo', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _actionsSection(String status, bool isFull, Map<String, dynamic> lobby) {
    final id = widget.lobbyId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status == 'OPEN' && !isFull)
          ElevatedButton.icon(
            onPressed: () => _doAction(() => AppScope.instance.socialRepository.joinLobby(id), 'Вы вступили в лобби'),
            icon: const Icon(Icons.login),
            label: const Text('Вступить'),
          ),
        if (status == 'OPEN')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: () => _doAction(() => AppScope.instance.socialRepository.leaveLobby(id), 'Вы вышли из лобби'),
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text('Покинуть', style: TextStyle(color: Colors.redAccent)),
            ),
          ),
        if (status == 'FULL' || status == 'VOTING')
          ElevatedButton.icon(
            onPressed: () => _showProposeDialog(),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Предложить время/корт'),
          ),
        if (status == 'BOOKED')
          ElevatedButton.icon(
            onPressed: () => _showPayDialog(),
            icon: const Icon(Icons.payment),
            label: const Text('Оплатить свою долю'),
          ),
        if (status == 'READY')
          ElevatedButton.icon(
            onPressed: () => _doAction(() => AppScope.instance.socialRepository.closeLobby(id), 'Лобби закрыто'),
            icon: const Icon(Icons.check_circle),
            label: const Text('Завершить лобби'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
      ],
    );
  }

  Widget _proposalsSection(bool isDark, Map<String, dynamic> lobby) {
    final id = widget.lobbyId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Предложения', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _proposalsFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
            if (snap.hasError) return Text(snap.error.toString(), style: const TextStyle(color: Colors.redAccent));
            final proposals = snap.data ?? [];
            if (proposals.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Пока нет предложений. Предложите время и корт!', style: TextStyle(color: Colors.grey)),
              );
            }
            return Column(
              children: proposals.map((p) {
                final pId = (p['id'] as num?)?.toInt();
                final courtName = (p['court_name'] ?? p['court'] ?? '').toString();
                final time = (p['proposed_time'] ?? p['start_time'] ?? '').toString();
                final votes = (p['votes_count'] as num?)?.toInt() ?? 0;
                final isAccepted = p['is_accepted'] == true;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: isAccepted ? Border.all(color: Colors.green, width: 2) : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (courtName.isNotEmpty) Text(courtName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                if (time.isNotEmpty) Text(time, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$votes голосов', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      if (!isAccepted && pId != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () => _doAction(() => AppScope.instance.socialRepository.vote(id, pId), 'Голос принят'),
                              child: const Text('Голосовать'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => _doAction(() => AppScope.instance.socialRepository.acceptProposal(id, pId), 'Предложение принято'),
                              child: const Text('Принять', style: TextStyle(color: Colors.green)),
                            ),
                          ],
                        ),
                      ],
                      if (isAccepted) ...[
                        const SizedBox(height: 6),
                        const Text('Принято', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => _doAction(() => AppScope.instance.socialRepository.bookLobby(id), 'Лобби забронировано! Теперь можно оплатить.'),
          child: const Text('Забронировать корт для лобби'),
        ),
      ],
    );
  }

  Widget _paymentSection(Map<String, dynamic> lobby) {
    final id = widget.lobbyId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Оплата', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        FutureBuilder<Map<String, dynamic>>(
          future: AppScope.instance.socialRepository.paymentStatus(id),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
            if (snap.hasError) return Text(snap.error.toString());
            final ps = snap.data ?? {};
            final total = (ps['total_amount'] ?? '—').toString();
            final perPerson = (ps['per_person'] ?? '—').toString();
            final paidPlayers = (ps['paid_players'] as num?)?.toInt() ?? 0;
            final totalPlayers = (ps['total_players'] as num?)?.toInt() ?? 0;
            final myPaid = ps['my_status'] == 'PAID';

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Итого: $total тг', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('На каждого: $perPerson тг', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: totalPlayers > 0 ? paidPlayers / totalPlayers : 0,
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  const SizedBox(height: 4),
                  Text('Оплатили: $paidPlayers / $totalPlayers', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (myPaid) ...[
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 6),
                        Text('Вы уже оплатили', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _showProposeDialog() async {
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = const TimeOfDay(hour: 18, minute: 0);
    int? selectedCourtId;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: BoxDecoration(color: Theme.of(ctx).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Text('Предложить время', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _modernPickerTile(
                        ctx: ctx,
                        icon: Icons.calendar_today_rounded,
                        label: _fmtDateShort(selectedDate),
                        onTap: () => _showCupertinoDate(ctx, selectedDate, (d) => setModal(() => selectedDate = d)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _modernPickerTile(
                        ctx: ctx,
                        icon: Icons.schedule_rounded,
                        label: '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                        onTap: () => _showCupertinoTime(ctx, selectedTime, (t) => setModal(() => selectedTime = t)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: AppScope.instance.bookingRepository.courts(),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
                    final courts = snap.data ?? [];
                    if (courts.isEmpty) return const Text('Кортов нет');
                    return DropdownButtonFormField<int>(
                      initialValue: selectedCourtId,
                      decoration: InputDecoration(
                        labelText: 'Корт',
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.1),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      items: courts.map((c) {
                        final id = (c['id'] as num).toInt();
                        return DropdownMenuItem<int>(value: id, child: Text((c['name'] ?? 'Корт $id').toString()));
                      }).toList(),
                      onChanged: (v) => setModal(() => selectedCourtId = v),
                    );
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: selectedCourtId == null
                        ? null
                        : () {
                            final start = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                            Navigator.pop(ctx, {
                              'court_id': selectedCourtId,
                              'proposed_time': start.toUtc().toIso8601String(),
                            });
                          },
                    child: const Text('Предложить'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != null) {
      _doAction(() => AppScope.instance.socialRepository.propose(widget.lobbyId, result), 'Предложение создано');
    }
  }

  void _showPayDialog() async {
    String payMethod = 'KASPI';

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Оплатить долю'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Выберите способ оплаты:'),
              const SizedBox(height: 12),
              ...['KASPI', 'CARD', 'CASH'].map((m) => ListTile(
                    title: Text(_payLabel(m)),
                    leading: Icon(
                      m == payMethod ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: m == payMethod ? AppTheme.primaryColor : Colors.grey,
                    ),
                    onTap: () => setDlg(() => payMethod = m),
                  )),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, payMethod), child: const Text('Оплатить')),
          ],
        ),
      ),
    );
    if (result != null) {
      _doAction(() => AppScope.instance.socialRepository.payShare(widget.lobbyId, result), 'Оплата выполнена');
    }
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'OPEN': return Colors.green;
    case 'FULL': return Colors.orange;
    case 'VOTING': return Colors.blue;
    case 'BOOKED': return Colors.purple;
    case 'READY': return Colors.teal;
    case 'CLOSED': return Colors.grey;
    default: return Colors.grey;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'OPEN': return 'Открыто';
    case 'FULL': return 'Полное';
    case 'VOTING': return 'Голосование';
    case 'BOOKED': return 'Забронировано';
    case 'READY': return 'Готово';
    case 'CLOSED': return 'Завершено';
    default: return status;
  }
}

String _payLabel(String method) {
  switch (method) {
    case 'KASPI': return 'Kaspi';
    case 'CARD': return 'Карта';
    case 'CASH': return 'Наличные';
    default: return method;
  }
}

Widget _modernPickerTile({required BuildContext ctx, required IconData icon, required String label, required VoidCallback onTap}) {
  final isDark = Theme.of(ctx).brightness == Brightness.dark;
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
          Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.grey.withValues(alpha: 0.6)),
        ],
      ),
    ),
  );
}

String _fmtDateShort(DateTime d) {
  const months = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
  return '${d.day} ${months[d.month - 1]}';
}

void _showCupertinoDate(BuildContext ctx, DateTime current, ValueChanged<DateTime> onPicked) {
  DateTime temp = current;
  showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      height: 320,
      decoration: BoxDecoration(
        color: Theme.of(sheetCtx).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Выберите дату', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                TextButton(
                  onPressed: () { onPicked(temp); Navigator.pop(sheetCtx); },
                  child: const Text('Готово', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
          Expanded(
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: current,
              minimumDate: DateTime.now().subtract(const Duration(days: 1)),
              maximumDate: DateTime.now().add(const Duration(days: 60)),
              onDateTimeChanged: (d) => temp = d,
            ),
          ),
        ],
      ),
    ),
  );
}

void _showCupertinoTime(BuildContext ctx, TimeOfDay current, ValueChanged<TimeOfDay> onPicked) {
  DateTime temp = DateTime(2025, 1, 1, current.hour, current.minute);
  showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      height: 320,
      decoration: BoxDecoration(
        color: Theme.of(sheetCtx).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Выберите время', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                TextButton(
                  onPressed: () { onPicked(TimeOfDay(hour: temp.hour, minute: temp.minute)); Navigator.pop(sheetCtx); },
                  child: const Text('Готово', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
          Expanded(
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              initialDateTime: temp,
              use24hFormat: true,
              minuteInterval: 15,
              onDateTimeChanged: (d) => temp = d,
            ),
          ),
        ],
      ),
    ),
  );
}
