import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? onGoToBooking;

  const HomeScreen({super.key, this.onGoToBooking});

  // 2.1 Логика персонализированного приветствия
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) return 'Доброе утро,';
    if (hour >= 12 && hour < 18) return 'Добрый день,';
    if (hour >= 18 && hour < 24) return 'Добрый вечер,';
    return 'Доброй ночи,';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppTheme.textPrimary;
    final subTextColor = isDark ? Colors.white70 : Colors.grey[600];

    const String userName = 'Александр';

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
                      Text(_getGreeting(), style: TextStyle(fontSize: 16, color: subTextColor)),
                      const SizedBox(height: 4),
                      Text(
                        '$userName 👋',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: titleColor, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                  _buildUserAvatar(theme),
                ],
              ),

              const SizedBox(height: 24),

              // --- КЛУБНЫЙ ПРОПУСК ---
              _buildClubPass(context, isDark),

              const SizedBox(height: 30),

              // --- 2.2 ИНФОРМАЦИОННЫЙ БЛОК (Новости, Акции, Турниры) ---
              _buildSectionTitle(titleColor, 'События и акции'),
              const SizedBox(height: 15),
              _buildInfoBanners(),

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
                  TextButton(
                    onPressed: () {},
                    child: const Text('Все', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              const SizedBox(height: 10),
              ...MockData.myBookings.map((booking) => _buildBookingCard(context, booking)),

              const SizedBox(height: 25),

              // КНОПКА БРОНИРОВАНИЯ
              _buildBookingAction(isDark, titleColor, subTextColor),
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
  Widget _buildUserAvatar(ThemeData theme) {
    return Container(
      width: 50, height: 50,
      decoration: BoxDecoration(
        color: theme.cardColor,
        shape: BoxShape.circle,
        image: const DecorationImage(image: NetworkImage('https://i.pravatar.cc/150?img=11'), fit: BoxFit.cover),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 5))],
      ),
    );
  }

  // Клубный пропуск
  Widget _buildClubPass(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () => showDialog(context: context, builder: (context) => _buildQRDialog(context)),
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark ? [AppTheme.primaryColor, Colors.black] : [AppTheme.primaryColor, const Color(0xFF1B5E20)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
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
  Widget _buildInfoBanners() {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: MockData.banners.length,
        itemBuilder: (context, index) {
          final banner = MockData.banners[index];
          final isPromo = index == 1; // Например, второй баннер — акция

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
                      isPromo ? 'АКЦИЯ' : 'ТУРНИР',
                      style: TextStyle(color: isPromo ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    banner['title']!,
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
      {'name': 'Фитнес-зона', 'icon': Icons.fitness_center_rounded, 'color': Colors.orange},
      {'name': 'Спорт-бар', 'icon': Icons.local_bar_rounded, 'color': Colors.blue},
      {'name': 'Восстановление', 'icon': Icons.spa_rounded, 'color': Colors.teal},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: services.map((service) {
        return Column(
          children: [
            Container(
              width: 100,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Icon(service['icon'] as IconData, color: service['color'] as Color, size: 30),
            ),
            const SizedBox(height: 8),
            Text(
              service['name'] as String,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : AppTheme.textPrimary),
            )
          ],
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Row(
        children: [
          _buildDateBadge(isDark),
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

  Widget _buildDateBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: isDark ? Colors.white10 : AppTheme.bgColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          const Text('24', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Окт', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isPaid, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isPaid ? Colors.green : Colors.orange).withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isPaid ? 'ГОТОВО' : 'ОПЛАТА',
        style: TextStyle(color: isPaid ? Colors.green : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Кнопка быстрого бронирования
  Widget _buildBookingAction(bool isDark, Color titleColor, Color? subTextColor) {
    return GestureDetector(
      onTap: onGoToBooking,
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
  Widget _buildNewsDetailsSheet(BuildContext context, Map<String, String> banner) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text(banner['title']!, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 15),
          Text(
            'Спешим сообщить важные новости нашего падел-центра! ${banner['subtitle']}. \n\nЖдем вас на кортах! Бронируйте заранее через приложение, чтобы получить бонусы.',
            style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.grey),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Понятно')),
          )
        ],
      ),
    );
  }

  // Диалог QR
  Widget _buildQRDialog(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ваш пропуск', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const Icon(Icons.qr_code_2_rounded, size: 200, color: AppTheme.primaryColor),
            const SizedBox(height: 20),
            const LinearProgressIndicator(value: 0.7, color: AppTheme.accentColor),
            const SizedBox(height: 20),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
          ],
        ),
      ),
    );
  }
}