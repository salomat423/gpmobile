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

  final Map<String, bool> _notifToggles = {
    'booking': true,
    'social': true,
    'achievements': true,
    'subscriptions': true,
    'financial': true,
    'tournaments': true,
    'news': true,
    'promotions': false,
    'system': true,
  };

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

  // ── Profile editing ──────────────────────────────────────────────────

  void _showEditProfileSheet(Map<String, dynamic> me) {
    final firstCtrl = TextEditingController(text: me['first_name']?.toString() ?? '');
    final lastCtrl = TextEditingController(text: me['last_name']?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _SheetWrapper(
          title: 'Редактировать профиль',
          icon: Icons.person_outline,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstCtrl,
                decoration: InputDecoration(
                  labelText: 'Имя',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lastCtrl,
                decoration: InputDecoration(
                  labelText: 'Фамилия',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final nav = Navigator.of(ctx);
                    try {
                      await AppScope.instance.authRepository.updateMe({
                        'first_name': firstCtrl.text.trim(),
                        'last_name': lastCtrl.text.trim(),
                      });
                      nav.pop();
                      _reload();
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Ошибка: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Сохранить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Photo upload placeholder ─────────────────────────────────────────

  void _onAvatarTap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Загрузка фото будет доступна в ближайшем обновлении')),
    );
  }

  // ── Financial section ────────────────────────────────────────────────

  void _showFinanceSheet() {
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
            _buildDragHandle(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined),
                  SizedBox(width: 8),
                  Text('Платежи и финансы', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Привязка карт и автоплатежи будут доступны в ближайшем обновлении',
                      style: TextStyle(fontSize: 13, color: AppTheme.primaryColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: AppScope.instance.secondaryRepository.financeHistory(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text(snap.error.toString(), textAlign: TextAlign.center));
                  }
                  final items = snap.data ?? [];
                  if (items.isEmpty) {
                    return const Center(child: Text('Нет финансовых операций', style: TextStyle(color: Colors.grey)));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final f = items[i];
                      final desc = (f['description'] ?? f['type'] ?? 'Операция').toString();
                      final amount = (f['amount'] ?? '').toString();
                      final date = (f['created_at'] ?? f['date'] ?? '').toString();
                      final status = (f['status'] ?? '').toString();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          amount.startsWith('-') ? Icons.arrow_downward : Icons.arrow_upward,
                          color: amount.startsWith('-') ? Colors.redAccent : Colors.green,
                        ),
                        title: Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              amount.isNotEmpty ? '$amount ₸' : '—',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: amount.startsWith('-') ? Colors.redAccent : Colors.green,
                              ),
                            ),
                            if (status.isNotEmpty)
                              Text(status, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
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

  // ── Booking history ──────────────────────────────────────────────────

  void _showBookingHistorySheet() {
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
            _buildDragHandle(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.history),
                  SizedBox(width: 8),
                  Text('История бронирований', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: AppScope.instance.bookingRepository.bookingHistory(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text(snap.error.toString(), textAlign: TextAlign.center));
                  }
                  final items = snap.data ?? [];
                  if (items.isEmpty) {
                    return const Center(child: Text('Нет бронирований', style: TextStyle(color: Colors.grey)));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final b = items[i];
                      final court = (b['court_name'] ?? b['court'] ?? 'Корт').toString();
                      final start = (b['start_time'] ?? b['datetime'] ?? '').toString();
                      final status = (b['status'] ?? '').toString();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.sports_tennis, color: AppTheme.primaryColor),
                        title: Text(court),
                        subtitle: Text(start, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        trailing: _bookingStatusChip(status),
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

  Widget _bookingStatusChip(String status) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'completed':
        bg = Colors.green.withValues(alpha: 0.12);
        fg = Colors.green;
        break;
      case 'cancelled':
      case 'canceled':
        bg = Colors.red.withValues(alpha: 0.12);
        fg = Colors.redAccent;
        break;
      case 'pending':
        bg = Colors.orange.withValues(alpha: 0.12);
        fg = Colors.orange;
        break;
      default:
        bg = Colors.grey.withValues(alpha: 0.12);
        fg = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  // ── Reviews placeholder ──────────────────────────────────────────────

  void _showReviewsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SheetWrapper(
        title: 'Отзывы',
        icon: Icons.rate_review_outlined,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.rate_review_outlined, size: 56, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Система отзывов будет доступна\nв ближайшем обновлении',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Notification settings ────────────────────────────────────────────

  void _showNotificationSettingsSheet() {
    const labels = {
      'booking': 'Бронирования',
      'social': 'Социальные',
      'achievements': 'Достижения',
      'subscriptions': 'Абонементы',
      'financial': 'Финансы',
      'tournaments': 'Турниры',
      'news': 'Новости',
      'promotions': 'Акции',
      'system': 'Системные',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDragHandle(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.notifications_active_outlined),
                    SizedBox(width: 8),
                    Text('Настройки уведомлений', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                  children: _notifToggles.keys.map((key) {
                    return SwitchListTile(
                      title: Text(labels[key] ?? key),
                      value: _notifToggles[key]!,
                      activeColor: AppTheme.primaryColor,
                      onChanged: (val) {
                        setSheetState(() => _notifToggles[key] = val);
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Security placeholder ─────────────────────────────────────────────

  void _showSecuritySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SheetWrapper(
        title: 'Безопасность',
        icon: Icons.shield_outlined,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Настройки безопасности будут доступны в ближайшем обновлении',
                      style: TextStyle(fontSize: 13, color: AppTheme.primaryColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _placeholderToggle('Вход по биометрии', false),
            _placeholderToggle('Двухфакторная аутентификация', false),
            _placeholderToggle('Запоминать устройство', true),
          ],
        ),
      ),
    );
  }

  Widget _placeholderToggle(String label, bool initial) {
    return StatefulBuilder(
      builder: (ctx, setSt) {
        bool val = initial;
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: val,
          activeColor: AppTheme.primaryColor,
          onChanged: (v) => setSt(() => val = v),
        );
      },
    );
  }

  // ── Info dialogs ─────────────────────────────────────────────────────

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('О приложении'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GPPadel v1.0.0', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 12),
            Text(
              'Мобильное приложение для клуба падел-тенниса GPPadel. '
              'Бронирование кортов, управление абонементами, статистика игр, '
              'турниры и социальные функции — всё в одном месте.',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.support_agent, size: 48, color: AppTheme.primaryColor),
        title: const Text('Служба поддержки'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.email_outlined),
              title: Text('support@gppadel.kz'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.phone_outlined),
              title: Text('+7 (700) 123-45-67'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Политика конфиденциальности'),
        content: const SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Text(
              'Настоящая Политика конфиденциальности определяет порядок обработки '
              'и защиты персональных данных пользователей мобильного приложения GPPadel.\n\n'
              '1. Общие положения\n'
              'Используя приложение, вы соглашаетесь с условиями данной политики. '
              'Мы собираем только необходимые данные для предоставления услуг.\n\n'
              '2. Собираемые данные\n'
              'Имя, фамилия, номер телефона, статистика игр, история бронирований.\n\n'
              '3. Цели обработки\n'
              'Предоставление доступа к услугам клуба, персонализация, '
              'уведомления о бронированиях и турнирах.\n\n'
              '4. Хранение данных\n'
              'Данные хранятся на защищённых серверах и не передаются третьим лицам '
              'без вашего согласия.\n\n'
              '5. Права пользователя\n'
              'Вы имеете право на доступ, изменение и удаление своих данных.\n\n'
              '6. Контакты\n'
              'По вопросам обработки данных: support@gppadel.kz',
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Условия использования'),
        content: const SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Text(
              'Условия использования мобильного приложения GPPadel.\n\n'
              '1. Принятие условий\n'
              'Устанавливая и используя приложение, вы принимаете настоящие условия.\n\n'
              '2. Регистрация\n'
              'Для использования необходима регистрация по номеру телефона. '
              'Вы несёте ответственность за достоверность предоставленных данных.\n\n'
              '3. Бронирования\n'
              'Бронирования кортов регулируются правилами клуба. '
              'Отмена бронирования возможна не позднее чем за 2 часа до начала.\n\n'
              '4. Оплата\n'
              'Оплата услуг производится через встроенные платёжные системы. '
              'Тарифы определяются действующим прайс-листом клуба.\n\n'
              '5. Ответственность\n'
              'Клуб не несёт ответственности за перебои в работе приложения, '
              'вызванные техническими причинами.\n\n'
              '6. Изменение условий\n'
              'Мы оставляем за собой право изменять условия использования '
              'с предварительным уведомлением пользователей.\n\n'
              '7. Контакты\n'
              'support@gppadel.kz | +7 (700) 123-45-67',
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  // ── QR club pass (existing) ──────────────────────────────────────────

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

  // ── Gym visits (existing) ────────────────────────────────────────────

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
            _buildDragHandle(),
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

  // ── Logout (existing) ────────────────────────────────────────────────

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

  // ── Delete account (existing) ────────────────────────────────────────

  Future<void> _confirmDeleteAccount() async {
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

  // ── Helpers ──────────────────────────────────────────────────────────

  static Widget _buildDragHandle() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        tileColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: iconColor),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey,
          letterSpacing: 0.8,
        ),
      ),
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

  // ── Build ────────────────────────────────────────────────────────────

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
                // ── User tile with edit & avatar upload ──
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: GestureDetector(
                    onTap: _onAvatarTap,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundImage: NetworkImage(
                            (avatar != null && avatar.isNotEmpty)
                                ? avatar
                                : 'https://i.pravatar.cc/150?img=11',
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  title: Text(
                    fullName.isEmpty ? 'Пользователь' : fullName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                  subtitle: Text(phone),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
                    tooltip: 'Редактировать',
                    onPressed: () => _showEditProfileSheet(me),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Club pass with QR ──
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

                // ── League & ELO card ──
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

                // ── Stats card ──
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

                // ── Activity section ──
                _sectionLabel('Активность'),
                _buildMenuTile(
                  icon: Icons.notifications_outlined,
                  title: 'Уведомления',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  ),
                ),
                _buildMenuTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Настройки уведомлений',
                  onTap: _showNotificationSettingsSheet,
                ),
                _buildMenuTile(
                  icon: Icons.miscellaneous_services_outlined,
                  title: 'Сервисы клуба',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ClubServicesScreen()),
                  ),
                ),
                _buildMenuTile(
                  icon: Icons.fitness_center_outlined,
                  title: 'Посещения зала',
                  onTap: _showGymVisitsSheet,
                ),
                _buildMenuTile(
                  icon: Icons.history,
                  title: 'История бронирований',
                  onTap: _showBookingHistorySheet,
                ),

                // ── Finance section ──
                _sectionLabel('Финансы'),
                _buildMenuTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Платежи и финансы',
                  onTap: _showFinanceSheet,
                ),

                // ── Social section ──
                _sectionLabel('Социальное'),
                _buildMenuTile(
                  icon: Icons.rate_review_outlined,
                  title: 'Отзывы',
                  onTap: _showReviewsSheet,
                ),

                // ── Info section ──
                _sectionLabel('Информация'),
                _buildMenuTile(
                  icon: Icons.info_outline,
                  title: 'О приложении',
                  onTap: _showAboutDialog,
                ),
                _buildMenuTile(
                  icon: Icons.support_agent_outlined,
                  title: 'Служба поддержки',
                  onTap: _showSupportDialog,
                ),
                _buildMenuTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Политика конфиденциальности',
                  onTap: _showPrivacyPolicyDialog,
                ),
                _buildMenuTile(
                  icon: Icons.description_outlined,
                  title: 'Условия использования',
                  onTap: _showTermsDialog,
                ),

                // ── Security & account section ──
                _sectionLabel('Аккаунт'),
                _buildMenuTile(
                  icon: Icons.shield_outlined,
                  title: 'Безопасность',
                  onTap: _showSecuritySheet,
                ),
                const SizedBox(height: 8),
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
}

// ── Reusable bottom sheet wrapper ────────────────────────────────────────

class _SheetWrapper extends StatelessWidget {
  const _SheetWrapper({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
