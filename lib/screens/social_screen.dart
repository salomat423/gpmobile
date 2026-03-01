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

class _SocialScreenState extends State<SocialScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<List<Map<String, dynamic>>> _openLobbiesFuture;
  late Future<List<Map<String, dynamic>>> _myLobbiesFuture;
  late Future<List<Map<String, dynamic>>> _friendsFuture;
  late Future<List<Map<String, dynamic>>> _incomingFuture;
  late Future<List<Map<String, dynamic>>> _searchFuture;

  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _reloadAll();
    _searchFuture = Future.value(const []);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _reloadAll() {
    _openLobbiesFuture = AppScope.instance.socialRepository.listLobbies(status: 'OPEN');
    _myLobbiesFuture = AppScope.instance.socialRepository.myLobbies();
    _friendsFuture = AppScope.instance.socialRepository.friends();
    _incomingFuture = AppScope.instance.socialRepository.incomingRequests();
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
      messenger.showSnackBar(const SnackBar(content: Text('Заявка отправлена')));
      setState(_reloadAll);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _respondRequest(int requestId, String action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.instance.socialRepository.respondRequest(requestId, action);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(action == 'accept' ? 'Заявка принята' : 'Заявка отклонена')));
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
      messenger.showSnackBar(const SnackBar(content: Text('Друг удалён')));
      setState(_reloadAll);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  // ─── Lobby actions ───

  Future<void> _joinLobby(int id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.instance.socialRepository.joinLobby(id);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Вы вступили в лобби')));
      setState(_reloadAll);
      _openLobbyDetail(id);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _openLobbyDetail(int id) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => LobbyDetailScreen(lobbyId: id)));
    if (!mounted) return;
    setState(_reloadAll);
  }

  // ─── Friend profile bottom sheet ───

  void _showFriendProfile(Map<String, dynamic> user) {
    final userId = (user['id'] as num?)?.toInt();
    final name = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
    final displayName = name.isEmpty ? (user['username'] ?? '').toString() : name;
    final phone = (user['phone_number'] ?? user['username'] ?? '').toString();
    final avatar = user['avatar']?.toString();
    final elo = (user['rating_elo'] ?? user['elo'] ?? '—').toString();
    final avatarUrl = (avatar != null && avatar.isNotEmpty) ? avatar : 'https://i.pravatar.cc/150?img=${(userId ?? 1) % 70}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            CircleAvatar(radius: 44, backgroundImage: NetworkImage(avatarUrl)),
            const SizedBox(height: 16),
            Text(displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (phone.isNotEmpty)
              Text(phone, style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events_rounded, size: 20, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text('ELO $elo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
                ],
              ),
            ),
            const SizedBox(height: 24),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Text('Удалить из друзей?'),
                            content: Text('Вы точно хотите удалить $displayName из друзей?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
                              TextButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Удалить', style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          _removeFriend(userId);
                        }
                      },
                icon: const Icon(Icons.person_remove_outlined, color: Colors.redAccent),
                label: const Text('Удалить из друзей', style: TextStyle(color: Colors.redAccent)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  void _openChat(Map<String, dynamic> user) {
    final name = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
    final avatar = user['avatar']?.toString();
    final userId = (user['id'] as num?)?.toInt();
    final avatarUrl = (avatar != null && avatar.isNotEmpty) ? avatar : 'https://i.pravatar.cc/150?img=${(userId ?? 1) % 70}';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          friend: {
            'id': userId,
            'name': name.isEmpty ? (user['username'] ?? '').toString() : name,
            'avatar': avatarUrl,
            'status': 'offline',
          },
        ),
      ),
    );
  }

  // ─── Lobby creation sheet ───

  void _showCreateLobbySheet() {
    final titleCtrl = TextEditingController();
    String format = 'DOUBLE';
    int? selectedCourtId;
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = const TimeOfDay(hour: 18, minute: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: BoxDecoration(color: Theme.of(ctx).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Text('Создать лобби', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    hintText: 'Название игры...',
                    filled: true,
                    fillColor: Colors.grey.withValues(alpha: 0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Формат', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(children: [
                  ChoiceChip(label: const Text('2v2 (Парный)'), selected: format == 'DOUBLE', onSelected: (_) => setModalState(() => format = 'DOUBLE')),
                  const SizedBox(width: 8),
                  ChoiceChip(label: const Text('1v1 (Одиночный)'), selected: format == 'SINGLE', onSelected: (_) => setModalState(() => format = 'SINGLE')),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _pickerTile(ctx: ctx, icon: Icons.calendar_today_rounded, label: _fmtDate(selectedDate), onTap: () => _showDateSheet(ctx, selectedDate, (d) => setModalState(() => selectedDate = d)))),
                  const SizedBox(width: 8),
                  Expanded(child: _pickerTile(ctx: ctx, icon: Icons.schedule_rounded, label: '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}', onTap: () => _showTimeSheet(ctx, selectedTime, (t) => setModalState(() => selectedTime = t)))),
                ]),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: AppScope.instance.bookingRepository.courts(),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
                    final courts = snap.data ?? [];
                    if (courts.isEmpty) return const Text('Кортов нет');
                    return DropdownButtonFormField<int>(
                      initialValue: selectedCourtId,
                      decoration: InputDecoration(labelText: 'Корт', filled: true, fillColor: Colors.grey.withValues(alpha: 0.1), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
                      items: courts.map((c) { final id = (c['id'] as num).toInt(); return DropdownMenuItem<int>(value: id, child: Text((c['name'] ?? 'Корт $id').toString())); }).toList(),
                      onChanged: (v) => setModalState(() => selectedCourtId = v),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(format == 'DOUBLE' ? 'Игроков: 4 (включая вас)' : 'Игроков: 2 (включая вас)', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty) return;
                      Navigator.of(ctx).pop();
                      try {
                        final lobby = await AppScope.instance.socialRepository.createLobby({'title': titleCtrl.text.trim(), 'game_format': format});
                        if (!mounted) return;
                        setState(_reloadAll);
                        final newId = (lobby['id'] as num?)?.toInt();
                        if (newId != null) _openLobbyDetail(newId);
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
    final activeColor = isDark ? AppTheme.accentColor : AppTheme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сообщество'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: activeColor,
          indicatorColor: activeColor,
          tabs: const [
            Tab(text: 'Лобби'),
            Tab(text: 'Друзья'),
            Tab(text: 'Сообщения'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateLobbySheet,
        backgroundColor: activeColor,
        icon: Icon(Icons.add, color: isDark ? AppTheme.primaryColor : Colors.white),
        label: Text('Создать', style: TextStyle(color: isDark ? AppTheme.primaryColor : Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildLobbyTab(),
          _buildFriendsTab(),
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
              if (snap.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.only(bottom: 16), child: LinearProgressIndicator());
              final myLobbies = snap.data ?? [];
              if (myLobbies.isEmpty) return const SizedBox.shrink();
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Мои лобби', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                ...myLobbies.map((l) => _lobbyCard(l, isMine: true)),
                const SizedBox(height: 20),
              ]);
            },
          ),
          const Text('Открытые лобби', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _openLobbiesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
              if (snapshot.hasError) return _errorWidget(snapshot.error, () => setState(_reloadAll));
              final lobbies = snapshot.data ?? const [];
              if (lobbies.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.sports_tennis_rounded, size: 56, color: Colors.grey.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    const Text('Открытых лобби нет', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 4),
                    const Text('Создайте первое!', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ])),
                );
              }
              return Column(children: lobbies.map((l) => _lobbyCard(l, isMine: false)).toList());
            },
          ),
        ],
      ),
    );
  }

  Widget _lobbyCard(Map<String, dynamic> l, {required bool isMine}) {
    final id = (l['id'] as num?)?.toInt();
    final title = (l['title'] ?? 'Лобби').toString();
    final status = (l['status'] ?? '').toString();
    final players = (l['players_count'] as num?)?.toInt() ?? 0;
    final maxPlayers = (l['max_players'] as num?)?.toInt() ?? 4;
    final isFull = players >= maxPlayers;
    final statusColor = _cardStatusColor(status);

    return GestureDetector(
      onTap: id == null ? null : () => _openLobbyDetail(id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
          border: isMine ? Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3), width: 1.5) : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(_statusLabel(status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              ...List.generate(maxPlayers, (i) => Padding(padding: const EdgeInsets.only(right: 4), child: Icon(Icons.person, size: 20, color: i < players ? AppTheme.primaryColor : Colors.grey.withValues(alpha: 0.3)))),
              const SizedBox(width: 6),
              Text('$players/$maxPlayers', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
            if (!isMine && !isFull && id != null)
              ElevatedButton(onPressed: () => _joinLobby(id), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), minimumSize: const Size(0, 36)), child: const Text('Вступить', style: TextStyle(fontSize: 13)))
            else
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ]),
        ]),
      ),
    );
  }

  // ─── TAB 2: Друзья + inline заявки ───

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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
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
                    if (friendsSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    final friends = friendsSnap.data ?? const [];
                    final isSearching = _searchController.text.trim().isNotEmpty;
                    final show = isSearching ? results : friends;

                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: _incomingFuture,
                      builder: (context, inSnap) {
                        final incoming = inSnap.data ?? const [];

                        if (show.isEmpty && incoming.isEmpty) {
                          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.people_outline, size: 56, color: Colors.grey.withValues(alpha: 0.4)),
                            const SizedBox(height: 8),
                            Text(isSearching ? 'Ничего не найдено' : 'Пока нет друзей', style: const TextStyle(color: Colors.grey)),
                          ]));
                        }

                        return ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            // Friends / search results
                            ...show.asMap().entries.map((entry) {
                              final u = entry.value;
                              final userId = (u['id'] as num?)?.toInt();
                              final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
                              final avatar = u['avatar']?.toString();
                              final avatarUrl = (avatar != null && avatar.isNotEmpty) ? avatar : 'https://i.pravatar.cc/150?img=${(userId ?? 1) % 70}';

                              return Column(children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(backgroundImage: NetworkImage(avatarUrl)),
                                  title: Text(name.isEmpty ? (u['username'] ?? '').toString() : name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text((u['username'] ?? '').toString(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  trailing: isSearching
                                      ? IconButton(icon: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primaryColor), onPressed: userId == null ? null : () => _sendFriendRequest(userId))
                                      : const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                                  onTap: isSearching ? null : () => _showFriendProfile(u),
                                ),
                                if (entry.key < show.length - 1 || incoming.isNotEmpty) const Divider(height: 1),
                              ]);
                            }),

                            // Inline incoming requests
                            if (incoming.isNotEmpty && !isSearching) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    const Icon(Icons.person_add_rounded, size: 20, color: AppTheme.primaryColor),
                                    const SizedBox(width: 8),
                                    Text('Заявки в друзья (${incoming.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                  ]),
                                  const SizedBox(height: 12),
                                  ...incoming.map((req) {
                                    final reqId = (req['id'] as num?)?.toInt();
                                    final from = (req['from_user'] as Map?)?.cast<String, dynamic>() ?? {};
                                    final fromName = '${from['first_name'] ?? ''} ${from['last_name'] ?? ''}'.trim();
                                    final fromAvatar = from['avatar']?.toString();
                                    final fromAvatarUrl = (fromAvatar != null && fromAvatar.isNotEmpty) ? fromAvatar : 'https://i.pravatar.cc/150?img=${(from['id'] ?? 1) % 70}';

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Row(children: [
                                        CircleAvatar(radius: 20, backgroundImage: NetworkImage(fromAvatarUrl)),
                                        const SizedBox(width: 12),
                                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text(fromName.isEmpty ? (from['username'] ?? '').toString() : fromName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                          Text((from['username'] ?? '').toString(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ])),
                                        IconButton(
                                          icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                                          onPressed: reqId == null ? null : () => _respondRequest(reqId, 'accept'),
                                          tooltip: 'Принять',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent),
                                          onPressed: reqId == null ? null : () => _respondRequest(reqId, 'reject'),
                                          tooltip: 'Отклонить',
                                        ),
                                      ]),
                                    );
                                  }),
                                ]),
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
            ),
          ),
        ),
      ],
    );
  }

  // ─── TAB 3: Сообщения (чаты с друзьями) ───

  Widget _buildMessagesTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _friendsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final friends = snap.data ?? const [];
        if (friends.isEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 56, color: Colors.grey.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text('Нет чатов', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            const Text('Добавьте друзей чтобы начать общение', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ]));
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reloadAll),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: friends.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final u = friends[i];
              final userId = (u['id'] as num?)?.toInt();
              final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
              final displayName = name.isEmpty ? (u['username'] ?? '').toString() : name;
              final avatar = u['avatar']?.toString();
              final avatarUrl = (avatar != null && avatar.isNotEmpty) ? avatar : 'https://i.pravatar.cc/150?img=${(userId ?? 1) % 70}';

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(radius: 24, backgroundImage: NetworkImage(avatarUrl)),
                title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Нажмите чтобы написать', style: TextStyle(fontSize: 12, color: Colors.grey)),
                trailing: const Icon(Icons.chat_bubble_rounded, size: 18, color: AppTheme.primaryColor),
                onTap: () => _openChat(u),
              );
            },
          ),
        );
      },
    );
  }

  Widget _errorWidget(Object? e, VoidCallback retry) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Ошибка загрузки'),
      const SizedBox(height: 8),
      Text(e.toString(), textAlign: TextAlign.center),
      const SizedBox(height: 8),
      ElevatedButton(onPressed: retry, child: const Text('Повторить')),
    ]));
  }
}

// ─── Top-level helpers ───

Color _cardStatusColor(String status) {
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

Widget _pickerTile({required BuildContext ctx, required IconData icon, required String label, required VoidCallback onTap}) {
  final isDark = Theme.of(ctx).brightness == Brightness.dark;
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.grey.withValues(alpha: 0.6)),
      ]),
    ),
  );
}

String _fmtDate(DateTime d) {
  const months = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
  return '${d.day} ${months[d.month - 1]}';
}

void _showDateSheet(BuildContext ctx, DateTime current, ValueChanged<DateTime> onPicked) {
  DateTime temp = current;
  showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      height: 320,
      decoration: BoxDecoration(color: Theme.of(sheetCtx).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Выберите дату', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            TextButton(onPressed: () { onPicked(temp); Navigator.pop(sheetCtx); }, child: const Text('Готово', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ]),
        ),
        Expanded(child: CupertinoDatePicker(mode: CupertinoDatePickerMode.date, initialDateTime: current, minimumDate: DateTime.now().subtract(const Duration(days: 1)), maximumDate: DateTime.now().add(const Duration(days: 60)), onDateTimeChanged: (d) => temp = d)),
      ]),
    ),
  );
}

void _showTimeSheet(BuildContext ctx, TimeOfDay current, ValueChanged<TimeOfDay> onPicked) {
  DateTime temp = DateTime(2025, 1, 1, current.hour, current.minute);
  showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      height: 320,
      decoration: BoxDecoration(color: Theme.of(sheetCtx).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Выберите время', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            TextButton(onPressed: () { onPicked(TimeOfDay(hour: temp.hour, minute: temp.minute)); Navigator.pop(sheetCtx); }, child: const Text('Готово', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ]),
        ),
        Expanded(child: CupertinoDatePicker(mode: CupertinoDatePickerMode.time, initialDateTime: temp, use24hFormat: true, minuteInterval: 15, onDateTimeChanged: (d) => temp = d)),
      ]),
    ),
  );
}
