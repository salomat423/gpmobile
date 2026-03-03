import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/di/app_scope.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';
import 'club_services_screen.dart';
import 'notifications_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final me = await AppScope.instance.authRepository.me();
    final stats = await AppScope.instance.authRepository.stats();
    final league = await AppScope.instance.authRepository.league();
    return {'me': me, 'stats': stats, 'league': league};
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Выход из аккаунта'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Выйти', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await AppScope.instance.authRepository.logoutWithBlacklist();
    AppScope.instance.authState.value = AuthState.unauthenticated;
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  Future<void> _confirmDeleteAccount() async {
    // Step 1
    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
        title: const Text('Удаление аккаунта'),
        content: const Text(
          'Это действие необратимо. Все ваши данные, бронирования, абонементы и статистика будут удалены.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Продолжить', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
    if (step1 != true || !mounted) return;

    // Step 2
    final step2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.delete_forever_rounded, size: 48, color: Colors.redAccent),
        title: const Text('Вы точно уверены?'),
        content: const Text(
          'После удаления восстановить аккаунт будет невозможно. Все ваши друзья, рейтинг и история матчей будут потеряны.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Нет, отменить')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Да, удалить', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (step2 != true || !mounted) return;

    // Step 3 — type confirmation
    final confirmCtrl = TextEditingController();
    final step3 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.dangerous_rounded, size: 48, color: Colors.red),
        title: const Text('Последнее подтверждение'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Введите слово УДАЛИТЬ для подтверждения:'),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              decoration: InputDecoration(
                hintText: 'УДАЛИТЬ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          StatefulBuilder(
            builder: (ctx, setSt) => ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                if (confirmCtrl.text.trim() == 'УДАЛИТЬ') {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Удалить навсегда', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
    if (step3 != true || !mounted) return;

    final navigator = Navigator.of(context);
    try {
      await AppScope.instance.authRepository.deleteAccount();
    } catch (_) {}
    if (!mounted) return;
    AppScope.instance.authState.value = AuthState.unauthenticated;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  void _showQrClubPass(BuildContext ctx, Map<String, dynamic> me) async {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String qrContent = '';
    try {
      final qr = await AppScope.instance.secondaryRepository.gymQr();
      qrContent = (qr['qr_content'] ?? '').toString();
    } catch (_) {
      qrContent = 'QR unavailable';
    }
    if (!ctx.mounted) return;
    Navigator.of(ctx).pop();

    final fullName = '${me['first_name'] ?? ''} ${me['last_name'] ?? ''}'.trim();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, Color(0xFF1B5E20)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Клубный пропуск', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                fullName.isEmpty ? 'Участник клуба' : fullName,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Container(
                width: 220, height: 220,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: qrContent.isEmpty || qrContent == 'QR unavailable'
                    ? const Center(child: Icon(Icons.qr_code_2_rounded, size: 140, color: AppTheme.primaryColor))
                    : QrImageView(
                        data: qrContent,
                        version: QrVersions.auto,
                        size: 196,
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: AppTheme.primaryColor),
                        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: AppTheme.primaryColor),
                      ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Покажите QR на входе', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Закрыть', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGymVisitsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
        decoration: BoxDecoration(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.fitness_center),
                  SizedBox(width: 8),
                  Text('История посещений зала', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: AppScope.instance.secondaryRepository.gymVisits(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text(snap.error.toString(), textAlign: TextAlign.center));
                  }
                  final visits = snap.data ?? const [];
                  if (visits.isEmpty) {
                    return const Center(child: Text('Посещений пока нет', style: TextStyle(color: Colors.grey)));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: visits.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final v = visits[i];
                      final date = (v['created_at'] ?? v['date'] ?? '').toString();
                      final status = (v['status'] ?? v['type'] ?? 'VISIT').toString();
                      final note = (v['message'] ?? v['description'] ?? '').toString();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                        title: Text(date.isEmpty ? 'Посещение #${i + 1}' : date),
                        subtitle: note.isEmpty ? null : Text(note, maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: Text(status, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Профиль')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Не удалось загрузить профиль'),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _reload, child: const Text('Повторить')),
                ],
              ),
            ),
          );
        }

        final payload = snapshot.data ?? const {};
        final me = (payload['me'] as Map?)?.cast<String, dynamic>() ?? {};
        final stats = ((payload['stats'] as Map?)?['stats'] as Map?)?.cast<String, dynamic>() ?? {};
        final league = (((payload['league'] as Map?)?['current_league']) as Map?)?.cast<String, dynamic>() ?? {};

        final fullName = '${me['first_name'] ?? ''} ${me['last_name'] ?? ''}'.trim();
        final phone = (me['phone_number'] ?? me['username'] ?? '').toString();
        final avatar = me['avatar']?.toString();
        final elo = (me['rating_elo'] ?? 0).toString();
        final leagueName = (league['name'] ?? '—').toString();

        return Scaffold(
          appBar: AppBar(title: const Text('Профиль')),
          body: RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 32,
                    backgroundImage: NetworkImage(
                      (avatar != null && avatar.isNotEmpty)
                          ? avatar
                          : 'https://i.pravatar.cc/150?img=11',
                    ),
                  ),
                  title: Text(
                    fullName.isEmpty ? 'Пользователь' : fullName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                  subtitle: Text(phone),
                ),
                const SizedBox(height: 12),

                // --- Club pass with QR ---
                GestureDetector(
                  onTap: () => _showQrClubPass(context, me),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryColor, Color(0xFF1B5E20)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 36),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Клубный пропуск', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              Text('$leagueName  •  ELO $elo', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Лига', style: TextStyle(color: Colors.grey)),
                          Text(leagueName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('ELO', style: TextStyle(color: Colors.grey)),
                          Text(elo, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Статистика', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      _statRow(Icons.sports_tennis, 'Бронирований', '${stats['total_bookings'] ?? 0}'),
                      _statRow(Icons.emoji_events, 'Сыграно матчей', '${stats['matches_played'] ?? 0}'),
                      _statRow(Icons.star, 'Побед', '${stats['matches_won'] ?? 0}'),
                      _statRow(Icons.fitness_center, 'Посещений зала', '${stats['gym_visits'] ?? 0}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  tileColor: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: const Text('Уведомления'),
                  leading: const Icon(Icons.notifications_outlined),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                    );
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  tileColor: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: const Text('Сервисы клуба'),
                  leading: const Icon(Icons.miscellaneous_services_outlined),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ClubServicesScreen()),
                    );
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  tileColor: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: const Text('Посещения зала'),
                  leading: const Icon(Icons.fitness_center_outlined),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: _showGymVisitsSheet,
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _confirmLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Выйти из аккаунта'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _confirmDeleteAccount,
                  icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 18),
                  label: const Text('Удалить аккаунт', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
