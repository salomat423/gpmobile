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

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final league = await AppScope.instance.authRepository.league();
    final leaderboard = await AppScope.instance.socialRepository.leaderboard(limit: 20);
    final matches = await AppScope.instance.socialRepository.matches();
    return {'league': league, 'leaderboard': leaderboard, 'matches': matches};
  }

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
                    onPressed: () => setState(() => _future = _load()),
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
        final current = (league['current_league'] as Map?)?.cast<String, dynamic>() ?? {};
        final elo = (league['rating_elo'] as num?)?.toInt() ?? 0;
        final leagueName = (current['name'] ?? 'Bronze').toString();
        final leagueData = _resolveLeague(leagueName, elo);
        final progress = (elo - leagueData.min) / (leagueData.max - leagueData.min);
        final nextLeagueName = _leagueConfig.entries
            .where((e) => e.value.min > leagueData.min)
            .map((e) => e.value.label)
            .firstOrNull ?? 'Мастер';

        return Scaffold(
          appBar: AppBar(title: const Text('Мой рейтинг')),
          body: RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // --- HERO LEAGUE CARD ---
                Container(
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
                ),

                const SizedBox(height: 24),
                const Text('Топ игроков', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 8),

                ...List.generate(board.take(10).length, (i) {
                  final u = board[i];
                  final rank = i + 1;
                  final name = (u['full_name'] ?? u['username'] ?? '').toString();
                  final uElo = (u['rating_elo'] ?? 0);
                  final avatar = u['avatar']?.toString();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: rank <= 3 ? Border.all(color: _rankColor(rank).withValues(alpha: 0.4), width: 1.5) : null,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: rank <= 3
                              ? Icon(_rankIcon(rank), color: _rankColor(rank), size: 22)
                              : Text('$rank', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        ),
                        const SizedBox(width: 12),
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: NetworkImage(
                            (avatar != null && avatar.isNotEmpty) ? avatar : 'https://i.pravatar.cc/150?img=${(i + 5) % 70}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
                        Text('$uElo', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor.withValues(alpha: isDark ? 1 : 0.8))),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 24),
                const Text('Мои матчи', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 8),

                if (matches.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Матчей пока нет', style: TextStyle(color: Colors.grey)))),

                ...matches.take(10).map(
                  (m) {
                    final score = (m['score'] ?? '-').toString();
                    final date = (m['date_formatted'] ?? m['date'] ?? '').toString();
                    final change = (m['my_elo_change'] as num?)?.toInt() ?? 0;
                    final isWin = change > 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
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
                  },
                ),
              ],
            ),
          ),
        );
      },
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
