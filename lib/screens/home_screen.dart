import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/di/app_scope.dart';
import '../theme/app_theme.dart';
import '../screens/sportbar.dart';

String defaultGreeting() {
  final hour = DateTime.now().hour;
  if (hour >= 6 && hour < 12) return 'Доброе утро,';
  if (hour >= 12 && hour < 18) return 'Добрый день,';
  if (hour >= 18 && hour < 24) return 'Добрый вечер,';
  return 'Доброй ночи,';
}

class HomeScreen extends StatelessWidget {
  final VoidCallback? onGoToBooking;

  const HomeScreen({super.key, this.onGoToBooking});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: AppScope.instance.authRepository.home(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
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
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return _HomeBody(data: snapshot.data ?? const {}, onGoToBooking: onGoToBooking);
      },
    );
  }
}

class _HomeBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onGoToBooking;

  const _HomeBody({required this.data, required this.onGoToBooking});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppTheme.textPrimary;
    final subTextColor = isDark ? Colors.white70 : Colors.grey[600];
    final user = (data['user'] as Map?)?.cast<String, dynamic>() ?? {};
    final nextBooking = (data['next_booking'] as Map?)?.cast<String, dynamic>();
    final promotions = ((data['promotions'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final news = ((data['news'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final String userName = (user['full_name'] ?? '').toString().trim().isEmpty
        ? 'Игрок'
        : user['full_name'].toString();
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
              // --- 2.1 ПЕРСОНАЛИЗАЦИЯ (Header) ---
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

              // --- 2.2 ИНФОРМАЦИОННЫЙ БЛОК (Новости, Акции, Турниры) ---
              _buildSectionTitle(titleColor, 'События и акции'),
              const SizedBox(height: 15),
              _buildInfoBanners(promotions, news),

              const SizedBox(height: 30),

              // --- 2.3 ДОПОЛНИТЕЛЬНЫЕ УСЛУГИ (Фитнес, Бар, Процедуры) ---
              _buildSectionTitle(titleColor, 'Сервисы центра'),
              const SizedBox(height: 15),
              _buildAdditionalServices(isDark, theme),

              const SizedBox(height: 30),

              // --- 2.1 ИНФОРМАЦИЯ О БЛИЖАЙШИХ АКТИВНОСТЯХ ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle(titleColor, 'Мои игры'),
                ],
              ),
              const SizedBox(height: 10),
              if (nextBooking != null)
                _buildBookingCard(context, {
                  'court': nextBooking['court']?.toString() ?? 'Корт',
                  'date':
                      '${nextBooking['date'] ?? ''} ${nextBooking['start_time'] ?? ''}'.trim(),
                  'status': nextBooking['status']?.toString() ?? 'PENDING',
                })
              else
                const Text('Ближайших игр нет', style: TextStyle(color: Colors.grey)),

              const SizedBox(height: 25),

              // КНОПКА БРОНИРОВАНИЯ
              _buildBookingAction(isDark, titleColor, subTextColor, onGoToBooking),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Виджет заголовка секции
  Widget _buildSectionTitle(Color color, String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
    );
  }

  // Аватар пользователя
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

  // Клубный пропуск
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

  // 2.2 Информационный блок (Баннеры)
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

  // 2.3 Дополнительные услуги
  Widget _buildAdditionalServices(bool isDark, ThemeData theme) {
    final services = [
      {
        'name': 'Фитнес-зона',
        'icon': Icons.fitness_center_rounded,
        'color': Colors.orange,
        'onTap': () {}, // позже откроем Fitness screen
      },
      {
        'name': 'Спорт-бар',
        'icon': Icons.local_bar_rounded,
        'color': Colors.blue,
        'onTap': () {
          // ВАЖНО: context нужен, поэтому onTap будет вызываться внутри build через Builder ниже
        },
      },
      {
        'name': 'Восстановление',
        'icon': Icons.spa_rounded,
        'color': Colors.teal,
        'onTap': () {}, // позже откроем Recovery screen
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

  // Карточка бронирования
  Widget _buildBookingCard(BuildContext context, Map<String, dynamic> booking) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPaid = booking['status'] == 'Оплачено';

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
          _buildDateBadge(isDark, (booking['date'] ?? '').toString()),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking['court'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(booking['date'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          _buildStatusBadge(isPaid, isDark),
        ],
      ),
    );
  }

  Widget _buildDateBadge(bool isDark, String dateText) {
    final parts = dateText.split(' ');
    final day = parts.isNotEmpty ? parts.first : '--';
    final month = parts.length > 1 ? parts[1] : '';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: isDark ? Colors.white10 : AppTheme.bgColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(day, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(month, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
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

  // Кнопка быстрого бронирования
  Widget _buildBookingAction(bool isDark, Color titleColor, Color? subTextColor, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2F38) : const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.add, color: Colors.white)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Забронировать корт', style: TextStyle(fontWeight: FontWeight.bold, color: titleColor)),
                Text('Выбрать свободное время', style: TextStyle(color: subTextColor, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Детали новости (Bottom Sheet)
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
