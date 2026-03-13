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
  Future<Map<String, dynamic>>? _extrasFuture;
  Future<Map<String, dynamic>>? _paymentStatusFuture;
  int? _myUserId;

  @override
  void initState() {
    super.initState();
    _reload();
    _loadMyId();
  }

  Future<void> _loadMyId() async {
    try {
      final me = await AppScope.instance.authRepository.me();
      if (!mounted) return;
      setState(() => _myUserId = (me['id'] as num?)?.toInt());
    } catch (_) {}
  }

  void _reload() {
    _detailFuture = AppScope.instance.socialRepository.lobbyDetail(widget.lobbyId);
    // Participant-only endpoints — silently return empty on 403/400
    _proposalsFuture = AppScope.instance.socialRepository
        .lobbyProposals(widget.lobbyId)
        .catchError((_) => <Map<String, dynamic>>[]);
    _extrasFuture = AppScope.instance.socialRepository
        .myExtras(widget.lobbyId)
        .catchError((_) => <String, dynamic>{});
    _paymentStatusFuture = AppScope.instance.socialRepository
        .paymentStatus(widget.lobbyId)
        .catchError((_) => <String, dynamic>{});
  }

  bool _isCreator(Map<String, dynamic> lobby) {
    if (_myUserId == null) return false;
    return (lobby['creator'] as num?)?.toInt() == _myUserId;
  }

  bool _isParticipant(List<Map<String, dynamic>> participants) {
    if (_myUserId == null) return false;
    return participants.any((p) {
      final uid = ((p['user'] ?? p['id']) as num?)?.toInt();
      return uid == _myUserId;
    });
  }

  bool _isTrainer(Map<String, dynamic> lobby) {
    if (_myUserId == null) return false;
    final trainerId = (lobby['trainer'] as num?)?.toInt();
    return trainerId != null && trainerId == _myUserId;
  }

  bool _iAlreadyPaid(List<Map<String, dynamic>> participants) {
    if (_myUserId == null) return false;
    final me = participants.where((p) {
      final uid = ((p['user'] ?? p['id']) as num?)?.toInt();
      return uid == _myUserId;
    });
    if (me.isEmpty) return false;
    return me.first['is_paid'] == true;
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

  Future<void> _confirmAndDo({
    required String title,
    required String message,
    required String confirmLabel,
    required Future<dynamic> Function() action,
    String? successMsg,
    bool isDestructive = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? Colors.redAccent : null,
              foregroundColor: isDestructive ? Colors.white : null,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _doAction(action, successMsg);
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
          final participantsList = ((lobby['participants'] as List?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final playersCount = (lobby['players_count'] as num?)?.toInt() ??
              (lobby['current_players_count'] as num?)?.toInt() ??
              participantsList.length;
          final maxPlayers = (lobby['max_players'] as num?)?.toInt() ?? 4;
          final format = (lobby['game_format'] ?? '').toString();
          final isFull = playersCount >= maxPlayers;
          final isCreator = _isCreator(lobby);
          final isParticipant = _isParticipant(participantsList);
          final iAlreadyPaid = _iAlreadyPaid(participantsList);

          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _headerCard(context, isDark, lobby, title, status, format, playersCount, maxPlayers),
                const SizedBox(height: 16),
                _playersSection(participantsList, isDark, status),
                const SizedBox(height: 16),
                _actionsSection(status, isFull, lobby, isCreator, isParticipant, iAlreadyPaid),
                const SizedBox(height: 16),
                // Proposals: only participants can view and interact
                if (isParticipant && (status == 'NEGOTIATING' || status == 'READY' || status == 'BOOKED'))
                  _proposalsSection(isDark, lobby, isCreator),
                if (status == 'READY' && isCreator) ...[
                  const SizedBox(height: 12),
                  _teamAssignmentSection(participantsList, lobby),
                ],
                // Extras / payment: only for participants
                if (isParticipant && (status == 'BOOKED' || status == 'PAID')) ...[
                  _extrasSection(lobby),
                  const SizedBox(height: 16),
                  _paymentSection(lobby),
                ],
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Header ───

  Widget _headerCard(BuildContext context, bool isDark, Map<String, dynamic> lobby,
      String title, String status, String format, int playersCount, int maxPlayers) {
    final statusColor = _statusColor(status);
    final eloLabel = (lobby['elo_label'] ?? '').toString();
    final comment = (lobby['comment'] ?? '').toString();
    final courtName = (lobby['court_name'] ?? '').toString();
    final scheduledTime = (lobby['scheduled_time'] ?? '').toString();
    final estimatedShare = (lobby['estimated_share'] ?? '').toString();
    final creatorName = (lobby['creator_name'] ?? '').toString();
    final trainerName = (lobby['trainer_name'] ?? '').toString();

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
          const SizedBox(height: 8),
          if (creatorName.isNotEmpty)
            Text('Организатор: $creatorName', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
          if (trainerName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.sports_rounded, color: Colors.amberAccent, size: 15),
              const SizedBox(width: 5),
              Text('Тренер: $trainerName', style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.people, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Text('$playersCount / $maxPlayers', style: const TextStyle(color: Colors.white70)),
              const SizedBox(width: 16),
              const Icon(Icons.sports_tennis, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Text(format == 'DOUBLE' ? 'Парный (2v2)' : 'Одиночный (1v1)', style: const TextStyle(color: Colors.white70)),
            ],
          ),
          if (eloLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 16),
              const SizedBox(width: 6),
              Text(eloLabel, style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ],
          if (courtName.isNotEmpty || scheduledTime.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              if (courtName.isNotEmpty) ...[
                const Icon(Icons.place_rounded, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text(courtName, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(width: 12),
              ],
              if (scheduledTime.isNotEmpty) ...[
                const Icon(Icons.schedule_rounded, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text(_formatDateTime(scheduledTime), style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ]),
          ],
          if (estimatedShare.isNotEmpty && estimatedShare != 'null') ...[
            const SizedBox(height: 8),
            Text('~$estimatedShare тг/чел', style: TextStyle(color: Colors.greenAccent.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600)),
          ],
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white60, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(comment, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Players ───

  Widget _playersSection(List<Map<String, dynamic>> players, bool isDark, String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Игроки', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        if (players.isEmpty)
          const Text('Нет данных об игроках', style: TextStyle(color: Colors.grey))
        else
          ...players.map((p) {
            final name = (p['user_name'] ?? '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}').toString().trim();
            final avatar = p['avatar']?.toString();
            final elo = (p['rating_elo'] ?? '').toString();
            final team = (p['team'] ?? '').toString();
            final isPaid = p['is_paid'] == true;
            final membershipUsed = p['membership_used'] == true;
            final userId = (p['user'] ?? p['id']) as num?;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: userId?.toInt() == _myUserId
                    ? Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4), width: 1.5)
                    : null,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: NetworkImage(
                      (avatar != null && avatar.isNotEmpty) ? avatar : 'https://i.pravatar.cc/150?img=${(userId ?? 1).toInt() % 70}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.isEmpty ? (p['username'] ?? '').toString() : name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (elo.isNotEmpty)
                          Text('ELO $elo', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (team.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: team == 'A' ? Colors.blue.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(team, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold,
                        color: team == 'A' ? Colors.blue : Colors.orange,
                      )),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (status == 'BOOKED' || status == 'PAID')
                    Icon(
                      isPaid ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                      size: 18,
                      color: isPaid ? Colors.green : Colors.grey.withValues(alpha: 0.4),
                    ),
                  if (membershipUsed) ...[
                    const SizedBox(width: 4),
                    const Tooltip(
                      message: 'Абонемент',
                      child: Icon(Icons.card_membership_rounded, size: 16, color: AppTheme.primaryColor),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  // ─── Actions ───

  Widget _actionsSection(String status, bool isFull, Map<String, dynamic> lobby, bool isCreator, bool isParticipant, bool iAlreadyPaid) {
    final id = widget.lobbyId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Join: only if not already a participant and lobby not full
        if ((status == 'OPEN' || status == 'WAITING') && !isFull && !isParticipant)
          ElevatedButton.icon(
            onPressed: () => _confirmAndDo(
              title: 'Вступить в лобби?',
              message: 'Вы хотите присоединиться к этому лобби?',
              confirmLabel: 'Вступить',
              action: () => AppScope.instance.socialRepository.joinLobby(id),
              successMsg: 'Вы вступили в лобби',
            ),
            icon: const Icon(Icons.login),
            label: const Text('Вступить'),
          ),
        // Leave: only if participant and not yet booked
        if ((status == 'OPEN' || status == 'WAITING' || status == 'NEGOTIATING') && isParticipant)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: () => _confirmAndDo(
                title: 'Покинуть лобби?',
                message: 'Вы уверены, что хотите выйти из лобби?',
                confirmLabel: 'Покинуть',
                isDestructive: true,
                action: () => AppScope.instance.socialRepository.leaveLobby(id),
                successMsg: 'Вы вышли из лобби',
              ),
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text('Покинуть', style: TextStyle(color: Colors.redAccent)),
            ),
          ),
        if (status == 'NEGOTIATING' && isParticipant)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ElevatedButton.icon(
              onPressed: () => _showProposeDialog(),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Предложить время/корт'),
            ),
          ),
        // Pay: only if booked, is participant, and not yet paid
        if (status == 'BOOKED' && isParticipant && !iAlreadyPaid)
          ElevatedButton.icon(
            onPressed: () => _showPayDialog(),
            icon: const Icon(Icons.payment),
            label: const Text('Оплатить свою долю'),
          ),
        if (status == 'BOOKED' && isParticipant && iAlreadyPaid)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text('Ваша доля оплачена', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _showCancelRequestSheet(isPaid: true),
                icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                label: const Text('Запросить отмену', style: TextStyle(color: Colors.redAccent)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
              ),
            ],
          ),
        // Participant cancellation for BOOKED (not yet paid)
        if (status == 'BOOKED' && isParticipant && !iAlreadyPaid)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: () => _showCancelRequestSheet(isPaid: false),
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text('Отменить участие', style: TextStyle(color: Colors.redAccent)),
            ),
          ),
        // Record match result: only the assigned trainer (or creator if no trainer)
        if (status == 'PAID') ...[
          if (_isTrainer(lobby))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _showRecordMatchResultSheet(lobby),
                  icon: const Icon(Icons.scoreboard_rounded),
                  label: const Text('Записать результат матча', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            )
          else if (isParticipant) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Icon(Icons.sports_rounded, color: AppTheme.primaryColor, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    (lobby['trainer_name'] ?? '').toString().isNotEmpty
                        ? 'Тренер ${lobby['trainer_name']} запишет результат после игры'
                        : 'Результат будет записан тренером после игры',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'ELO обновится автоматически',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ],
        // Creator: cancel/close lobby at any non-terminal status (including BOOKED/PAID)
        if (isCreator && status != 'CLOSED') ...[
          const SizedBox(height: 4),
          Builder(builder: (ctx) {
            final bookingId = (lobby['booking_id'] as num?)?.toInt();
            final hasBooking = bookingId != null && (status == 'BOOKED' || status == 'PAID');
            return OutlinedButton.icon(
              onPressed: () => _confirmAndDo(
                title: 'Отменить лобби?',
                message: status == 'PAID'
                    ? 'Все участники уже оплатили. Бронь и лобби будут отменены. Возврат средств осуществляется согласно политике клуба.'
                    : status == 'BOOKED'
                        ? 'Бронь будет отменена. Возврат средств зависит от политики клуба.'
                        : 'Лобби будет закрыто для всех участников.',
                confirmLabel: 'Отменить',
                isDestructive: true,
                action: () async {
                  // For BOOKED/PAID: cancel the actual booking first
                  if (hasBooking) {
                    await AppScope.instance.bookingRepository.cancelBooking(bookingId);
                  }
                  // Then close the lobby (best-effort — may fail if backend restricts it)
                  try {
                    await AppScope.instance.socialRepository.closeLobby(id);
                  } catch (_) {}
                },
                successMsg: hasBooking ? 'Бронь и лобби отменены' : 'Лобби закрыто',
              ),
              icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
              label: const Text('Отменить лобби', style: TextStyle(color: Colors.redAccent)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
            );
          }),
        ],
      ],
    );
  }

  // ─── Proposals ───

  Widget _proposalsSection(bool isDark, Map<String, dynamic> lobby, bool isCreator) {
    final id = widget.lobbyId;
    final lobbyStatus = (lobby['status'] ?? '').toString();
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
                final time = (p['scheduled_time'] ?? '').toString();
                final duration = (p['duration_minutes'] as num?)?.toInt();
                final votes = (p['votes_count'] as num?)?.toInt() ?? 0;
                final maxP = (lobby['max_players'] as num?)?.toInt() ?? 4;
                final isAccepted = p['is_accepted'] == true;
                final iVoted = p['i_voted'] == true;
                final share = (p['estimated_share'] ?? '').toString();
                final proposedBy = (p['proposed_by_name'] ?? '').toString();

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
                                if (time.isNotEmpty)
                                  Text(
                                    '${_formatDateTime(time)}${duration != null ? '  •  $duration мин' : ''}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                if (proposedBy.isNotEmpty)
                                  Text('от $proposedBy', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                if (share.isNotEmpty && share != 'null')
                                  Text('~$share тг/чел', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$votes/$maxP', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      if (!isAccepted && pId != null && lobbyStatus == 'NEGOTIATING') ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _doAction(() => AppScope.instance.socialRepository.vote(id, pId), iVoted ? 'Голос убран' : 'Голос принят'),
                              icon: Icon(iVoted ? Icons.how_to_vote : Icons.how_to_vote_outlined, size: 18),
                              label: Text(iVoted ? 'Убрать голос' : 'Голосовать'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: iVoted ? Colors.orange : null,
                                side: iVoted ? const BorderSide(color: Colors.orange) : null,
                              ),
                            ),
                            if (isCreator) ...[
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _doAction(() => AppScope.instance.socialRepository.acceptProposal(id, pId), 'Предложение принято!'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                child: const Text('Принять'),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (isAccepted) ...[
                        const SizedBox(height: 6),
                        const Row(children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 16),
                          SizedBox(width: 4),
                          Text('Принято', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                        ]),
                      ],
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ─── Team Assignment (READY, creator only) ───

  Widget _teamAssignmentSection(List<Map<String, dynamic>> participants, Map<String, dynamic> lobby) {
    final allAssigned = participants.isNotEmpty &&
        participants.every((p) => (p['team'] ?? '').toString().isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.groups_rounded, color: AppTheme.primaryColor, size: 20),
            SizedBox(width: 8),
            Text('Назначить команды', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ]),
          const SizedBox(height: 8),
          const Text('Распределите игроков по командам A и B, затем создайте бронь.',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showTeamAssignmentSheet(participants),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Распределить команды'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            ),
          ),
          if (allAssigned) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _doAction(
                    () => AppScope.instance.socialRepository.bookLobby(widget.lobbyId),
                    'Бронь создана! Теперь каждый может добавить услуги и оплатить.'),
                icon: const Icon(Icons.event_available_rounded),
                label: const Text('Забронировать корт'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showTeamAssignmentSheet(List<Map<String, dynamic>> participants) {
    final teams = <String, String>{};
    for (final p in participants) {
      final uId = (p['user'] ?? p['id']).toString();
      teams[uId] = (p['team'] ?? '').toString();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Распределение команд', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Нажмите на A или B для каждого игрока', style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 16),
              ...participants.map((p) {
                final uId = (p['user'] ?? p['id']).toString();
                final name = (p['user_name'] ?? '').toString();
                final currentTeam = teams[uId] ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                      ToggleButtons(
                        isSelected: [currentTeam == 'A', currentTeam == 'B'],
                        onPressed: (i) => setSheet(() => teams[uId] = i == 0 ? 'A' : 'B'),
                        borderRadius: BorderRadius.circular(10),
                        selectedColor: Colors.white,
                        fillColor: currentTeam == 'A' ? Colors.blue : Colors.orange,
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 36),
                        children: const [Text('A', style: TextStyle(fontWeight: FontWeight.bold)), Text('B', style: TextStyle(fontWeight: FontWeight.bold))],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: teams.values.every((t) => t == 'A' || t == 'B')
                      ? () {
                          Navigator.pop(ctx);
                          _doAction(
                            () => AppScope.instance.socialRepository.assignTeams(widget.lobbyId, teams),
                            'Команды назначены!',
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                  child: const Text('Сохранить команды'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── My Extras (BOOKED) ───

  Widget _extrasSection(Map<String, dynamic> lobby) {
    final id = widget.lobbyId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Мои услуги', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            TextButton.icon(
              onPressed: () => _showAddExtrasSheet(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Добавить'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FutureBuilder<Map<String, dynamic>>(
          future: _extrasFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
            if (snap.hasError) return Text(snap.error.toString(), style: const TextStyle(fontSize: 12, color: Colors.redAccent));
            final data = snap.data ?? {};
            final extras = ((data['extras'] as List?) ?? const [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            final extrasTotal = (data['extras_total'] ?? '0').toString();
            final courtShare = (data['court_share'] ?? '0').toString();
            final totalToPay = (data['total_to_pay'] ?? '0').toString();

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (extras.isEmpty)
                    const Text('Нет добавленных услуг', style: TextStyle(color: Colors.grey, fontSize: 13))
                  else
                    ...extras.map((e) {
                      final extraId = (e['id'] as num?)?.toInt();
                      final svcName = (e['service_name'] ?? '').toString();
                      final qty = (e['quantity'] as num?)?.toInt() ?? 1;
                      final subtotal = (e['subtotal'] ?? e['price'] ?? '').toString();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text('$svcName x$qty', style: const TextStyle(fontSize: 14))),
                            Text('$subtotal тг', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            if (extraId != null) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _doAction(() => AppScope.instance.socialRepository.removeMyExtra(id, extraId), 'Услуга удалена'),
                                child: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  const Divider(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Доля за корт:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    Text('$courtShare тг', style: const TextStyle(fontSize: 13)),
                  ]),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Доп. услуги:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    Text('$extrasTotal тг', style: const TextStyle(fontSize: 13)),
                  ]),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Итого к оплате:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text('$totalToPay тг', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  ]),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _showAddExtrasSheet() async {
    List<Map<String, dynamic>> services;
    try {
      services = await AppScope.instance.secondaryRepository.services();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось загрузить услуги')));
      return;
    }
    if (!mounted) return;

    final selected = <int, int>{};

    final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Добавить услуги', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: services.length,
                  itemBuilder: (_, i) {
                    final svc = services[i];
                    final sId = (svc['id'] as num).toInt();
                    final name = (svc['name'] ?? '').toString();
                    final price = (svc['price'] ?? '0').toString();
                    final qty = selected[sId] ?? 0;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('$price тг', style: const TextStyle(fontSize: 13)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 22),
                            onPressed: qty > 0 ? () => setSheet(() => selected[sId] = qty - 1) : null,
                          ),
                          Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 22, color: AppTheme.primaryColor),
                            onPressed: () => setSheet(() => selected[sId] = qty + 1),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: selected.values.any((q) => q > 0)
                      ? () {
                          final list = selected.entries
                              .where((e) => e.value > 0)
                              .map((e) => {'service_id': e.key, 'quantity': e.value})
                              .toList();
                          Navigator.pop(ctx, list);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                  child: const Text('Добавить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      _doAction(() => AppScope.instance.socialRepository.addMyExtras(widget.lobbyId, result), 'Услуги добавлены');
    }
  }

  // ─── Payment ───

  Widget _paymentSection(Map<String, dynamic> lobby) {
    final id = widget.lobbyId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Оплата', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        FutureBuilder<Map<String, dynamic>>(
          future: _paymentStatusFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
            if (snap.hasError) return Text(snap.error.toString());
            final ps = snap.data ?? {};
            final total = (ps['court_total'] ?? '—').toString();
            final paidCount = (ps['paid_count'] as num?)?.toInt() ?? 0;
            final totalCount = (ps['total_count'] as num?)?.toInt() ?? 0;
            final allPaid = ps['all_paid'] == true;
            final participants = ((ps['participants'] as List?) ?? const [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Итого за корт: $total тг', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (allPaid)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                          child: const Text('Все оплатили', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: totalCount > 0 ? paidCount / totalCount : 0,
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  const SizedBox(height: 4),
                  Text('Оплатили: $paidCount / $totalCount', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (participants.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...participants.map((p) {
                      final pName = (p['user_name'] ?? '').toString();
                      final pTeam = (p['team'] ?? '').toString();
                      final courtShare = (p['court_share'] ?? '0').toString();
                      final extrasTotal = (p['extras_total'] ?? '0').toString();
                      final totalToPay = (p['total_to_pay'] ?? '0').toString();
                      final isPaid = p['is_paid'] == true;
                      final membershipUsed = p['membership_used'] == true;
                      final isMe = (p['user_id'] as num?)?.toInt() == _myUserId;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppTheme.primaryColor.withValues(alpha: 0.05)
                              : Colors.grey.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: isMe ? Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)) : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isPaid ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                              size: 18,
                              color: isPaid ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Text(pName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isMe ? AppTheme.primaryColor : null)),
                                    if (pTeam.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text(pTeam, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: pTeam == 'A' ? Colors.blue : Colors.orange)),
                                    ],
                                    if (membershipUsed) ...[
                                      const SizedBox(width: 6),
                                      const Icon(Icons.card_membership_rounded, size: 14, color: AppTheme.primaryColor),
                                    ],
                                  ]),
                                  Text(
                                    membershipUsed ? 'Абонемент' : 'Корт: $courtShare${extrasTotal != '0' ? ' + услуги: $extrasTotal' : ''}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              isPaid ? 'Оплачено' : '$totalToPay тг',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isPaid ? Colors.green : null,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ─── Dialogs ───

  void _showCancelRequestSheet({required bool isPaid}) async {
    final reasonCtrl = TextEditingController();
    bool agreed = false;
    bool loading = false;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            decoration: BoxDecoration(
              color: Theme.of(ctx).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                )),
                Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    isPaid ? 'Запрос на отмену участия' : 'Отмена участия',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ]),
                const SizedBox(height: 12),
                if (isPaid) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'Вы уже оплатили свою долю. После отмены организатор будет уведомлён. '
                      'Вопрос возврата средств решается организатором согласно политике клуба.',
                      style: TextStyle(fontSize: 13, color: Colors.redAccent),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                const Text('Причина (необязательно)', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Укажите причину отмены...',
                    filled: true,
                    fillColor: Colors.grey.withValues(alpha: 0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                if (isPaid)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: agreed,
                    onChanged: (v) => setSheet(() => agreed = v ?? false),
                    title: const Text(
                      'Я понимаю, что возврат средств решается организатором',
                      style: TextStyle(fontSize: 13),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colors.redAccent,
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: (isPaid && !agreed) || loading
                        ? null
                        : () {
                            setSheet(() => loading = true);
                            Navigator.pop(ctx, true);
                          },
                    child: loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(isPaid ? 'Отправить запрос на отмену' : 'Отменить участие'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Назад'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed == true) {
      _doAction(
        () => AppScope.instance.socialRepository.leaveLobby(widget.lobbyId),
        isPaid
            ? 'Запрос отправлен. Организатор получит уведомление.'
            : 'Вы отменили участие',
      );
    }
  }

  void _showProposeDialog() async {
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = const TimeOfDay(hour: 18, minute: 0);
    int? selectedCourtId;
    int durationMinutes = 90;

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
                      value: selectedCourtId,
                      decoration: InputDecoration(
                        labelText: 'Корт',
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.1),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      items: courts.map((c) {
                        final cId = (c['id'] as num).toInt();
                        return DropdownMenuItem<int>(value: cId, child: Text((c['name'] ?? 'Корт $cId').toString()));
                      }).toList(),
                      onChanged: (v) => setModal(() => selectedCourtId = v),
                    );
                  },
                ),
                const SizedBox(height: 12),
                const Text('Длительность', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final d in [60, 90, 120])
                      ChoiceChip(
                        label: Text('$d мин'),
                        selected: durationMinutes == d,
                        onSelected: (_) => setModal(() => durationMinutes = d),
                      ),
                  ],
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
                              'court': selectedCourtId,
                              'scheduled_time': start.toUtc().toIso8601String(),
                              'duration_minutes': durationMinutes,
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

  // ─── Record match result from lobby ───

  void _showRecordMatchResultSheet(Map<String, dynamic> lobby) {
    final participants = ((lobby['participants'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final teamA = participants.where((p) => (p['team'] ?? '').toString() == 'A').toList();
    final teamB = participants.where((p) => (p['team'] ?? '').toString() == 'B').toList();

    if (teamA.isEmpty || teamB.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Команды не назначены. Невозможно записать результат.')),
      );
      return;
    }

    final sets = List.generate(3, (_) => [TextEditingController(), TextEditingController()]);
    bool submitting = false;

    String teamNames(List<Map<String, dynamic>> team) {
      return team.map((p) {
        final name = (p['user_name'] ?? '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}').toString().trim();
        return name.isEmpty ? 'Игрок' : name;
      }).join(', ');
    }

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
              if (a > b) {
                setsWonA++;
              } else if (b > a) {
                setsWonB++;
              }
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
                    const Row(children: [
                      Icon(Icons.scoreboard_rounded, color: AppTheme.primaryColor),
                      SizedBox(width: 10),
                      Text('Результат матча', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(6)),
                          child: const Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(teamNames(teamA), style: const TextStyle(fontWeight: FontWeight.w600))),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(6)),
                          child: const Text('B', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(teamNames(teamB), style: const TextStyle(fontWeight: FontWeight.w600))),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        const SizedBox(width: 60),
                        Expanded(child: Center(child: Text('A', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.withValues(alpha: 0.7))))),
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
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isOptional ? Colors.grey : null,
                                ),
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
                                  fillColor: Colors.blue.withValues(alpha: 0.06),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
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
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
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
                        margin: const EdgeInsets.only(top: 4, bottom: 16),
                        decoration: BoxDecoration(
                          color: hasWinner
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.08),
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
                                  ? 'Победитель: Команда ${setsWonA > setsWonB ? 'A' : 'B'} ($setsWonA:$setsWonB по сетам)'
                                  : 'Счёт по сетам: $setsWonA:$setsWonB',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: hasWinner ? Colors.green : Colors.grey,
                              ),
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

                                final teamAIds = teamA.map((p) => ((p['user'] ?? p['id']) as num).toInt()).toList();
                                final teamBIds = teamB.map((p) => ((p['user'] ?? p['id']) as num).toInt()).toList();
                                final courtId = (lobby['court'] as num?)?.toInt();

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

                                  try {
                                    await AppScope.instance.socialRepository.closeLobby(widget.lobbyId);
                                  } catch (_) {}

                                  nav.pop();
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Матч записан! Результат отправлен на подтверждение участникам.'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  if (mounted) setState(_reload);
                                } catch (e) {
                                  setSheet(() => submitting = false);
                                  messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                                }
                              }
                            : null,
                        icon: submitting
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_rounded),
                        label: Text(submitting ? 'Сохранение...' : 'Записать результат'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(children: [
                        Icon(Icons.info_outline, size: 16, color: AppTheme.primaryColor),
                        SizedBox(width: 8),
                        Expanded(child: Text(
                          'После записи матч появится у всех участников для подтверждения. Рейтинг обновится после подтверждения.',
                          style: TextStyle(fontSize: 12, color: AppTheme.primaryColor),
                        )),
                      ]),
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

  String _formatDateTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Top-level helpers ───

Color _statusColor(String status) {
  switch (status) {
    case 'OPEN': return Colors.green;
    case 'WAITING': return Colors.orange;
    case 'NEGOTIATING': return Colors.blue;
    case 'BOOKED': return Colors.purple;
    case 'READY': return Colors.teal;
    case 'PAID': return Colors.green;
    case 'CLOSED': return Colors.grey;
    default: return Colors.grey;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'OPEN': return 'Открыто';
    case 'WAITING': return 'Ожидание';
    case 'NEGOTIATING': return 'Согласование';
    case 'BOOKED': return 'Забронировано';
    case 'READY': return 'Готово';
    case 'PAID': return 'Оплачено';
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
