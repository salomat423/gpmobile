import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart'; // Импорт экрана входа

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // --- Логика выхода из аккаунта ---
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Выход'),
        content: const Text('Вы уверены, что хотите выйти из аккаунта?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Закрываем диалог
              // Переход на экран входа и полная очистка навигации
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const AuthScreen()),
                    (route) => false,
              );
            },
            child: const Text('Выйти', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color titleColor = isDark ? Colors.white : AppTheme.textPrimary;
    final Color subTitleColor = isDark ? Colors.white70 : Colors.grey;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // --- 1. Аватар и Имя ---
              const SizedBox(height: 10),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.cardColor, width: 4),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 5)
                          )
                        ],
                        image: const DecorationImage(
                          image: NetworkImage('https://i.pravatar.cc/150?img=11'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Александр Иванов',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: titleColor),
                    ),
                    Text(
                      '+7 777 123 45 67',
                      style: TextStyle(fontSize: 14, color: subTitleColor, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // --- 2. QR Пропуск ---
              GestureDetector(
                onTap: () => showDialog(context: context, builder: (context) => _buildQRDialog(context)),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? Colors.white10 : AppTheme.primaryColor.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white12 : AppTheme.textPrimary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.qr_code_2_rounded, color: AppTheme.accentColor, size: 32),
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Клубный пропуск', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor)),
                          const SizedBox(height: 4),
                          Text('Нажмите для входа', style: TextStyle(color: subTitleColor, fontSize: 13)),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // --- 3. Статус и Баллы ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, Color(0xFF1B5E20)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: AppTheme.primaryColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Статус', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('Gold Member 🏆', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(height: 40, width: 1, color: Colors.white24),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Баллы', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('2 450', style: TextStyle(color: AppTheme.accentColor, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // --- 4. Меню ---
              _buildMenuItem(context, icon: Icons.credit_card_rounded, title: 'Мои карты'),

              // Переключатель темы
              _buildMenuItem(
                context,
                icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                title: 'Темная тема',
                trailing: Switch(
                  value: isDark,
                  activeColor: AppTheme.accentColor,
                  onChanged: (value) {
                    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                  },
                ),
              ),

              _buildMenuItem(context, icon: Icons.notifications_none_rounded, title: 'Уведомления'),
              _buildMenuItem(context, icon: Icons.language_rounded, title: 'Язык', subtitle: 'Русский'),

              const SizedBox(height: 20),

              // --- Кнопка выхода (Обновленная) ---
              TextButton(
                onPressed: () => _showLogoutDialog(context),
                child: const Text('Выйти из аккаунта', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white12 : AppTheme.bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isDark ? Colors.white : AppTheme.primaryColor, size: 22),
        ),
        title: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : AppTheme.textPrimary)
        ),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: Colors.grey)) : null,
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      ),
    );
  }

  Widget _buildQRDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))
            ]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ваш пропуск', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 8),
            const Text('Поднесите к считывателю', style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 24),
            Container(
              height: 220,
              width: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.qr_code_2, size: 200, color: Colors.black),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.sports_tennis_rounded, color: AppTheme.accentColor, size: 24),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Обновление через 25 сек...', textAlign: TextAlign.center, style: TextStyle(color: isDark ? AppTheme.accentColor : AppTheme.primaryColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const LinearProgressIndicator(value: 0.3, color: AppTheme.accentColor, backgroundColor: Colors.grey),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Закрыть', style: TextStyle(fontSize: 16, color: textColor)),
            )
          ],
        ),
      ),
    );
  }
}