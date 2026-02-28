import 'dart:async';

import 'package:flutter/material.dart';

import '../core/di/app_scope.dart';
import '../theme/app_theme.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<List<Map<String, dynamic>>> _lobbiesFuture;
  late Future<List<Map<String, dynamic>>> _friendsFuture;
  late Future<List<Map<String, dynamic>>> _incomingFuture;
  late Future<List<Map<String, dynamic>>> _outgoingFuture;
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
    _lobbiesFuture = AppScope.instance.socialRepository.listLobbies(status: 'OPEN');
    _friendsFuture = AppScope.instance.socialRepository.friends();
    _incomingFuture = AppScope.instance.socialRepository.incomingRequests();
    _outgoingFuture = AppScope.instance.socialRepository.outgoingRequests();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        if (value.trim().isEmpty) {
          _searchFuture = Future.value(const []);
        } else {
          _searchFuture = AppScope.instance.authRepository.searchUsers(value.trim());
        }
      });
    });
  }

  Future<void> _sendFriendRequest(int userId) async {
    try {
      await AppScope.instance.socialRepository.sendFriendRequest(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заявка отправлена')));
      setState(_reloadAll);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _respondRequest(int requestId, String action) async {
    try {
      await AppScope.instance.socialRepository.respondRequest(requestId, action);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(action == 'accept' ? 'Заявка принята' : 'Заявка отклонена')),
      );
      setState(_reloadAll);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _cancelOutgoing(int requestId) async {
    try {
      await AppScope.instance.socialRepository.cancelRequest(requestId);
      if (!mounted) return;
      setState(_reloadAll);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _removeFriend(int userId) async {
    try {
      await AppScope.instance.socialRepository.removeFriend(userId);
      if (!mounted) return;
      setState(_reloadAll);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _joinLobby(int id) async {
    try {
      await AppScope.instance.socialRepository.joinLobby(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Вы вступили в лобби')));
      setState(_reloadAll);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

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
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: Theme.of(ctx).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
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
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('2v2 (Парный)'),
                      selected: format == 'DOUBLE',
                      onSelected: (_) => setModalState(() => format = 'DOUBLE'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('1v1 (Одиночный)'),
                      selected: format == 'SINGLE',
                      onSelected: (_) => setModalState(() => format = 'SINGLE'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 60)),
                          );
                          if (picked != null) setModalState(() => selectedDate = picked);
                        },
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text('${selectedDate.day}.${selectedDate.month}.${selectedDate.year}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(context: ctx, initialTime: selectedTime);
                          if (picked != null) setModalState(() => selectedTime = picked);
                        },
                        icon: const Icon(Icons.access_time, size: 18),
                        label: Text('${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: AppScope.instance.bookingRepository.courts(),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const LinearProgressIndicator();
                    }
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
                      onChanged: (v) => setModalState(() => selectedCourtId = v),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  format == 'DOUBLE' ? 'Игроков: 4 (включая вас)' : 'Игроков: 2 (включая вас)',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty) return;
                      Navigator.pop(ctx);
                      try {
                        await AppScope.instance.socialRepository.createLobby({
                          'title': titleCtrl.text.trim(),
                          'game_format': format,
                        });
                        if (!mounted) return;
                        setState(_reloadAll);
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
            Tab(text: 'Заявки'),
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
          _buildRequestsTab(),
        ],
      ),
    );
  }

  Widget _buildLobbyTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _lobbiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return _errorWidget(snapshot.error, () => setState(_reloadAll));
        final lobbies = snapshot.data ?? const [];
        if (lobbies.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_tennis_rounded, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                const Text('Лобби пока нет', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                const Text('Создайте первое!', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reloadAll),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lobbies.length,
            itemBuilder: (context, i) {
              final l = lobbies[i];
              final id = (l['id'] as num?)?.toInt();
              final title = (l['title'] ?? 'Лобби').toString();
              final status = (l['status'] ?? '').toString();
              final players = l['players_count'] ?? 0;
              final maxPlayers = l['max_players'] ?? 4;
              final eloLabel = (l['elo_label'] ?? '').toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppTheme.accentColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                          child: Text(status, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (eloLabel.isNotEmpty) Text(eloLabel, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Игроки: $players/$maxPlayers', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ElevatedButton(
                          onPressed: id == null ? null : () => _joinLobby(id),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), minimumSize: const Size(0, 36)),
                          child: const Text('Вступить', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

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
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _searchFuture,
            builder: (context, searchSnap) {
              final results = searchSnap.data ?? const [];
              return FutureBuilder<List<Map<String, dynamic>>>(
                future: _friendsFuture,
                builder: (context, friendsSnap) {
                  if (friendsSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final friends = friendsSnap.data ?? const [];
                  final show = _searchController.text.trim().isEmpty ? friends : results;
                  if (show.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline, size: 56, color: Colors.grey.withValues(alpha: 0.4)),
                          const SizedBox(height: 8),
                          Text(
                            _searchController.text.trim().isEmpty ? 'Пока нет друзей' : 'Ничего не найдено',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => setState(_reloadAll),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: show.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final u = show[i];
                        final userId = (u['id'] as num?)?.toInt();
                        final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
                        final avatar = u['avatar']?.toString();
                        final isSearchResult = _searchController.text.trim().isNotEmpty;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(
                              (avatar != null && avatar.isNotEmpty) ? avatar : 'https://i.pravatar.cc/150?img=${(userId ?? 1) % 70}',
                            ),
                          ),
                          title: Text(name.isEmpty ? (u['username'] ?? '').toString() : name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text((u['username'] ?? '').toString(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          trailing: isSearchResult
                              ? IconButton(
                                  icon: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primaryColor),
                                  onPressed: userId == null ? null : () => _sendFriendRequest(userId),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.person_remove_outlined, color: Colors.redAccent),
                                  onPressed: userId == null ? null : () => _removeFriend(userId),
                                ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRequestsTab() {
    return RefreshIndicator(
      onRefresh: () async => setState(_reloadAll),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Входящие заявки', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _incomingFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
              final list = snap.data ?? const [];
              if (list.isEmpty) return const Padding(padding: EdgeInsets.only(bottom: 16), child: Text('Нет входящих заявок', style: TextStyle(color: Colors.grey)));
              return Column(
                children: list.map((req) {
                  final reqId = (req['id'] as num?)?.toInt();
                  final from = (req['from_user'] as Map?)?.cast<String, dynamic>() ?? {};
                  final fromName = '${from['first_name'] ?? ''} ${from['last_name'] ?? ''}'.trim();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(
                          (from['avatar'] ?? 'https://i.pravatar.cc/150?img=${(from['id'] ?? 1) % 70}').toString(),
                        ),
                      ),
                      title: Text(fromName.isEmpty ? (from['username'] ?? '').toString() : fromName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text((from['username'] ?? '').toString(), style: const TextStyle(fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: Colors.green),
                            onPressed: reqId == null ? null : () => _respondRequest(reqId, 'accept'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.redAccent),
                            onPressed: reqId == null ? null : () => _respondRequest(reqId, 'reject'),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text('Исходящие заявки', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _outgoingFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
              final list = snap.data ?? const [];
              if (list.isEmpty) return const Text('Нет исходящих заявок', style: TextStyle(color: Colors.grey));
              return Column(
                children: list.map((req) {
                  final reqId = (req['id'] as num?)?.toInt();
                  final to = (req['to_user'] as Map?)?.cast<String, dynamic>() ?? {};
                  final toName = '${to['first_name'] ?? ''} ${to['last_name'] ?? ''}'.trim();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(
                          (to['avatar'] ?? 'https://i.pravatar.cc/150?img=${(to['id'] ?? 1) % 70}').toString(),
                        ),
                      ),
                      title: Text(toName.isEmpty ? (to['username'] ?? '').toString() : toName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Ожидает подтверждения', style: TextStyle(fontSize: 12, color: Colors.orange)),
                      trailing: TextButton(
                        onPressed: reqId == null ? null : () => _cancelOutgoing(reqId),
                        child: const Text('Отменить', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
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
          ElevatedButton(onPressed: retry, child: const Text('Повторить')),
        ],
      ),
    );
  }
}
