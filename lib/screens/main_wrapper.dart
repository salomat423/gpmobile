import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'home_screen.dart';
import 'booking_screen.dart';
import 'social_screen.dart';
import 'rating_screen.dart';
import 'profile_screen.dart';
// Убедитесь, что путь к теме верный, либо закомментируйте, если не используете кастомные классы из app_theme
import '../theme/app_theme.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initialization();
  }

  /// Логика инициализации и скрытия нативного сплэш-экрана
  void _initialization() async {
    // Имитация загрузки или проверка токена (2 секунды)
    await Future.delayed(const Duration(seconds: 2));
    // Убираем заставку
    FlutterNativeSplash.remove();
  }

  /// Метод для переключения на вкладку "Бронь" (индекс 1)
  /// Передается в HomeScreen
  void _goToBookingTab() {
    setState(() {
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Список страниц. Важно: HomeScreen получает колбэк для навигации
    final List<Widget> pages = [
      HomeScreen(onGoToBooking: _goToBookingTab),
      const BookingScreen(),
      const SocialScreen(),
      const RatingScreen(),
      const ProfileScreen()
    ];

    return Scaffold(
      // IndexedStack сохраняет состояние страниц (не перезагружает их при переключении)
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        // Добавляем верхнюю границу для визуального разделения
        decoration: BoxDecoration(
          color: theme.cardColor,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),

          // Цвета берутся из темы
          backgroundColor: theme.bottomNavigationBarTheme.backgroundColor,
          selectedItemColor: theme.bottomNavigationBarTheme.selectedItemColor,
          unselectedItemColor: theme.bottomNavigationBarTheme.unselectedItemColor,

          type: BottomNavigationBarType.fixed, // Чтобы иконки не "плясали" при >3 элементах
          elevation: 0, // Убираем тень, так как используем border сверху

          // Настройка стилей текста подписей
          selectedLabelStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold
          ),
          unselectedLabelStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500
          ),

          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Главная',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.sports_tennis_outlined),
              activeIcon: Icon(Icons.sports_tennis_rounded),
              label: 'Бронь',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline_rounded),
              activeIcon: Icon(Icons.people_rounded),
              label: 'Друзья',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events_outlined),
              activeIcon: Icon(Icons.emoji_events_rounded),
              label: 'Рейтинг',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Профиль',
            ),
          ],
        ),
      ),
    );
  }
}