import 'package:flutter/foundation.dart';

import '../push_notification_service.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/booking/data/booking_repository.dart';
import '../../features/memberships/data/membership_repository.dart';
import '../../features/secondary/data/secondary_repository.dart';
import '../../features/social/data/social_repository.dart';
import '../../features/chat/data/chat_repository.dart';
import '../../features/tournament/data/tournament_repository.dart';
import '../network/api_client.dart';
import '../storage/token_storage.dart';

enum AuthState { unknown, authenticated, unauthenticated }

class AppScope {
  AppScope._()
      : authRepository = AuthRepository(ApiClient.instance, TokenStorage.instance),
        bookingRepository = BookingRepository(ApiClient.instance),
        membershipRepository = MembershipRepository(ApiClient.instance),
        socialRepository = SocialRepository(ApiClient.instance),
        secondaryRepository = SecondaryRepository(ApiClient.instance),
        chatRepository = ChatRepository(ApiClient.instance),
        tournamentRepository = TournamentRepository(ApiClient.instance);

  static final AppScope instance = AppScope._();

  final AuthRepository authRepository;
  final BookingRepository bookingRepository;
  final MembershipRepository membershipRepository;
  final SocialRepository socialRepository;
  final SecondaryRepository secondaryRepository;
  final ChatRepository chatRepository;
  final TournamentRepository tournamentRepository;

  final ValueNotifier<AuthState> authState = ValueNotifier<AuthState>(AuthState.unknown);

  Future<void> bootstrapAuth() async {
    final hasSession = await authRepository.hasSession();
    if (!hasSession) {
      authState.value = AuthState.unauthenticated;
      return;
    }
    try {
      final meData = await authRepository.me();
      authState.value = AuthState.authenticated;
      // Если роль не была сохранена (например, после обновления токена) — восстанавливаем из профиля
      final role = await TokenStorage.instance.readRole();
      if ((role == null || role.trim().isEmpty) && meData['role'] != null) {
        await TokenStorage.instance.saveRole(meData['role'].toString().trim());
      }
      // Отправить FCM-токен на бэкенд для push-уведомлений
      PushNotificationService.instance.requestPermissionAndSyncToken();
    } catch (_) {
      try {
        await authRepository.refresh();
        authState.value = AuthState.authenticated;
        final role = await TokenStorage.instance.readRole();
        if (role == null || role.trim().isEmpty) {
          try {
            final meData = await authRepository.me();
            if (meData['role'] != null) {
              await TokenStorage.instance.saveRole(meData['role'].toString().trim());
            }
          } catch (_) {}
        }
        PushNotificationService.instance.requestPermissionAndSyncToken();
      } catch (_) {
        await authRepository.logout();
        authState.value = AuthState.unauthenticated;
      }
    }
  }
}
