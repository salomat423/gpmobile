import 'package:flutter/material.dart';

import '../core/di/app_scope.dart';
import '../theme/app_theme.dart';

const _leagueConfig = <String, _LeagueData>{
  'Bronze':   _LeagueData(icon: Icons.shield_outlined,   min: 0,    max: 1200, label: 'Бронза'),
  'Silver':   _LeagueData(icon: Icons.shield,            min: 1200, max: 1500, label: 'Серебро'),
  'Gold':     _LeagueData(icon: Icons.workspace_premium,  min: 1500, max: 1800, label: 'Золото'),
  'Platinum': _LeagueData(icon: Icons.diamond_outlined,   min: 1800, max: 2100, label: 'Платина'),
  'Diamond':  _LeagueData(icon: Icons.diamond,            min: 2100, max: 2500, label: 'Бриллиант'),
  'Master':   _LeagueData(icon: Icons.emoji_events,       min: 2500, max: 3000, label: 'Мастер'),
};

class _LeagueData {
  final IconData icon;
  final int min;
  final int max;
  final String label;
  const _LeagueData({required this.icon, required this.min, required this.max, required this.label});
}

_LeagueData _resolveLeague(String name, int elo) {
  return _leagueConfig[name] ?? _leagueConfig.values.firstWhere(
    (l) => elo >= l.min && elo < l.max,
    orElse: () => _leagueConfig.values.first,
  );
}

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _showAllMatches = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final scope = AppScope.instance;
    final results = await Future.wait([
      scope.authRepository.league(),
      scope.socialRepository.leaderboard(limit: 20),
      scope.socialRepository.matches(),
      scope.authRepository.me(),
    ]);
    return {
      'league': results[0],
      'leaderboard': results[1],
      'matches': results[2],
      'me': results[3],
    };
  }

  void _reload() => setState(() {
    _showAllMatches = false;
    _future = _load();
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Рейтинг')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _reload,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data ?? const {};
        final league = (data['league'] as Map?)?.cast<String, dynamic>() ?? {};
        final board = (data['leaderboard'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
        final matches = (data['matches'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
        final me = (data['me'] as Map?)?.cast<String, dynamic>() ?? {};
        final myId = me['id'];
        final current = (league['current_league'] as Map?)?.cast<String, dynamic>() ?? {};
        final elo = (league['rating_elo'] as num?)?.toInt() ?? 0;
        final leagueName = (current['name'] ?? 'Bronze').toString();
        final leagueData = _resolveLeague(leagueName, elo);
        final progress = (elo - leagueData.min) / (leagueData.max - leagueData.min);
        final nextLeagueName = _leagueConfig.entries
            .where((e) => e.value.min > leagueData.min)
            .map((e) => e.value.label)
            .firstOrNull ?? 'Мастер';

        final visibleMatches = _showAllMatches ? matches : matches.take(10).toList();

        return Scaffold(
          appBar: AppBar(title: const Text('Мой рейтинг')),
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: AppTheme.accentColor,
            onPressed: () => _showCreateMatchSheet(context),
            child: const Icon(Icons.add),
          ),
          body: RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // --- HERO LEAGUE CARD ---
                _buildLeagueCard(isDark, leagueData, elo, nextLeagueName, progress),

                const SizedBox(height: 24),
                const Text('Топ игроков', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 8),

                // --- LEADERBOARD ---
                ...List.generate(board.take(10).length, (i) {
                  final u = board[i];
                  final rank = i + 1;
                  final name = (u['full_name'] ?? u['username'] ?? '').toString();
                  final uElo = (u['rating_elo'] ?? 0);
                  final avatar = u['avatar']?.toString();
                  final isMe = myId != null && u['id'] == myId;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isMe
                          ? AppTheme.primaryColor.withOpacity(0.1)
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: isMe
                          ? Border.all(color: AppTheme.primaryColor.withOpacity(0.5), width: 2)
                          : rank <= 3
                              ? Border.all(color: _rankColor(rank).withValues(alpha: 0.4), width: 1.5)
                              : null,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: rank <= 3
                              ? Icon(_rankIcon(rank), color: _rankColor(rank), size: 22)
                              : Text(
                                  '$rank',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isMe ? AppTheme.primaryColor : Colors.grey,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: NetworkImage(
                            (avatar != null && avatar.isNotEmpty) ? avatar : 'https://i.pravatar.cc/150?img=${(i + 5) % 70}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                              color: isMe ? AppTheme.primaryColor : null,
                            ),
                          ),
                        ),
                        if (isMe)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Вы',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        Text(
                          '$uElo',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor.withValues(alpha: isDark ? 1 : 0.8),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // --- PENDING CONFIRMATIONS ---
                const SizedBox(height: 24),
                const Text('Ожидают подтверждения', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.grey, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Нет матчей, ожидающих подтверждения',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ),

                // --- MATCHES ---
                const SizedBox(height: 24),
                const Text('Мои матчи', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 8),

                if (matches.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Матчей пока нет', style: TextStyle(color: Colors.grey)),
                    ),
                  ),

                ...visibleMatches.map((m) => _buildMatchCard(context, m)),

                if (!_showAllMatches && matches.length > 10)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: () => setState(() => _showAllMatches = true),
                        icon: const Icon(Icons.expand_more),
                        label: Text('Показать все (${matches.length})'),
                      ),
                    ),
                  ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeagueCard(bool isDark, _LeagueData leagueData, int elo, String nextLeagueName, double progress) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1B5E20), const Color(0xFF0A2618)]
              : [const Color(0xFF2E7D32), const Color(0xFF1B5E20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1B5E20).withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Icon(leagueData.icon, size: 56, color: AppTheme.accentColor),
          const SizedBox(height: 8),
          Text(
            leagueData.label,
            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          Text(
            '$elo',
            style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900, height: 1),
          ),
          const SizedBox(height: 4),
          const Text('ELO', style: TextStyle(color: Colors.white54, fontSize: 14, letterSpacing: 2)),
          const SizedBox(height: 20),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${leagueData.min}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  Text('${leagueData.max}  ($nextLeagueName)', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(BuildContext context, Map<String, dynamic> m) {
    final score = (m['score'] ?? '-').toString();
    final date = (m['date_formatted'] ?? m['date'] ?? '').toString();
    final change = (m['my_elo_change'] as num?)?.toInt() ?? 0;
    final isWin = change > 0;
    final opponentName = m['opponent_name']?.toString();
    final opponentAvatar = m['opponent_avatar']?.toString();
    final hasOpponent = opponentName != null && opponentName.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (hasOpponent) ...[
            CircleAvatar(
              radius: 18,
              backgroundImage: (opponentAvatar != null && opponentAvatar.isNotEmpty)
                  ? NetworkImage(opponentAvatar)
                  : null,
              child: (opponentAvatar == null || opponentAvatar.isEmpty)
                  ? Text(
                      opponentName[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
          ],
          Container(
            width: 4, height: 36,
            decoration: BoxDecoration(
              color: isWin ? Colors.green : Colors.redAccent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Счёт: $score', style: const TextStyle(fontWeight: FontWeight.w600)),
                if (hasOpponent)
                  Text(opponentName, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Text(
            '${change > 0 ? '+' : ''}$change',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isWin ? Colors.green : Colors.redAccent),
          ),
        ],
      ),
    );
  }

  void _showCreateMatchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateMatchSheet(onCreated: _reload),
    );
  }
}

class _CreateMatchSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateMatchSheet({required this.onCreated});

  @override
  State<_CreateMatchSheet> createState() => _CreateMatchSheetState();
}

class _CreateMatchSheetState extends State<_CreateMatchSheet> {
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _courts = [];
  Map<String, dynamic>? _selectedFriend;
  Map<String, dynamic>? _selectedCourt;
  final _myScoreController = TextEditingController();
  final _opponentScoreController = TextEditingController();
  bool _loading = true;
  bool _submitting = false;
  String? _friendSearch;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final scope = AppScope.instance;
      final results = await Future.wait([
        scope.socialRepository.friends(),
        scope.bookingRepository.courts(),
      ]);
      if (!mounted) return;
      setState(() {
        _friends = (results[0] as List).cast<Map<String, dynamic>>();
        _courts = (results[1] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _myScoreController.dispose();
    _opponentScoreController.dispose();
    super.dispose();
  }

  String _friendDisplayName(Map<String, dynamic> f) {
    final first = (f['first_name'] ?? '').toString();
    final last = (f['last_name'] ?? '').toString();
    return '$first $last'.trim();
  }

  List<Map<String, dynamic>> get _filteredFriends {
    if (_friendSearch == null || _friendSearch!.isEmpty) return _friends;
    final q = _friendSearch!.toLowerCase();
    return _friends.where((f) => _friendDisplayName(f).toLowerCase().contains(q)).toList();
  }

  Future<void> _submit() async {
    if (_selectedFriend == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите соперника')),
      );
      return;
    }
    final myScore = _myScoreController.text.trim();
    final oppScore = _opponentScoreController.text.trim();
    if (myScore.isEmpty || oppScore.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите счёт')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final me = await AppScope.instance.authRepository.me();
      final myId = me['id'];
      final oppId = _selectedFriend!['id'];
      final score = '$myScore - $oppScore';

      final myScoreNum = _parseScoreTotal(myScore);
      final oppScoreNum = _parseScoreTotal(oppScore);
      final winnerTeam = myScoreNum >= oppScoreNum ? 'A' : 'B';

      await AppScope.instance.socialRepository.createMatch(
        teamA: [myId],
        teamB: [oppId],
        score: score,
        winnerTeam: winnerTeam,
        court: _selectedCourt != null ? (_selectedCourt!['id'] as num?)?.toInt() : null,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Матч зарегистрирован!'),
          backgroundColor: Colors.green,
        ),
      );
      widget.onCreated();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  int _parseScoreTotal(String score) {
    return score
        .split(RegExp(r'[,\s]+'))
        .map((s) => int.tryParse(s.split('-').first.trim()) ?? 0)
        .fold(0, (a, b) => a + b);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 16 + bottomInset),
      child: _loading
          ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Регистрация матча',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                  ),
                  const SizedBox(height: 20),

                  const Text('Соперник', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  _buildFriendSelector(),

                  const SizedBox(height: 20),
                  const Text('Счёт', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _myScoreController,
                          decoration: InputDecoration(
                            hintText: '6-4, 6-3',
                            labelText: 'Ваш счёт',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('vs', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _opponentScoreController,
                          decoration: InputDecoration(
                            hintText: '3-6, 4-6',
                            labelText: 'Счёт соперника',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Text('Корт (необязательно)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: _selectedCourt,
                    decoration: InputDecoration(
                      hintText: 'Выберите корт',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    items: _courts.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text((c['name'] ?? '').toString()),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedCourt = v),
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Зарегистрировать матч'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
    );
  }

  Widget _buildFriendSelector() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selectedFriend != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: _selectedFriend!['avatar'] != null && (_selectedFriend!['avatar'] as String).isNotEmpty
                      ? NetworkImage(_selectedFriend!['avatar'] as String)
                      : null,
                  child: _selectedFriend!['avatar'] == null || (_selectedFriend!['avatar'] as String).isEmpty
                      ? Text(_friendDisplayName(_selectedFriend!).isNotEmpty ? _friendDisplayName(_selectedFriend!)[0] : '?')
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _friendDisplayName(_selectedFriend!),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _selectedFriend = null),
                  child: const Icon(Icons.close, size: 20, color: Colors.grey),
                ),
              ],
            ),
          )
        else ...[
          TextField(
            onChanged: (v) => setState(() => _friendSearch = v),
            decoration: InputDecoration(
              hintText: 'Поиск по имени...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: _filteredFriends.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Друзья не найдены', style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredFriends.length,
                    itemBuilder: (_, i) {
                      final f = _filteredFriends[i];
                      final name = _friendDisplayName(f);
                      final avatar = f['avatar']?.toString();
                      final elo = f['rating_elo'];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
                          child: (avatar == null || avatar.isEmpty) ? Text(name.isNotEmpty ? name[0] : '?') : null,
                        ),
                        title: Text(name, style: const TextStyle(fontSize: 14)),
                        trailing: elo != null ? Text('$elo', style: const TextStyle(color: Colors.grey, fontSize: 12)) : null,
                        onTap: () => setState(() {
                          _selectedFriend = f;
                          _friendSearch = null;
                        }),
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }
}

IconData _rankIcon(int rank) {
  switch (rank) {
    case 1: return Icons.emoji_events;
    case 2: return Icons.military_tech;
    case 3: return Icons.workspace_premium;
    default: return Icons.circle;
  }
}

Color _rankColor(int rank) {
  switch (rank) {
    case 1: return const Color(0xFFFFD700);
    case 2: return const Color(0xFFC0C0C0);
    case 3: return const Color(0xFFCD7F32);
    default: return Colors.grey;
  }
}
