// Push-уведомления: на Android доставляет FCM, на iOS — FCM через APNs.
// Чтобы пуши заработали: 1) Создайте проект в Firebase Console.
// 2) Выполните: dart pub global activate flutterfire_cli && flutterfire configure
// 3) Добавьте в Xcode capability "Push Notifications" и при необходимости "Background Modes" → Remote notifications.

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'di/app_scope.dart';

/// Сервис push-уведомлений (FCM).
/// На Android пуши доставляет FCM, на iOS — FCM через APNs.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  bool _initialized = false;

  /// Инициализация Firebase (вызвать из main до runApp).
  static Future<bool> ensureInitialized() async {
    if (instance._initialized) return true;
    try {
      await Firebase.initializeApp();
      instance._initialized = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Запрос разрешения на уведомления (iOS и Android 13+), получение FCM-токена и отправка на бэкенд.
  Future<void> requestPermissionAndSyncToken() async {
    if (!_initialized) return;
    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) return;

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;

      await AppScope.instance.authRepository.saveFcm(token);
    } catch (_) {
      // Firebase не настроен или пользователь не залогинен
    }
  }

  /// Только отправить текущий FCM-токен на бэкенд (если пользователь уже залогинен).
  Future<void> syncTokenToBackend() async {
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await AppScope.instance.authRepository.saveFcm(token);
    } catch (_) {}
  }

  /// Обработчик входящих сообщений в foreground (опционально).
  static void setForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Можно показать in-app уведомление или обновить UI
    });
  }

  /// Обработчик тапа по уведомлению (когда приложение открыто из фона).
  static void setMessageOpenedHandler(void Function(RemoteMessage)? onOpened) {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      onOpened?.call(message);
    });
  }
}
