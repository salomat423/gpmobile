import 'package:flutter/foundation.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/booking/data/booking_repository.dart';
import '../../features/memberships/data/membership_repository.dart';
import '../../features/secondary/data/secondary_repository.dart';
import '../../features/social/data/social_repository.dart';
import '../network/api_client.dart';
import '../storage/token_storage.dart';

enum AuthState { unknown, authenticated, unauthenticated }

class AppScope {
  AppScope._()
      : authRepository = AuthRepository(ApiClient.instance, TokenStorage.instance),
        bookingRepository = BookingRepository(ApiClient.instance),
        membershipRepository = MembershipRepository(ApiClient.instance),
        socialRepository = SocialRepository(ApiClient.instance),
        secondaryRepository = SecondaryRepository(ApiClient.instance);

  static final AppScope instance = AppScope._();

  final AuthRepository authRepository;
  final BookingRepository bookingRepository;
  final MembershipRepository membershipRepository;
  final SocialRepository socialRepository;
  final SecondaryRepository secondaryRepository;

  final ValueNotifier<AuthState> authState = ValueNotifier<AuthState>(AuthState.unknown);

  Future<void> bootstrapAuth() async {
    final hasSession = await authRepository.hasSession();
    if (!hasSession) {
      authState.value = AuthState.unauthenticated;
      return;
    }
    try {
      await authRepository.me();
      authState.value = AuthState.authenticated;
    } catch (_) {
      try {
        await authRepository.refresh();
        authState.value = AuthState.authenticated;
      } catch (_) {
        await authRepository.logout();
        authState.value = AuthState.unauthenticated;
      }
    }
  }
}
