import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/di/app_scope.dart';
import '../core/network/api_error.dart';

import '../theme/app_theme.dart';
import 'main_wrapper.dart';
import 'trainer_main_wrapper.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  const OtpScreen({super.key, required this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resendCode();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4) {
      setState(() => _errorText = 'Введите код из SMS');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final result = await AppScope.instance.authRepository.login(
        phoneNumber: widget.phoneNumber,
        code: otp,
      );
      AppScope.instance.authState.value = AuthState.authenticated;
      if (!mounted) return;

      final isNewUser = result['is_new_user'] == true;
      final isProfileComplete = result['is_profile_complete'] == true;
      final access = (result['access'] ?? '').toString();
      final role = (result['role'] ?? '').toString().toUpperCase();
      final isCoach = role == 'COACH_PADEL' || role == 'COACH_FITNESS';

      if (isNewUser || !isProfileComplete) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => ProfileSetupScreen(
              accessToken: access,
              phoneNumber: widget.phoneNumber,
              isCoach: isCoach,
            ),
          ),
              (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => isCoach ? const TrainerMainWrapper() : const MainWrapper()),
              (route) => false,
        );
      }
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = 'Ошибка сети/сервера: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await AppScope.instance.authRepository.sendCode(widget.phoneNumber);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Код отправлен')),
      );
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = 'Ошибка сети/сервера: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          children: [
            Text('Подтверждение', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 10),
            Text(
              'Мы отправили код на ${widget.phoneNumber}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            if (_errorText != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_errorText!, style: const TextStyle(color: Colors.redAccent)),
              ),
              const SizedBox(height: 14),
            ],

            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: 'Введите код',
                counterText: "",
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                fillColor: theme.cardColor,
                filled: true,
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Подтвердить', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 14),

            TextButton(
              onPressed: _isLoading ? null : _resendCode,
              child: const Text('Отправить код заново'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileSetupScreen extends StatefulWidget {
  final String accessToken;
  final String phoneNumber;
  final bool isCoach;

  const ProfileSetupScreen({super.key, required this.accessToken, required this.phoneNumber, this.isCoach = false});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_first.text.trim().isEmpty) return;

    setState(() => _saving = true);
    try {
      await AppScope.instance.authRepository.updateMe({
        'first_name': _first.text.trim(),
        'last_name': _last.text.trim(),
      });

      if (!mounted) return;
      AppScope.instance.authState.value = AuthState.authenticated;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => widget.isCoach ? const TrainerMainWrapper() : const MainWrapper()),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('Введите имя и фамилию', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(controller: _first, decoration: const InputDecoration(labelText: 'Имя')),
            const SizedBox(height: 12),
            TextField(controller: _last, decoration: const InputDecoration(labelText: 'Фамилия')),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Сохранить'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
