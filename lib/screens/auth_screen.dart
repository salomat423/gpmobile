import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'otp_screen.dart'; // Обязательно создайте этот файл ниже

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    final subTextColor = isDark ? Colors.white70 : Colors.grey;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/icon.png',
                  height: 120, width: 120, fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.sports_tennis_rounded, size: 80, color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 40),
                Text('Вход в систему', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 8),
                Text('Введите ваш номер телефона', style: TextStyle(fontSize: 15, color: subTextColor)),
                const SizedBox(height: 40),

                // Поле ввода
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 16, right: 10),
                        child: Row(
                          children: [
                            Text('🇰🇿', style: TextStyle(fontSize: 24)),
                            SizedBox(width: 8),
                            Text('+7', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Container(height: 24, width: 1, color: Colors.grey.withOpacity(0.3)),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(fontSize: 18, letterSpacing: 1.2, fontWeight: FontWeight.w500),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            KzPhoneFormatter(),
                            LengthLimitingTextInputFormatter(13),
                          ],
                          decoration: InputDecoration(
                            hintText: '700 000 00 00',
                            hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 18),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      String rawPhone = _phoneController.text.replaceAll(' ', '');
                      if (rawPhone.length == 10) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => OtpScreen(phoneNumber: _phoneController.text),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Введите полный номер'), backgroundColor: Colors.redAccent),
                        );
                      }
                    },
                    child: const Text('Войти', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Нажимая «Войти», вы принимаете условия оферты', textAlign: TextAlign.center, style: TextStyle(color: subTextColor, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Улучшенный форматтер: исправляет проблему прыгающего курсора
class KzPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(' ', '');
    if (text.length > 10) return oldValue;

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i == 2 || i == 5 || i == 7) && i != text.length - 1) {
        buffer.write(' ');
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}