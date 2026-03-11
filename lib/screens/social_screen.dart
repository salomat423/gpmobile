import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/di/app_scope.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'lobby_detail_screen.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<List<Map<String, dynamic>>> _openLobbiesFuture;
  late Future<List<Map<String, dynamic>>> _myLobbiesFuture;
  late Future<List<Map<String, dynamic>>> _friendsFuture;
  late Future<List<Map<String, dynamic>>> _incomingFuture;
  late Future<List<Map<String, dynamic>>> _outgoingFuture;
  late Future<List<Map<String, dynamic>>> _searchFuture;
  late Future<List<Map<String, dynamic>>> _feedFuture;
  late Future<List<Map<String, dynamic>>> _conversationsFuture;

  final _searchController = TextEditingController();
  Timer? _debounce;

  String _friendsSort = 'all';
  String _feedFilter = 'all';
  final Set<int> _likedFeedItems = {};

  bool _privacyShowProfile = true;
  bool _privacyShowStats = true;
  bool _privacyShowFeed = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(_handleTabChange);
    _reloadAll();
    _searchFuture = Future.value(const []);
  }

  @override
  void dispose() {
    _tabs.removeListener(_handleTabChange);
    _tabs.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabs.indexIsChanging && mounted) setState(() {});
  }

  void _reloadAll() {
    _openLobbiesFuture = AppScope.instance.socialRepository.listLobbies();
    _myLobbiesFuture = AppScope.instance.socialRepository.myLobbies();
    _friendsFuture = AppScope.instance.socialRepository.friends();
    _incomingFuture = AppScope.instance.socialRepository.incomingRequests();
    _outgoingFuture = AppScope.instance.socialRepository.outgoingRequests();
    _feedFuture = AppScope.instance.socialRepository.friendsFeed(limit: 20);
    _conversationsFuture = AppScope.instance.chatRepository
        .conversations()
        .catchError((_) => <Map<String, dynamic>>[]);
  }

  // ─── Search ───

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _searchFuture = value.trim().isEmpty
            ? Future.value(const [])
            : AppScope.instance.authRepository.searchUsers(value.trim());
      });
    });
  }

  // ─── Friend actions ───

  Future<void> _sendFriendRequest(int userId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.instance.socialRepository.sendFriendRequest(userId);
      if (!mounted) return;
      messenger.showSnackBar(
          const SnackBar(content: Text('Заявка отправлена')));
      setState(_reloadAll);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _respondRequest(int requestId, String action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.instance.socialRepository
          .respondRequest(requestId, action);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
          content: Text(
              action == 'accept' ? 'Заявка принята' : 'Заявка отклонена')));
      setState(_reloadAll);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _cancelRequest(int requestId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.instance.socialRepository.cancelRequest(requestId);
      if (!mounted) return;
      messenger.showSnackBar(
          const SnackBar(content: Text('Заявка отменена')));
      setState(_reloadAll);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _removeFriend(int userId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.instance.socialRepository.removeFriend(userId);
      if (!mounted) return;
      messenger
          .showSnackBar(const SnackBar(content: Text('Друг удалён')));
      setState(_reloadAll);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  // ─── Lobby actions ───

  Future<void> _joinLobby(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Вступить в лобби?'),
        content: const Text('Вы хотите присоединиться к этому лобби?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Вступить')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.instance.socialRepository.joinLobby(id);
      if (!mounted) return;
      messenger.showSnackBar(
          const SnackBar(content: Text('Вы вступили в лобби')));
      setState(_reloadAll);
      _openLobbyDetail(id);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _openLobbyDetail(int id) async {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LobbyDetailScreen(lobbyId: id)));
    if (!mounted) return;
    setState(_reloadAll);
  }

  // ─── Helpers ───

  String _avatarUrl(Map<String, dynamic> user) {
    final avatar = user['avatar']?.toString();
    final userId = (user['id'] as num?)?.toInt() ?? 1;
    return (avatar != null && avatar.isNotEmpty)
        ? avatar
        : 'https://i.pravatar.cc/150?img=${userId % 70}';
  }

  String _displayName(Map<String, dynamic> user) {
    final name =
        '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
    return name.isEmpty ? (user['username'] ?? '').toString() : name;
  }

  bool _isOnline(Map<String, dynamic> user) {
    final userId = (user['id'] as num?)?.toInt() ?? 0;
    return userId % 3 == 0;
  }

  Widget _avatarWithStatus(Map<String, dynamic> user, {double radius = 22}) {
    final online = _isOnline(user);
    return Stack(
      children: [
        CircleAvatar(
            radius: radius,
            backgroundImage: NetworkImage(_avatarUrl(user))),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: radius * 0.45,
            height: radius * 0.45,
            decoration: BoxDecoration(
              color: online ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Friend profile bottom sheet (2.7.2) ───

  void _showFriendProfile(Map<String, dynamic> user) {
    final userId = (user['id'] as num?)?.toInt();
    final displayName = _displayName(user);
    final phone =
        (user['phone_number'] ?? user['username'] ?? '').toString();
    final elo = (user['rating_elo'] ?? user['elo'] ?? '—').toString();

    Future<Map<String, dynamic>?>? profileFuture;
    if (userId != null) {
      profileFuture = AppScope.instance.authRepository
          .publicUserProfile(userId)
          .catchError((_) => <String, dynamic>{});
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (ctx, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Center(child: _avatarWithStatus(user, radius: 44)),
              const SizedBox(height: 16),
              Center(
                  child: Text(displayName,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold))),
              const SizedBox(height: 4),
              if (phone.isNotEmpty)
                Center(
                    child: Text(phone,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 14))),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events_rounded,
                          size: 20, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text('ELO $elo',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.primaryColor)),
                    ],
                  ),
                ),
              ),
              if (profileFuture != null)
                FutureBuilder<Map<String, dynamic>?>(
                  future: profileFuture,
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                            child:
                                CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    final profile = snap.data;
                    if (profile == null || profile.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final stats =
                        (profile['stats'] as Map?)
                                ?.cast<String, dynamic>() ??
                            {};
                    final matchesPlayed =
                        (stats['matches_played'] as num?)?.toInt() ?? 0;
                    final matchesWon =
                        (stats['matches_won'] as num?)?.toInt() ?? 0;
                    final winRate = matchesPlayed > 0
                        ? (matchesWon / matchesPlayed * 100)
                            .toStringAsFixed(1)
                        : '0.0';
                    final league =
                        (profile['league'] as Map?)
                                ?.cast<String, dynamic>() ??
                            {};
                    final leagueName =
                        (league['name'] ?? '').toString();

                    return Column(
                      children: [
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                                child: _statCard(
                                    'Матчей',
                                    matchesPlayed.toString(),
                                    Icons.sports_tennis_rounded)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: _statCard(
                                    'Побед %',
                                    '$winRate%',
                                    Icons.trending_up_rounded)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: _statCard(
                                    'Время',
                                    'Вечер',
                                    Icons.access_time_rounded)),
                          ],
                        ),
                        if (leagueName.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                AppTheme.primaryColor
                                    .withValues(alpha: 0.08),
                                AppTheme.primaryColor
                                    .withValues(alpha: 0.02),
                              ]),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.shield_rounded,
                                    color: AppTheme.primaryColor),
                                const SizedBox(width: 10),
                                Text('Лига: $leagueName',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              const SizedBox(height: 16),
              _buildAchievementsExpansion(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showInviteSheet(user);
                  },
                  icon: const Icon(Icons.sports_tennis_rounded),
                  label: const Text('Позвать играть'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openChat(user);
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('Написать сообщение'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: userId == null
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: ctx,
                            builder: (c) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(20)),
                              title:
                                  const Text('Удалить из друзей?'),
                              content: Text(
                                  'Вы точно хотите удалить $displayName из друзей?'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(c, false),
                                    child: const Text('Отмена')),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(c, true),
                                  child: const Text('Удалить',
                                      style: TextStyle(
                                          color: Colors.redAccent)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            if (ctx.mounted) Navigator.pop(ctx);
                            _removeFriend(userId);
                          }
                        },
                  icon: const Icon(Icons.person_remove_outlined,
                      color: Colors.redAccent),
                  label: const Text('Удалить из друзей',
                      style: TextStyle(color: Colors.redAccent)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent)),
                ),
              ),
              SizedBox(
                  height: MediaQuery.of(ctx).padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  // ─── Achievements section (2.7.4) ───

  Widget _buildAchievementsExpansion() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding:
            const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: const Icon(Icons.military_tech_rounded,
            color: AppTheme.primaryColor),
        title: const Text('Достижения',
            style:
                TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kAchievements
                .map((a) => _achievementCard(a))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _achievementCard(Map<String, dynamic> a) {
    final unlocked = a['unlocked'] as bool;
    final hidden = a['hidden'] == true;
    final icon = a['icon'] as IconData;
    final name = a['name'] as String;
    final desc = a['description'] as String;
    final rarity = (a['rarity'] as num?)?.toInt();

    return Container(
      width: 100,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: hidden
            ? Colors.blueGrey.withValues(alpha: 0.06)
            : unlocked
                ? AppTheme.primaryColor.withValues(alpha: 0.08)
                : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hidden
              ? Colors.blueGrey.withValues(alpha: 0.2)
              : unlocked
                  ? AppTheme.primaryColor.withValues(alpha: 0.25)
                  : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Icon(icon,
              size: 28,
              color: hidden
                  ? Colors.blueGrey.withValues(alpha: 0.4)
                  : unlocked
                      ? AppTheme.primaryColor
                      : Colors.grey),
          const SizedBox(height: 6),
          Text(name,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: hidden
                      ? Colors.blueGrey.withValues(alpha: 0.5)
                      : unlocked
                          ? null
                          : Colors.grey)),
          const SizedBox(height: 2),
          Text(hidden ? '???' : desc,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 9,
                  color: unlocked
                      ? Colors.grey[600]
                      : Colors.grey[400])),
          if (rarity != null && !hidden) ...[
            const SizedBox(height: 4),
            Text('$rarity% игроков',
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    color: rarity <= 5
                        ? Colors.amber[700]
                        : rarity <= 15
                            ? Colors.orange
                            : Colors.grey[500])),
          ],
          if (!unlocked && !hidden) ...[
            const SizedBox(height: 2),
            Icon(Icons.lock_outline_rounded,
                size: 14, color: Colors.grey[400]),
          ],
        ],
      ),
    );
  }

  // ─── Game invitation sheet (2.7.3) ───

  void _showInviteSheet(Map<String, dynamic> friend) {
    _showInviteSheetMulti([friend]);
  }

  void _showInviteSheetMulti(List<Map<String, dynamic>> initialFriends) {
    final selectedFriends = List<Map<String, dynamic>>.from(initialFriends);
    String selectedFormat = '2v2_team';
    String? selectedTemplate;
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime =
        TimeOfDay(hour: TimeOfDay.now().hour + 1, minute: 0);
    final commentCtrl = TextEditingController();
    Map<String, dynamic>? selectedCourt;
    List<Map<String, dynamic>>? courtsList;

    final courtsFuture =
        AppScope.instance.bookingRepository.courts().catchError((_) => <Map<String, dynamic>>[]);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.9),
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Text('Позвать играть',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                // Selected friends chips
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final f in selectedFriends)
                      Chip(
                        avatar: CircleAvatar(
                          backgroundImage:
                              NetworkImage(_avatarUrl(f)),
                          radius: 14,
                        ),
                        label: Text(_displayName(f),
                            style: const TextStyle(fontSize: 13)),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: selectedFriends.length > 1
                            ? () => setSheet(
                                () => selectedFriends.remove(f))
                            : null,
                        backgroundColor:
                            AppTheme.primaryColor.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.person_add_rounded,
                          size: 18, color: AppTheme.primaryColor),
                      label: const Text('Добавить',
                          style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 13)),
                      onPressed: () async {
                        final picked = await _pickFriendsDialog(
                            ctx, selectedFriends);
                        if (picked != null && picked.isNotEmpty) {
                          setSheet(() {
                            for (final p in picked) {
                              final pId = (p['id'] as num?)?.toInt();
                              final exists = selectedFriends.any((f) =>
                                  (f['id'] as num?)?.toInt() == pId);
                              if (!exists) selectedFriends.add(p);
                            }
                          });
                        }
                      },
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                            color: AppTheme.primaryColor
                                .withValues(alpha: 0.3)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const Text('Формат',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('2 на 2 (в команде)'),
                      selected: selectedFormat == '2v2_team',
                      onSelected: (_) => setSheet(
                          () => selectedFormat = '2v2_team'),
                    ),
                    ChoiceChip(
                      label: const Text('2 на 2 (против)'),
                      selected: selectedFormat == '2v2_vs',
                      onSelected: (_) => setSheet(
                          () => selectedFormat = '2v2_vs'),
                    ),
                    ChoiceChip(
                      label: const Text('Тренировка'),
                      selected: selectedFormat == 'training',
                      onSelected: (_) => setSheet(
                          () => selectedFormat = 'training'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Court selection
                const Text('Корт',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: courtsFuture,
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
                            SizedBox(width: 10),
                            Text('Загрузка кортов...',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 14)),
                          ],
                        ),
                      );
                    }
                    courtsList = snap.data ?? [];
                    if (courtsList!.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(children: [
                          Icon(Icons.info_outline,
                              size: 18, color: Colors.grey),
                          SizedBox(width: 8),
                          Text('Корты будут назначены позже',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 14)),
                        ]),
                      );
                    }
                    return DropdownButtonFormField<int>(
                      value: (selectedCourt?['id'] as num?)?.toInt(),
                      decoration: InputDecoration(
                        hintText: 'Выберите корт (опционально)',
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                        prefixIcon: const Icon(
                            Icons.sports_tennis_rounded,
                            color: AppTheme.primaryColor),
                      ),
                      items: [
                        const DropdownMenuItem<int>(
                            value: null,
                            child: Text('Не выбран')),
                        ...courtsList!.map((c) {
                          final cId =
                              (c['id'] as num?)?.toInt() ?? 0;
                          final cName =
                              (c['name'] ?? 'Корт $cId').toString();
                          return DropdownMenuItem<int>(
                              value: cId, child: Text(cName));
                        }),
                      ],
                      onChanged: (val) {
                        setSheet(() {
                          selectedCourt = val == null
                              ? null
                              : courtsList!.firstWhere(
                                  (c) =>
                                      (c['id'] as num?)?.toInt() ==
                                      val,
                                  orElse: () => <String, dynamic>{});
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),

                const Text('Быстрый выбор',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final tpl in [
                      'Играем сейчас',
                      'Завтра вечером',
                      'На выходных'
                    ])
                      ChoiceChip(
                        label: Text(tpl),
                        selected: selectedTemplate == tpl,
                        onSelected: (_) => setSheet(() {
                          selectedTemplate =
                              selectedTemplate == tpl ? null : tpl;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _pickerTile(
                        ctx: ctx,
                        icon: Icons.calendar_today_rounded,
                        label: _fmtDate(selectedDate),
                        onTap: () => _showDateSheet(
                            ctx, selectedDate, (d) {
                          setSheet(() => selectedDate = d);
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _pickerTile(
                        ctx: ctx,
                        icon: Icons.access_time_rounded,
                        label:
                            '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                        onTap: () => _showTimeSheet(
                            ctx, selectedTime, (t) {
                          setSheet(() => selectedTime = t);
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commentCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Комментарий (опционально)',
                    filled: true,
                    fillColor:
                        Colors.grey.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      final names = selectedFriends
                          .map((f) => _displayName(f))
                          .join(', ');
                      final courtInfo = selectedCourt != null
                          ? ' на ${selectedCourt!['name'] ?? 'корт'}'
                          : '';
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Приглашение отправлено: $names$courtInfo')));
                    },
                    icon: const Icon(Icons.send_rounded),
                    label: Text(selectedFriends.length > 1
                        ? 'Пригласить ${selectedFriends.length} друзей'
                        : 'Отправить приглашение'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>?> _pickFriendsDialog(
      BuildContext ctx,
      List<Map<String, dynamic>> alreadySelected) async {
    final allFriends = await _friendsFuture;
    final alreadyIds =
        alreadySelected.map((f) => (f['id'] as num?)?.toInt()).toSet();
    final available = allFriends
        .where((f) => !alreadyIds.contains((f['id'] as num?)?.toInt()))
        .toList();

    if (available.isEmpty) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('Все друзья уже добавлены')));
      }
      return null;
    }

    final selected = <Map<String, dynamic>>{};

    return showDialog<List<Map<String, dynamic>>>(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDlg) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Добавить друзей'),
          content: SizedBox(
            width: double.maxFinite,
            height: 340,
            child: ListView.builder(
              itemCount: available.length,
              itemBuilder: (_, i) {
                final f = available[i];
                final isChecked = selected.contains(f);
                return CheckboxListTile(
                  value: isChecked,
                  activeColor: AppTheme.primaryColor,
                  secondary: CircleAvatar(
                      radius: 18,
                      backgroundImage: NetworkImage(_avatarUrl(f))),
                  title: Text(_displayName(f),
                      style: const TextStyle(fontSize: 14)),
                  onChanged: (v) {
                    setDlg(() {
                      if (v == true) {
                        selected.add(f);
                      } else {
                        selected.remove(f);
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('Отмена')),
            ElevatedButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(dCtx, selected.toList()),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white),
              child: Text('Добавить (${selected.length})'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Privacy settings sheet ───

  void _showPrivacySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Настройки приватности',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Показывать профиль всем'),
                value: _privacyShowProfile,
                activeColor: AppTheme.primaryColor,
                onChanged: (v) => setSheet(
                    () => _privacyShowProfile = v),
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title:
                    const Text('Показывать статистику друзьям'),
                value: _privacyShowStats,
                activeColor: AppTheme.primaryColor,
                onChanged: (v) =>
                    setSheet(() => _privacyShowStats = v),
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                    'Показывать в ленте активности'),
                value: _privacyShowFeed,
                activeColor: AppTheme.primaryColor,
                onChanged: (v) =>
                    setSheet(() => _privacyShowFeed = v),
              ),
              SizedBox(
                  height:
                      MediaQuery.of(ctx).padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
  }

  void _openChat(Map<String, dynamic> user, {Map<String, dynamic>? conversation}) {
    final fullName = (user['full_name'] ?? '').toString().trim();
    final name = fullName.isNotEmpty
        ? fullName
        : '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
    final avatar = user['avatar']?.toString();
    final userId = (user['id'] as num?)?.toInt();
    final avatarUrl = (avatar != null && avatar.isNotEmpty)
        ? avatar
        : 'https://i.pravatar.cc/150?img=${(userId ?? 1) % 70}';

    final convId = (conversation?['id'] as num?)?.toInt();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          friend: {
            'id': userId,
            'name': name.isNotEmpty
                ? name
                : (user['username'] ?? '').toString(),
            'avatar': avatarUrl,
            'status': 'offline',
          },
          conversationId: convId,
        ),
      ),
    );
  }

  // ─── Lobby creation sheet ───

  Future<void> _showCreateLobbySheet() async {
    final titleCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    final eloMinCtrl = TextEditingController();
    final eloMaxCtrl = TextEditingController();
    String format = 'DOUBLE';
    int? selectedTrainerId;
    List<Map<String, dynamic>> coaches = [];
    try {
      coaches = await AppScope.instance.authRepository.coaches();
    } catch (_) {}

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: BoxDecoration(
              color: Theme.of(ctx).cardColor,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius:
                                BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Text('Создать лобби',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    hintText: 'Название игры...',
                    filled: true,
                    fillColor:
                        Colors.grey.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Формат',
                    style:
                        TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(children: [
                  ChoiceChip(
                      label: const Text('2v2 (Парный)'),
                      selected: format == 'DOUBLE',
                      onSelected: (_) => setModalState(
                          () => format = 'DOUBLE')),
                  const SizedBox(width: 8),
                  ChoiceChip(
                      label: const Text('1v1 (Одиночный)'),
                      selected: format == 'SINGLE',
                      onSelected: (_) => setModalState(
                          () => format = 'SINGLE')),
                ]),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: eloMinCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'ELO min (опц.)',
                          filled: true,
                          fillColor: Colors.grey
                              .withValues(alpha: 0.1),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: eloMaxCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'ELO max (опц.)',
                          filled: true,
                          fillColor: Colors.grey
                              .withValues(alpha: 0.1),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Trainer selection
                if (coaches.isNotEmpty) ...[
                  const Text('Тренер',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: selectedTrainerId,
                    decoration: InputDecoration(
                      hintText: 'Без тренера',
                      filled: true,
                      fillColor: Colors.grey.withValues(alpha: 0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.sports_rounded, size: 20),
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Без тренера',
                            style: TextStyle(color: Colors.grey)),
                      ),
                      ...coaches.map((c) {
                        final cId = (c['id'] as num).toInt();
                        final name = (c['full_name'] ??
                                c['username'] ??
                                'Тренер $cId')
                            .toString();
                        return DropdownMenuItem<int>(
                            value: cId, child: Text(name));
                      }),
                    ],
                    onChanged: (v) =>
                        setModalState(() => selectedTrainerId = v),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: commentCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Комментарий (опционально)',
                    filled: true,
                    fillColor:
                        Colors.grey.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                    format == 'DOUBLE'
                        ? 'Игроков: 4 (включая вас)'
                        : 'Игроков: 2 (включая вас)',
                    style:
                        const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty) return;
                      Navigator.of(ctx).pop();
                      try {
                        final payload = <String, dynamic>{
                          'title': titleCtrl.text.trim(),
                          'game_format': format,
                        };
                        final min = int.tryParse(
                            eloMinCtrl.text.trim());
                        final max = int.tryParse(
                            eloMaxCtrl.text.trim());
                        if (min != null) payload['elo_min'] = min;
                        if (max != null) payload['elo_max'] = max;
                        if (commentCtrl.text.trim().isNotEmpty) {
                          payload['comment'] =
                              commentCtrl.text.trim();
                        }
                        if (selectedTrainerId != null) {
                          payload['trainer'] = selectedTrainerId;
                        }
                        final lobby = await AppScope
                            .instance.socialRepository
                            .createLobby(payload);
                        if (!mounted) return;
                        setState(_reloadAll);
                        final newId =
                            (lobby['id'] as num?)?.toInt();
                        if (newId != null) {
                          _openLobbyDetail(newId);
                        }
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(e.toString())));
                      }
                    },
                    child: const Text('Создать'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor =
        isDark ? AppTheme.accentColor : AppTheme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сообщество'),
        actions: [
          if (_tabs.index == 1)
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 22),
              tooltip: 'Настройки приватности',
              onPressed: _showPrivacySheet,
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: activeColor,
          indicatorColor: activeColor,
          tabs: const [
            Tab(text: 'Лобби'),
            Tab(text: 'Друзья'),
            Tab(text: 'Лента'),
            Tab(text: 'Сообщения'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateLobbySheet,
        backgroundColor: activeColor,
        icon: Icon(Icons.add,
            color: isDark ? AppTheme.primaryColor : Colors.white),
        label: Text('Создать',
            style: TextStyle(
                color:
                    isDark ? AppTheme.primaryColor : Colors.white,
                fontWeight: FontWeight.bold)),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildLobbyTab(),
          _buildFriendsTab(),
          _buildFeedTab(),
          _buildMessagesTab(),
        ],
      ),
    );
  }

  // ─── TAB 1: Лобби ───

  Widget _buildLobbyTab() {
    return RefreshIndicator(
      onRefresh: () async => setState(_reloadAll),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _myLobbiesFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: LinearProgressIndicator());
              }
              final myLobbies = snap.data ?? [];
              if (myLobbies.isEmpty) return const SizedBox.shrink();
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Мои лобби',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                    const SizedBox(height: 8),
                    ...myLobbies
                        .map((l) => _lobbyCard(l, isMine: true)),
                    const SizedBox(height: 20),
                  ]);
            },
          ),
          const Text('Открытые лобби',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _openLobbiesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return _errorWidget(
                    snapshot.error, () => setState(_reloadAll));
              }
              final lobbies = (snapshot.data ?? const [])
                  .where((l) =>
                      (l['status'] ?? '').toString() != 'CLOSED')
                  .toList();
              if (lobbies.isEmpty) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        Icon(Icons.sports_tennis_rounded,
                            size: 56,
                            color: Colors.grey
                                .withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        const Text('Открытых лобби нет',
                            style:
                                TextStyle(color: Colors.grey)),
                        const SizedBox(height: 4),
                        const Text('Создайте первое!',
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12)),
                      ])),
                );
              }
              return Column(
                  children: lobbies
                      .map((l) => _lobbyCard(l, isMine: false))
                      .toList());
            },
          ),
        ],
      ),
    );
  }

  Widget _lobbyCard(Map<String, dynamic> l,
      {required bool isMine}) {
    final id = (l['id'] as num?)?.toInt();
    final title = (l['title'] ?? 'Лобби').toString();
    final status = (l['status'] ?? '').toString();
    final participants =
        ((l['participants'] as List?) ?? const []).length;
    final players = (l['players_count'] as num?)?.toInt() ??
        (l['current_players_count'] as num?)?.toInt() ??
        participants;
    final maxPlayers =
        (l['max_players'] as num?)?.toInt() ?? 4;
    final isFull = maxPlayers > 0 && players >= maxPlayers;
    final canJoin = status == 'OPEN' || status == 'WAITING';
    final statusColor = _cardStatusColor(status);

    return GestureDetector(
      onTap: id == null ? null : () => _openLobbyDetail(id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
          border: isMine
              ? Border.all(
                  color: AppTheme.primaryColor
                      .withValues(alpha: 0.3),
                  width: 1.5)
              : null,
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16))),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color:
                          statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(_statusLabel(status),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor)),
                ),
              ]),
              const SizedBox(height: 10),
              Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      ...List.generate(
                          maxPlayers,
                          (i) => Padding(
                              padding: const EdgeInsets.only(
                                  right: 4),
                              child: Icon(Icons.person,
                                  size: 20,
                                  color: i < players
                                      ? AppTheme.primaryColor
                                      : Colors.grey.withValues(
                                          alpha: 0.3)))),
                      const SizedBox(width: 6),
                      Text('$players/$maxPlayers',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ]),
                    if (!isMine &&
                        !isFull &&
                        canJoin &&
                        id != null)
                      ElevatedButton(
                          onPressed: () => _joinLobby(id),
                          style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 8),
                              minimumSize:
                                  const Size(0, 36)),
                          child: const Text('Вступить',
                              style: TextStyle(fontSize: 13)))
                    else
                      const Icon(Icons.chevron_right_rounded,
                          color: Colors.grey),
                  ]),
            ]),
      ),
    );
  }

  // ─── TAB 2: Друзья + заявки (enhanced 2.7.1) ───

  Widget _buildFriendsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Поиск по имени или телефону...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Все'),
                selected: _friendsSort == 'all',
                onSelected: (_) =>
                    setState(() => _friendsSort = 'all'),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('По рейтингу'),
                selected: _friendsSort == 'rating',
                onSelected: (_) =>
                    setState(() => _friendsSort = 'rating'),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('По имени'),
                selected: _friendsSort == 'name',
                onSelected: (_) =>
                    setState(() => _friendsSort = 'name'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => setState(_reloadAll),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _searchFuture,
              builder: (context, searchSnap) {
                final results = searchSnap.data ?? const [];
                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _friendsFuture,
                  builder: (context, friendsSnap) {
                    if (friendsSnap.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    final rawFriends =
                        friendsSnap.data ?? const [];
                    final isSearching =
                        _searchController.text.trim().isNotEmpty;
                    final friends = isSearching
                        ? results
                        : _sortFriends(List.of(rawFriends));

                    return FutureBuilder<
                        List<Map<String, dynamic>>>(
                      future: _incomingFuture,
                      builder: (context, inSnap) {
                        final incoming =
                            inSnap.data ?? const [];

                        return FutureBuilder<
                            List<Map<String, dynamic>>>(
                          future: _outgoingFuture,
                          builder: (context, outSnap) {
                            final outgoing =
                                outSnap.data ?? const [];

                            if (friends.isEmpty &&
                                incoming.isEmpty &&
                                outgoing.isEmpty) {
                              return Center(
                                  child: Column(
                                      mainAxisSize:
                                          MainAxisSize.min,
                                      children: [
                                    Icon(
                                        Icons.people_outline,
                                        size: 56,
                                        color: Colors.grey
                                            .withValues(
                                                alpha: 0.4)),
                                    const SizedBox(height: 8),
                                    Text(
                                        isSearching
                                            ? 'Ничего не найдено'
                                            : 'Пока нет друзей',
                                        style:
                                            const TextStyle(
                                                color: Colors
                                                    .grey)),
                                  ]));
                            }

                            return ListView(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 16),
                              children: [
                                ...friends
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                  final u = entry.value;
                                  final userId =
                                      (u['id'] as num?)
                                          ?.toInt();
                                  final name =
                                      _displayName(u);

                                  return Column(children: [
                                    ListTile(
                                      contentPadding:
                                          EdgeInsets.zero,
                                      leading:
                                          _avatarWithStatus(
                                              u,
                                              radius: 22),
                                      title: Text(name,
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight
                                                      .w600)),
                                      subtitle: Row(
                                        children: [
                                          Text(
                                              (u['username'] ??
                                                      '')
                                                  .toString(),
                                              style: const TextStyle(
                                                  fontSize:
                                                      12,
                                                  color: Colors
                                                      .grey)),
                                          if (!isSearching &&
                                              u['rating_elo'] !=
                                                  null) ...[
                                            const SizedBox(
                                                width: 8),
                                            Container(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal:
                                                      6,
                                                  vertical:
                                                      1),
                                              decoration:
                                                  BoxDecoration(
                                                color: AppTheme
                                                    .primaryColor
                                                    .withValues(
                                                        alpha:
                                                            0.1),
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(
                                                            6),
                                              ),
                                              child: Text(
                                                  'ELO ${u['rating_elo']}',
                                                  style: const TextStyle(
                                                      fontSize:
                                                          10,
                                                      fontWeight:
                                                          FontWeight
                                                              .w600,
                                                      color:
                                                          AppTheme.primaryColor)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      trailing: isSearching
                                          ? IconButton(
                                              icon: const Icon(
                                                  Icons
                                                      .person_add_alt_1_rounded,
                                                  color: AppTheme
                                                      .primaryColor),
                                              onPressed: userId ==
                                                      null
                                                  ? null
                                                  : () =>
                                                      _sendFriendRequest(
                                                          userId))
                                          : const Icon(
                                              Icons
                                                  .chevron_right_rounded,
                                              color:
                                                  Colors.grey,
                                              size: 20),
                                      onTap: isSearching
                                          ? null
                                          : () =>
                                              _showFriendProfile(
                                                  u),
                                    ),
                                    if (entry.key <
                                            friends.length -
                                                1 ||
                                        incoming
                                            .isNotEmpty ||
                                        outgoing.isNotEmpty)
                                      const Divider(
                                          height: 1),
                                  ]);
                                }),

                                // Incoming requests
                                if (incoming.isNotEmpty &&
                                    !isSearching) ...[
                                  const SizedBox(height: 16),
                                  _requestsSection(
                                    icon: Icons
                                        .person_add_rounded,
                                    title:
                                        'Заявки в друзья (${incoming.length})',
                                    children: incoming
                                        .map((req) =>
                                            _incomingRequestTile(
                                                req))
                                        .toList(),
                                  ),
                                ],

                                // Outgoing requests
                                if (outgoing.isNotEmpty &&
                                    !isSearching) ...[
                                  const SizedBox(height: 12),
                                  _requestsSection(
                                    icon: Icons
                                        .arrow_forward_rounded,
                                    title:
                                        'Исходящие заявки (${outgoing.length})',
                                    children: outgoing
                                        .map((req) =>
                                            _outgoingRequestTile(
                                                req))
                                        .toList(),
                                  ),
                                ],
                                const SizedBox(height: 80),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _sortFriends(
      List<Map<String, dynamic>> friends) {
    switch (_friendsSort) {
      case 'rating':
        friends.sort((a, b) {
          final ra = (a['rating_elo'] as num?)?.toDouble() ?? 0;
          final rb = (b['rating_elo'] as num?)?.toDouble() ?? 0;
          return rb.compareTo(ra);
        });
        return friends;
      case 'name':
        friends.sort((a, b) {
          final na = _displayName(a).toLowerCase();
          final nb = _displayName(b).toLowerCase();
          return na.compareTo(nb);
        });
        return friends;
      default:
        return friends;
    }
  }

  Widget _requestsSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
            const SizedBox(height: 12),
            ...children,
          ]),
    );
  }

  Widget _incomingRequestTile(Map<String, dynamic> req) {
    final reqId = (req['id'] as num?)?.toInt();
    final from =
        (req['from_user'] as Map?)?.cast<String, dynamic>() ?? {};
    final fromName = _displayName(from);
    final fromAvatarUrl = _avatarUrl(from);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(fromAvatarUrl)),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(fromName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600)),
              Text((from['username'] ?? '').toString(),
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey)),
            ])),
        IconButton(
          icon: const Icon(Icons.check_circle_rounded,
              color: Colors.green),
          onPressed: reqId == null
              ? null
              : () => _respondRequest(reqId, 'accept'),
          tooltip: 'Принять',
        ),
        IconButton(
          icon: const Icon(Icons.cancel_rounded,
              color: Colors.redAccent),
          onPressed: reqId == null
              ? null
              : () => _respondRequest(reqId, 'reject'),
          tooltip: 'Отклонить',
        ),
      ]),
    );
  }

  Widget _outgoingRequestTile(Map<String, dynamic> req) {
    final reqId = (req['id'] as num?)?.toInt();
    final toUser =
        (req['to_user'] as Map?)?.cast<String, dynamic>() ?? {};
    final toName = _displayName(toUser);
    final toAvatarUrl = _avatarUrl(toUser);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(toAvatarUrl)),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(toName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600)),
              Text((toUser['username'] ?? '').toString(),
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey)),
            ])),
        TextButton.icon(
          icon: const Icon(Icons.close_rounded,
              size: 18, color: Colors.redAccent),
          label: const Text('Отменить',
              style:
                  TextStyle(color: Colors.redAccent, fontSize: 12)),
          onPressed:
              reqId == null ? null : () => _cancelRequest(reqId),
        ),
      ]),
    );
  }

  // ─── TAB 3: Лента активности (2.7.5) ───

  Widget _buildFeedTab() {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              for (final entry in _kFeedFilters.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(entry.value['icon'] as IconData,
                        size: 16,
                        color: _feedFilter == entry.key
                            ? Colors.white
                            : Colors.grey),
                    label: Text(entry.value['label'] as String),
                    selected: _feedFilter == entry.key,
                    onSelected: (_) =>
                        setState(() => _feedFilter = entry.key),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _feedFuture = AppScope.instance.socialRepository
                    .friendsFeed(limit: 20);
              });
            },
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _feedFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _errorWidget(snap.error, () {
                    setState(() {
                      _feedFuture = AppScope
                          .instance.socialRepository
                          .friendsFeed(limit: 20);
                    });
                  });
                }
                final allItems = snap.data ?? const [];
                final items = _feedFilter == 'all'
                    ? allItems
                    : allItems
                        .where((it) =>
                            (it['type'] ?? '').toString().toUpperCase() ==
                            _feedFilter.toUpperCase())
                        .toList();
                if (allItems.isEmpty) {
                  return Center(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        Icon(Icons.dynamic_feed_rounded,
                            size: 56,
                            color:
                                Colors.grey.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        const Text(
                            'Лента активности пуста.\nДобавьте друзей!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey)),
                      ]));
                }
                if (items.isEmpty) {
                  return Center(
                      child: Text(
                          'Нет записей типа «${_kFeedFilters[_feedFilter]?['label'] ?? _feedFilter}»',
                          style: const TextStyle(color: Colors.grey)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, i) =>
                      _feedCard(items[i]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _feedCard(Map<String, dynamic> item) {
    final id = (item['id'] as num?)?.toInt() ?? 0;
    final type = (item['type'] ?? '').toString();
    final text = (item['description'] ?? item['text'] ?? '').toString();
    final userName =
        (item['user_name'] ?? '').toString();
    final userAvatar =
        (item['user_avatar'] ?? '').toString();
    final createdAt =
        (item['date'] ?? item['created_at'] ?? '').toString();
    final liked = _likedFeedItems.contains(id);
    final avatarUrl = userAvatar.isNotEmpty
        ? userAvatar
        : 'https://i.pravatar.cc/150?img=${id % 70}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(avatarUrl)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                  Text(userName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600)),
                  Text(_relativeTime(createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                ])),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _feedTypeColor(type)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_feedTypeIcon(type),
                  size: 18, color: _feedTypeColor(type)),
            ),
          ]),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() {
                    if (liked) {
                      _likedFeedItems.remove(id);
                    } else {
                      _likedFeedItems.add(id);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          liked
                              ? Icons.favorite_rounded
                              : Icons
                                  .favorite_border_rounded,
                          size: 20,
                          color: liked
                              ? Colors.redAccent
                              : Colors.grey),
                      const SizedBox(width: 4),
                      Text(liked ? '1' : '',
                          style: TextStyle(
                              fontSize: 12,
                              color: liked
                                  ? Colors.redAccent
                                  : Colors.grey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _showInviteSheet({
                  'first_name': userName,
                  'avatar': userAvatar,
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sports_tennis_rounded,
                          size: 18,
                          color: AppTheme.primaryColor),
                      const SizedBox(width: 4),
                      Text('Позвать играть',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── TAB 4: Сообщения (чаты с друзьями) ───

  Widget _buildMessagesTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _conversationsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _buildMessagesFromFriends();
        }
        final conversations = snap.data ?? const [];
        if (conversations.isEmpty) {
          return _buildMessagesFromFriends();
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reloadAll),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: conversations.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1),
            itemBuilder: (context, i) {
              final conv = conversations[i];
              final companion = (conv['companion'] as Map?)?.cast<String, dynamic>() ?? const {};
              final last = (conv['last_message'] as Map?)?.cast<String, dynamic>() ?? const {};
              final unread = (conv['unread_count'] as num?)?.toInt() ?? 0;

              final name = (companion['full_name'] ??
                      '${companion['first_name'] ?? ''} ${companion['last_name'] ?? ''}')
                  .toString()
                  .trim();
              final phone = (companion['phone_number'] ?? '').toString();
              final avatar = (companion['avatar'] ?? '').toString();
              final lastText = (last['text'] ?? '').toString();

              String subtitle;
              if (lastText.isNotEmpty) {
                subtitle = lastText;
              } else if (phone.isNotEmpty) {
                subtitle = phone;
              } else {
                subtitle = 'Нажмите, чтобы открыть диалог';
              }

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _avatarWithStatus({
                  'id': (companion['id'] as num?),
                  'avatar': avatar,
                  'first_name': companion['first_name'],
                  'last_name': companion['last_name'],
                }, radius: 24),
                title: Text(name.isEmpty ? 'Игрок клуба' : name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600)),
                subtitle: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey),
                ),
                trailing: unread > 0
                    ? CircleAvatar(
                        radius: 11,
                        backgroundColor: AppTheme.primaryColor,
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      )
                    : const Icon(
                        Icons.chat_bubble_rounded,
                        size: 18,
                        color: AppTheme.primaryColor),
                onTap: () => _openChat(companion, conversation: conv),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMessagesFromFriends() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _friendsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final friends = snap.data ?? const [];
        if (friends.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 56, color: Colors.grey.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              const Text('Нет чатов', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 4),
              const Text('Добавьте друзей чтобы начать общение',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reloadAll),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: friends.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final u = friends[i];
              final displayName = _displayName(u);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _avatarWithStatus(u, radius: 24),
                title: Text(displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Нажмите чтобы написать',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                trailing: const Icon(Icons.chat_bubble_rounded,
                    size: 18, color: AppTheme.primaryColor),
                onTap: () => _openChat(u),
              );
            },
          ),
        );
      },
    );
  }

  Widget _errorWidget(Object? e, VoidCallback retry) {
    return Center(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          const Text('Ошибка загрузки'),
          const SizedBox(height: 8),
          Text(e.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          ElevatedButton(
              onPressed: retry, child: const Text('Повторить')),
        ]));
  }
}

// ─── Static achievements data (2.7.4) — 24 achievements ───

const List<Map<String, dynamic>> _kAchievements = [
  // ── Victories ──
  {'name': 'Первая победа', 'icon': Icons.emoji_events, 'description': 'Выиграть первый матч', 'unlocked': true, 'rarity': 92},
  {'name': 'Серийный победитель', 'icon': Icons.local_fire_department, 'description': '5 побед подряд', 'unlocked': false, 'rarity': 18},
  {'name': 'Непобедимый', 'icon': Icons.shield_rounded, 'description': '10 побед подряд', 'unlocked': false, 'rarity': 5},
  {'name': 'Сотня побед', 'icon': Icons.military_tech_rounded, 'description': '100 побед всего', 'unlocked': false, 'rarity': 8},
  // ── Activity & attendance ──
  {'name': 'Завсегдатай', 'icon': Icons.calendar_month, 'description': '30 дней подряд', 'unlocked': false, 'rarity': 12},
  {'name': 'Ранняя пташка', 'icon': Icons.wb_sunny_rounded, 'description': '10 игр до 10 утра', 'unlocked': true, 'rarity': 25},
  {'name': 'Ночная сова', 'icon': Icons.nightlight_round, 'description': '10 игр после 21:00', 'unlocked': false, 'rarity': 15},
  {'name': 'Марафонец', 'icon': Icons.directions_run_rounded, 'description': '50 часов на корте', 'unlocked': false, 'rarity': 10},
  // ── Social ──
  {'name': 'Командный игрок', 'icon': Icons.people, 'description': '50 парных матчей', 'unlocked': true, 'rarity': 20},
  {'name': 'Душа компании', 'icon': Icons.groups_rounded, 'description': '20 друзей в клубе', 'unlocked': false, 'rarity': 14},
  {'name': 'Наставник', 'icon': Icons.school_rounded, 'description': 'Пригласить 5 новичков', 'unlocked': false, 'rarity': 7},
  {'name': 'Организатор', 'icon': Icons.event_rounded, 'description': 'Создать 10 лобби', 'unlocked': true, 'rarity': 22},
  // ── Rating & leagues ──
  {'name': 'Новая лига', 'icon': Icons.arrow_upward, 'description': 'Повышение ранга', 'unlocked': true, 'rarity': 45},
  {'name': 'Топ-10', 'icon': Icons.leaderboard_rounded, 'description': 'Войти в топ-10 рейтинга', 'unlocked': false, 'rarity': 3},
  {'name': 'ELO 1500+', 'icon': Icons.trending_up_rounded, 'description': 'Достичь рейтинга 1500', 'unlocked': false, 'rarity': 11},
  {'name': 'Чемпион сезона', 'icon': Icons.workspace_premium_rounded, 'description': 'Выиграть сезон лиги', 'unlocked': false, 'rarity': 2},
  // ── Tournaments ──
  {'name': 'Турнирный боец', 'icon': Icons.emoji_events_rounded, 'description': 'Участие в 5 турнирах', 'unlocked': false, 'rarity': 16},
  {'name': 'Финалист', 'icon': Icons.stars_rounded, 'description': 'Дойти до финала турнира', 'unlocked': false, 'rarity': 6},
  // ── Special ──
  {'name': 'Камбэк', 'icon': Icons.replay_rounded, 'description': 'Победить проигрывая 0-5', 'unlocked': false, 'rarity': 4},
  {'name': 'Без потерь', 'icon': Icons.verified_rounded, 'description': 'Выиграть 6-0 / 6-0', 'unlocked': false, 'rarity': 9},
  {'name': 'Первый абонемент', 'icon': Icons.card_membership_rounded, 'description': 'Оформить абонемент', 'unlocked': true, 'rarity': 68},
  {'name': 'Отзывчивый', 'icon': Icons.rate_review_rounded, 'description': 'Оставить 10 отзывов', 'unlocked': false, 'rarity': 13},
  // ── Hidden achievements ──
  {'name': '???', 'icon': Icons.help_outline_rounded, 'description': 'Секретное достижение', 'unlocked': false, 'hidden': true, 'rarity': 1},
  {'name': '???', 'icon': Icons.help_outline_rounded, 'description': 'Секретное достижение', 'unlocked': false, 'hidden': true, 'rarity': 1},
];

const Map<String, Map<String, dynamic>> _kFeedFilters = {
  'all': {'label': 'Все', 'icon': Icons.dynamic_feed_rounded},
  'MATCH': {'label': 'Матчи', 'icon': Icons.sports_tennis},
  'ACHIEVEMENT': {'label': 'Достижения', 'icon': Icons.star_rounded},
  'RANK': {'label': 'Ранг', 'icon': Icons.arrow_upward_rounded},
  'TOURNAMENT': {'label': 'Турниры', 'icon': Icons.emoji_events_rounded},
};

// ─── Feed helpers ───

IconData _feedTypeIcon(String type) {
  switch (type.toUpperCase()) {
    case 'MATCH':
      return Icons.sports_tennis;
    case 'ACHIEVEMENT':
      return Icons.star_rounded;
    case 'RANK':
      return Icons.arrow_upward_rounded;
    case 'TOURNAMENT':
      return Icons.emoji_events_rounded;
    default:
      return Icons.notifications_rounded;
  }
}

Color _feedTypeColor(String type) {
  switch (type.toUpperCase()) {
    case 'MATCH':
      return Colors.blue;
    case 'ACHIEVEMENT':
      return Colors.amber;
    case 'RANK':
      return Colors.green;
    case 'TOURNAMENT':
      return Colors.purple;
    default:
      return Colors.grey;
  }
}

String _relativeTime(String? createdAt) {
  if (createdAt == null || createdAt.isEmpty) return '';
  final dt = DateTime.tryParse(createdAt);
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'только что';
  if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
  if (diff.inHours < 24) return '${diff.inHours} ч назад';
  if (diff.inDays < 7) return '${diff.inDays} дн назад';
  return _fmtDate(dt);
}

// ─── Top-level helpers (preserved) ───

Color _cardStatusColor(String status) {
  switch (status) {
    case 'OPEN':
      return Colors.green;
    case 'WAITING':
      return Colors.orange;
    case 'NEGOTIATING':
      return Colors.blue;
    case 'BOOKED':
      return Colors.purple;
    case 'READY':
      return Colors.teal;
    case 'PAID':
      return Colors.green;
    case 'CLOSED':
      return Colors.grey;
    default:
      return Colors.grey;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'OPEN':
      return 'Открыто';
    case 'WAITING':
      return 'Ожидание';
    case 'NEGOTIATING':
      return 'Согласование';
    case 'BOOKED':
      return 'Забронировано';
    case 'READY':
      return 'Готово';
    case 'PAID':
      return 'Оплачено';
    case 'CLOSED':
      return 'Завершено';
    default:
      return status;
  }
}

Widget _pickerTile(
    {required BuildContext ctx,
    required IconData icon,
    required String label,
    required VoidCallback onTap}) {
  final isDark = Theme.of(ctx).brightness == Brightness.dark;
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14))),
        Icon(Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: Colors.grey.withValues(alpha: 0.6)),
      ]),
    ),
  );
}

String _fmtDate(DateTime d) {
  const months = [
    'янв', 'фев', 'мар', 'апр', 'май', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
  ];
  return '${d.day} ${months[d.month - 1]}';
}

void _showDateSheet(BuildContext ctx, DateTime current,
    ValueChanged<DateTime> onPicked) {
  DateTime temp = current;
  showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      height: 320,
      decoration: BoxDecoration(
          color: Theme.of(sheetCtx).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24))),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Выберите дату',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17)),
                TextButton(
                    onPressed: () {
                      onPicked(temp);
                      Navigator.pop(sheetCtx);
                    },
                    child: const Text('Готово',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16))),
              ]),
        ),
        Expanded(
            child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: current,
                minimumDate: DateTime.now()
                    .subtract(const Duration(days: 1)),
                maximumDate:
                    DateTime.now().add(const Duration(days: 60)),
                onDateTimeChanged: (d) => temp = d)),
      ]),
    ),
  );
}

void _showTimeSheet(BuildContext ctx, TimeOfDay current,
    ValueChanged<TimeOfDay> onPicked) {
  DateTime temp =
      DateTime(2025, 1, 1, current.hour, current.minute);
  showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      height: 320,
      decoration: BoxDecoration(
          color: Theme.of(sheetCtx).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24))),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Выберите время',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17)),
                TextButton(
                    onPressed: () {
                      onPicked(TimeOfDay(
                          hour: temp.hour,
                          minute: temp.minute));
                      Navigator.pop(sheetCtx);
                    },
                    child: const Text('Готово',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16))),
              ]),
        ),
        Expanded(
            child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: temp,
                use24hFormat: true,
                minuteInterval: 15,
                onDateTimeChanged: (d) => temp = d)),
      ]),
    ),
  );
}
