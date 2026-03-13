import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/di/app_scope.dart';
import '../theme/app_theme.dart';
import '../screens/sportbar.dart';
import '../screens/tournament_screen.dart';

String defaultGreeting() {
  final hour = DateTime.now().hour;
  if (hour >= 6 && hour < 12) return 'Доброе утро,';
  if (hour >= 12 && hour < 18) return 'Добрый день,';
  if (hour >= 18 && hour < 24) return 'Добрый вечер,';
  return 'Доброй ночи,';
}

class HomeScreen extends StatefulWidget {
  final VoidCallback? onGoToBooking;

  const HomeScreen({super.key, this.onGoToBooking});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<Map<String, dynamic>> _homeFuture;
  late Future<Map<String, dynamic>> _statsFuture;
  late Future<List<Map<String, dynamic>>> _membershipsFuture;
  late Future<List<Map<String, dynamic>>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    final scope = AppScope.instance;
    _homeFuture = scope.authRepository.home();
    _statsFuture = scope.authRepository.stats().catchError((_) => <String, dynamic>{});
    _membershipsFuture = scope.membershipRepository.myMemberships().catchError((_) => <Map<String, dynamic>>[]);
    _bookingsFuture = scope.bookingRepository.myBookings().catchError((_) => <Map<String, dynamic>>[]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _homeFuture,
      builder: (context, homeSnap) {
        if (homeSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (homeSnap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Не удалось загрузить главную',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      homeSnap.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return FutureBuilder<List<dynamic>>(
          future: Future.wait([_statsFuture, _membershipsFuture, _bookingsFuture]),
          builder: (context, extraSnap) {
            final statsData = (extraSnap.data != null)
                ? extraSnap.data![0] as Map<String, dynamic>
                : <String, dynamic>{};
            final memberships = (extraSnap.data != null)
                ? extraSnap.data![1] as List<Map<String, dynamic>>
                : <Map<String, dynamic>>[];
            final bookings = (extraSnap.data != null)
                ? extraSnap.data![2] as List<Map<String, dynamic>>
                : <Map<String, dynamic>>[];

            return _HomeBody(
              data: homeSnap.data ?? const {},
              stats: statsData,
              memberships: memberships,
              bookings: bookings,
              onGoToBooking: widget.onGoToBooking,
            );
          },
        );
      },
    );
  }
}

class _HomeBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> memberships;
  final List<Map<String, dynamic>> bookings;
  final VoidCallback? onGoToBooking;

  const _HomeBody({
    required this.data,
    required this.stats,
    required this.memberships,
    required this.bookings,
    required this.onGoToBooking,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppTheme.textPrimary;
    final subTextColor = isDark ? Colors.white70 : Colors.grey[600];
    final user = (data['user'] as Map?)?.cast<String, dynamic>() ?? {};
    final promotions = ((data['promotions'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final news = ((data['news'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final fullName = (user['full_name'] ?? '').toString().trim();
    final firstName = (user['first_name'] ?? '').toString().trim();
    final lastName = (user['last_name'] ?? '').toString().trim();
    final String userName = fullName.isNotEmpty
        ? fullName
        : '$firstName $lastName'.trim().isNotEmpty
            ? '$firstName $lastName'.trim()
            : 'Игрок';
    final greeting = (data['greeting'] ?? defaultGreeting()).toString();
    final avatarUrl = user['avatar']?.toString();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- ПЕРСОНАЛИЗАЦИЯ (Header) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(greeting, style: TextStyle(fontSize: 16, color: subTextColor)),
                      const SizedBox(height: 4),
                      Text(
                        '$userName 👋',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: titleColor, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                  _buildUserAvatar(theme, avatarUrl),
                ],
              ),

              const SizedBox(height: 24),

              // --- КЛУБНЫЙ ПРОПУСК ---
              _buildClubPass(context, isDark),

              const SizedBox(height: 30),

              // --- ИНФОРМАЦИОННЫЙ БЛОК (Новости, Акции) ---
              _buildSectionTitle(titleColor, 'События и акции'),
              const SizedBox(height: 15),
              _buildInfoBanners(promotions, news),

              const SizedBox(height: 30),

              // --- ТУРНИРЫ И МЕРОПРИЯТИЯ ---
              _buildSectionTitle(titleColor, 'Турниры и мероприятия'),
              const SizedBox(height: 15),
              _buildTournamentSection(context, theme, isDark),

              const SizedBox(height: 30),

              // --- ИЗМЕНЕНИЯ В РАБОТЕ ---
              _buildChangesInfoCard(theme, isDark),

              const SizedBox(height: 30),

              // --- МОЯ СТАТИСТИКА ---
              _buildSectionTitle(titleColor, 'Моя статистика'),
              const SizedBox(height: 15),
              _buildStatsSection(theme, isDark),

              const SizedBox(height: 30),

              // --- МОЙ АБОНЕМЕНТ ---
              _buildSectionTitle(titleColor, 'Мой абонемент'),
              const SizedBox(height: 15),
              _buildMembershipSection(theme, isDark),

              const SizedBox(height: 30),

              // --- ДОПОЛНИТЕЛЬНЫЕ УСЛУГИ ---
              _buildSectionTitle(titleColor, 'Сервисы центра'),
              const SizedBox(height: 15),
              _buildAdditionalServices(isDark, theme),

              const SizedBox(height: 30),

              // --- МОЁ РАСПИСАНИЕ ---
              _buildSectionTitle(titleColor, 'Моё расписание'),
              const SizedBox(height: 10),
              _buildScheduleSection(context, theme, isDark),

              const SizedBox(height: 25),

              // --- БЫСТРЫЕ ДЕЙСТВИЯ ---
              _buildQuickActions(isDark, titleColor, subTextColor, onGoToBooking),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(Color color, String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
    );
  }

  Widget _buildUserAvatar(ThemeData theme, String? avatarUrl) {
    return Container(
      width: 50, height: 50,
      decoration: BoxDecoration(
        color: theme.cardColor,
        shape: BoxShape.circle,
        image: DecorationImage(
          image: NetworkImage(
            (avatarUrl != null && avatarUrl.isNotEmpty) ? avatarUrl : 'https://i.pravatar.cc/150?img=11',
          ),
          fit: BoxFit.cover,
        ),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 5))],
      ),
    );
  }

  Widget _buildClubPass(BuildContext context, bool isDark) {
    final userMap = (data['user'] as Map?)?.cast<String, dynamic>() ?? {};
    final userName = (userMap['full_name'] ?? '').toString();
    return GestureDetector(
      onTap: () => _showQrClubPass(context, userName),
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark ? [AppTheme.primaryColor, Colors.black] : [AppTheme.primaryColor, const Color(0xFF1B5E20)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: const Row(
          children: [
            Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 32),
            SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Клубный пропуск', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Нажмите для входа в зал', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
            Spacer(),
            Icon(Icons.chevron_right_rounded, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanners(List<Map<String, dynamic>> promotions, List<Map<String, dynamic>> news) {
    final banners = <Map<String, dynamic>>[
      ...promotions.take(3).map((e) => {
            'title': (e['title'] ?? 'Промо').toString(),
            'subtitle': (e['description'] ?? '').toString(),
            'type': 'АКЦИЯ',
            'imageUrl': (e['image_url'] ?? '').toString(),
          }),
      ...news.take(3).map((e) => {
            'title': (e['title'] ?? 'Новость').toString(),
            'subtitle': (e['preview'] ?? e['content'] ?? '').toString(),
            'type': 'НОВОСТЬ',
            'imageUrl': (e['image_url'] ?? '').toString(),
          }),
    ];
    if (banners.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(child: Text('Сейчас нет новостей и акций', style: TextStyle(color: Colors.grey))),
      );
    }
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: banners.length,
        itemBuilder: (context, index) {
          final banner = banners[index];
          final isPromo = banner['type'] == 'АКЦИЯ';

          return GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => _buildNewsDetailsSheet(context, banner),
            ),
            child: Container(
              width: 280,
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPromo
                      ? [const Color(0xFFD4F826), const Color(0xFFAEEA00)]
                      : [const Color(0xFF0F3628), const Color(0xFF1B5E20)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(6)),
                     child: Text(
                       (banner['type'] ?? '').toString(),
                       style: TextStyle(color: isPromo ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                     ),
                   ),
                   Text(
                     (banner['title'] ?? '').toString(),
                     style: TextStyle(
                         color: isPromo ? const Color(0xFF0F3628) : Colors.white,
                         fontSize: 18, fontWeight: FontWeight.w800, height: 1.2
                    ),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                  const Text('Подробнее →', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- ТУРНИРЫ И МЕРОПРИЯТИЯ ---
  Widget _buildTournamentSection(BuildContext context, ThemeData theme, bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TournamentScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppTheme.primaryColor, const Color(0xFF1B5E20)]
                : [AppTheme.primaryColor, const Color(0xFF2E7D32)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Турниры и мероприятия',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Расписание, регистрация, результаты',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 24),
          ],
        ),
      ),
    );
  }

  // --- ИЗМЕНЕНИЯ В РАБОТЕ ---
  Widget _buildChangesInfoCard(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.blueGrey.shade900.withValues(alpha: 0.5) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.amber.withValues(alpha: 0.2) : Colors.amber.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.amber.shade700, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Изменения в работе',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Актуальное расписание и изменения смотрите в новостях',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.grey[700],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- МОЯ СТАТИСТИКА ---
  Widget _buildStatsSection(ThemeData theme, bool isDark) {
    final s = (stats['stats'] as Map?)?.cast<String, dynamic>() ?? stats;
    final items = [
      _StatItem('Всего посещений', _safeInt(s['total_bookings']), Icons.calendar_today_rounded, Colors.blue),
      _StatItem('Матчей сыграно', _safeInt(s['matches_played']), Icons.sports_tennis_rounded, Colors.orange),
      _StatItem('Побед', _safeInt(s['matches_won']), Icons.emoji_events_rounded, Colors.green),
      _StatItem('Посещений зала', _safeInt(s['gym_visits']), Icons.fitness_center_rounded, Colors.purple),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildStatTile(items[0], isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatTile(items[1], isDark)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatTile(items[2], isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatTile(items[3], isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(_StatItem item, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: item.color, size: 22),
          const SizedBox(height: 10),
          Text(
            item.value.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  // --- МОЙ АБОНЕМЕНТ ---
  Widget _buildMembershipSection(ThemeData theme, bool isDark) {
    final active = memberships.where((m) => m['is_frozen'] != true).toList();
    if (active.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Icon(Icons.card_membership_rounded, color: Colors.grey[400], size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'У вас нет активного абонемента',
                style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : Colors.grey[600]),
              ),
            ),
          ],
        ),
      );
    }

    final m = active.first;
    final typeName = (m['membership_type_name'] ?? 'Абонемент').toString();
    final endDateStr = (m['end_date'] ?? '').toString();
    final hoursRemaining = m['hours_remaining'];

    DateTime? endDate;
    try {
      endDate = DateTime.parse(endDateStr);
    } catch (_) {}

    _MembershipStatus status = _MembershipStatus.active;
    if (endDate != null) {
      final daysLeft = endDate.difference(DateTime.now()).inDays;
      if (daysLeft < 0) {
        status = _MembershipStatus.expired;
      } else if (daysLeft <= 7) {
        status = _MembershipStatus.expiring;
      }
    }

    final statusColor = switch (status) {
      _MembershipStatus.active => Colors.green,
      _MembershipStatus.expiring => Colors.orange,
      _MembershipStatus.expired => Colors.red,
    };
    final statusText = switch (status) {
      _MembershipStatus.active => 'Активен',
      _MembershipStatus.expiring => 'Истекает',
      _MembershipStatus.expired => 'Истёк',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.card_membership_rounded, color: statusColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(typeName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    if (endDateStr.isNotEmpty)
                      Text('до $endDateStr', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600])),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (hoursRemaining != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 18, color: isDark ? Colors.white54 : Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Осталось часов: $hoursRemaining',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : AppTheme.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdditionalServices(bool isDark, ThemeData theme) {
    final services = [
      {
        'name': 'Фитнес-зона',
        'icon': Icons.fitness_center_rounded,
        'color': Colors.orange,
        'onTap': () {},
      },
      {
        'name': 'Спорт-бар',
        'icon': Icons.local_bar_rounded,
        'color': Colors.blue,
        'onTap': () {},
      },
      {
        'name': 'Восстановление',
        'icon': Icons.spa_rounded,
        'color': Colors.teal,
        'onTap': () {},
      },
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: services.map((service) {
        return Builder(
          builder: (context) {
            final name = service['name'] as String;

            VoidCallback? onTap;
            if (name == 'Спорт-бар') {
              onTap = () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SportBarScreen()),
                );
              };
            } else {
              onTap = service['onTap'] as VoidCallback?;
            }

            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Column(
                children: [
                  Container(
                    width: 100,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Icon(
                      service['icon'] as IconData,
                      color: service['color'] as Color,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppTheme.textPrimary,
                    ),
                  )
                ],
              ),
            );
          },
        );
      }).toList(),
    );
  }

  // --- МОЁ РАСПИСАНИЕ ---
  Widget _buildScheduleSection(BuildContext context, ThemeData theme, bool isDark) {
    final nextBooking = data['next_booking'] as Map?;
    if (bookings.isEmpty && nextBooking == null) {
      return const Text('Ближайших игр нет', style: TextStyle(color: Colors.grey));
    }
    final upcoming = bookings.isNotEmpty
        ? bookings.take(5).toList()
        : [Map<String, dynamic>.from(nextBooking!)];
    return Column(
      children: upcoming.map((b) => _buildBookingCard(context, {
        'court': (b['court_name'] ?? b['court'] ?? 'Корт').toString(),
        'date': (b['start_time'] ?? '').toString(),
        'status': (b['status'] ?? 'PENDING').toString(),
      })).toList(),
    );
  }

  static const _shortMonths = [
    '', 'янв', 'фев', 'мар', 'апр', 'май', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
  ];

  static String _courtDisplayName(String raw) {
    final s = raw.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (m) => '${m[1]} ${m[2]}',
    );
    return s[0].toUpperCase() + s.substring(1);
  }

  Widget _buildBookingCard(BuildContext context, Map<String, dynamic> booking) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final status = booking['status'].toString().toUpperCase();
    final isPaid = status == 'ОПЛАЧЕНО' || status == 'CONFIRMED' || status == 'COMPLETED';

    final rawDate = (booking['date'] ?? '').toString();
    final dt = DateTime.tryParse(rawDate);
    final courtName = _courtDisplayName((booking['court'] ?? 'Корт').toString());

    final timeLabel = dt != null
        ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '';
    final dateLabel = dt != null
        ? '${dt.day} ${_shortMonths[dt.month]}, $timeLabel'
        : rawDate;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Row(
        children: [
          _buildDateBadge(isDark, dt),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courtName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildStatusBadge(isPaid, isDark),
        ],
      ),
    );
  }

  Widget _buildDateBadge(bool isDark, DateTime? dt) {
    final day = dt != null ? '${dt.day}' : '--';
    final month = dt != null ? _shortMonths[dt.month] : '';
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : AppTheme.bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(day, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Text(month, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isPaid, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isPaid ? Colors.green : Colors.orange).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isPaid ? 'ГОТОВО' : 'ОПЛАТА',
        style: TextStyle(color: isPaid ? Colors.green : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  // --- БЫСТРЫЕ ДЕЙСТВИЯ ---
  Widget _buildQuickActions(bool isDark, Color titleColor, Color? subTextColor, VoidCallback? onTap) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2F38) : const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.add, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 12),
                  Text('Забронировать корт', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor)),
                  const SizedBox(height: 2),
                  Text('Свободное время', style: TextStyle(color: subTextColor, fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2F1E38) : const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.deepPurple.shade400,
                    child: const Icon(Icons.sports_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 12),
                  Text('Запись на тренировку', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor)),
                  const SizedBox(height: 2),
                  Text('Выбрать тренера', style: TextStyle(color: subTextColor, fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewsDetailsSheet(BuildContext context, Map<String, dynamic> banner) {
    final theme = Theme.of(context);
    final type = (banner['type'] ?? '').toString();
    final isPromo = type == 'АКЦИЯ';
    final imageUrl = (banner['imageUrl'] ?? '').toString();
    final title = (banner['title'] ?? 'Событие').toString();
    final subtitle = (banner['subtitle'] ?? '').toString().trim();

    return FractionallySizedBox(
      heightFactor: 0.86,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: SizedBox(
                        height: 220,
                        width: double.infinity,
                        child: (imageUrl.isNotEmpty)
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildBannerSheetImageFallback(isPromo),
                              )
                            : _buildBannerSheetImageFallback(isPromo),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isPromo ? const Color(0xFFD4F826) : const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          color: isPromo ? const Color(0xFF0F3628) : const Color(0xFF1B5E20),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.15),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      subtitle.isEmpty ? 'Подробности появятся в ближайшее время.' : subtitle,
                      style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Понятно'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerSheetImageFallback(bool isPromo) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPromo
              ? [const Color(0xFFD4F826), const Color(0xFFAEEA00)]
              : [const Color(0xFF0F3628), const Color(0xFF1B5E20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          isPromo ? Icons.local_offer_rounded : Icons.newspaper_rounded,
          color: isPromo ? const Color(0xFF0F3628) : Colors.white,
          size: 56,
        ),
      ),
    );
  }

  void _showQrClubPass(BuildContext ctx, String userName) async {
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
      qrContent = '';
    }
    if (!ctx.mounted) return;
    Navigator.of(ctx).pop();

    showDialog(
      context: ctx,
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
                userName.isNotEmpty ? userName : 'Участник клуба',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Container(
                width: 220, height: 220,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: qrContent.isEmpty
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
}

class _StatItem {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _StatItem(this.label, this.value, this.icon, this.color);
}

enum _MembershipStatus { active, expiring, expired }
