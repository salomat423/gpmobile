import 'package:flutter/material.dart';

import '../core/di/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/qr_club_pass.dart';
import 'coach_schedule_screen.dart';
import 'rating_screen.dart';
import 'profile_screen.dart';

class TrainerMainWrapper extends StatefulWidget {
  const TrainerMainWrapper({super.key});

  @override
  State<TrainerMainWrapper> createState() => _TrainerMainWrapperState();
}

class _TrainerMainWrapperState extends State<TrainerMainWrapper> {
  int _currentIndex = 0;
  int _unreadCount = 0;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    try {
      final results = await Future.wait([
        AppScope.instance.socialRepository.unreadCount(),
        AppScope.instance.authRepository.me(),
      ]);
      if (!mounted) return;
      final me = results[1] as Map<String, dynamic>;
      final fullName = (me['full_name'] ?? '').toString().trim();
      final first = (me['first_name'] ?? '').toString().trim();
      final last = (me['last_name'] ?? '').toString().trim();
      setState(() {
        _unreadCount = results[0] as int;
        _userName = fullName.isNotEmpty ? fullName : '$first $last'.trim();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          CoachScheduleScreen(userName: _userName),
          const RatingScreen(),
          _TrainerQrTab(userName: _userName),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: theme.bottomNavigationBarTheme.backgroundColor,
          selectedItemColor: theme.bottomNavigationBarTheme.selectedItemColor,
          unselectedItemColor: theme.bottomNavigationBarTheme.unselectedItemColor,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month_rounded),
              label: 'Расписание',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events_outlined),
              activeIcon: Icon(Icons.emoji_events_rounded),
              label: 'Матчи',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_rounded),
              activeIcon: Icon(Icons.qr_code_2_rounded),
              label: 'Пропуск',
            ),
            BottomNavigationBarItem(
              icon: _unreadCount > 0
                  ? Badge(
                      label: Text('$_unreadCount'),
                      child: const Icon(Icons.person_outline_rounded),
                    )
                  : const Icon(Icons.person_outline_rounded),
              activeIcon: const Icon(Icons.person_rounded),
              label: 'Профиль',
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainerQrTab extends StatefulWidget {
  final String userName;
  const _TrainerQrTab({required this.userName});

  @override
  State<_TrainerQrTab> createState() => _TrainerQrTabState();
}

class _TrainerQrTabState extends State<_TrainerQrTab> {
  Map<String, dynamic>? _me;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    try {
      final me = await AppScope.instance.authRepository.me();
      if (!mounted) return;
      setState(() {
        _me = me;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Рабочий пропуск')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMe,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _profileHeader(isDark),
                  const SizedBox(height: 24),
                  _qrSection(),
                  const SizedBox(height: 24),
                  _infoCard(isDark),
                ],
              ),
            ),
    );
  }

  Widget _profileHeader(bool isDark) {
    final name = (_me?['full_name'] ?? '${_me?['first_name'] ?? ''} ${_me?['last_name'] ?? ''}'.trim()).toString();
    final role = (_me?['role'] ?? '').toString();
    final roleLabel = role == 'COACH_PADEL'
        ? 'Тренер по паделу'
        : role == 'COACH_FITNESS'
            ? 'Фитнес-тренер'
            : 'Тренер';
    final avatar = _me?['avatar']?.toString();

    return Row(children: [
      CircleAvatar(
        radius: 32,
        backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
        child: avatar == null || avatar.isEmpty
            ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))
            : null,
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            name.isNotEmpty ? name : 'Тренер',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              roleLabel,
              style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _qrSection() {
    final name = (_me?['full_name'] ?? '${_me?['first_name'] ?? ''} ${_me?['last_name'] ?? ''}'.trim()).toString();

    return Center(
      child: Column(children: [
        const Text(
          'Покажите QR на входе в клуб',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => QrClubPass.showQrClubPass(context, name.isNotEmpty ? name : 'Тренер'),
            icon: const Icon(Icons.qr_code_rounded, size: 24),
            label: const Text('Открыть QR-пропуск', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _infoCard(bool isDark) {
    final phone = (_me?['phone'] ?? _me?['phone_number'] ?? _me?['username'] ?? '').toString();
    final elo = (_me?['rating_elo'] ?? 0).toString();
    final pricePerHour = (_me?['price_per_hour'] ?? '0').toString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Информация', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        _infoRow(Icons.phone_outlined, 'Телефон', phone),
        const Divider(height: 20),
        _infoRow(Icons.star_rounded, 'ELO рейтинг', elo),
        if (pricePerHour != '0' && pricePerHour != '0.00') ...[
          const Divider(height: 20),
          _infoRow(Icons.payments_outlined, 'Ставка', '$pricePerHour тг/час'),
        ],
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 20, color: Colors.grey),
      const SizedBox(width: 12),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
      const Spacer(),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    ]);
  }
}
