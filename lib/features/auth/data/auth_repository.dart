import 'dart:math';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

class AuthRepository {
  AuthRepository(this._api, this._storage);

  final ApiClient _api;
  final TokenStorage _storage;

  Future<void> sendCode(String phoneNumber) async {
    await _api.post('/auth/mobile/send-code/', data: {'phone_number': phoneNumber});
  }

  Future<Map<String, dynamic>> login({
    required String phoneNumber,
    required String code,
    String? fcmToken,
  }) async {
    final deviceId = await _ensureDeviceId();
    final data = await _api.post('/auth/mobile/login/', data: {
      'phone_number': phoneNumber,
      'code': code,
      'device_id': deviceId,
    });
    final map = Map<String, dynamic>.from(data as Map);
    final access = (map['access'] ?? '').toString();
    final refresh = (map['refresh'] ?? '').toString();
    final userId = map['user_id'] is int ? map['user_id'] as int : int.tryParse('${map['user_id']}');
    await _storage.saveTokens(
      access: access,
      refresh: refresh,
      userId: userId,
      role: map['role']?.toString(),
    );
    await _postLoginSyncFcm(fcmToken);
    return map;
  }

  Future<Map<String, dynamic>> crmLogin({
    required String username,
    required String password,
    String? fcmToken,
  }) async {
    final data = await _api.post('/auth/crm/login/', data: {
      'username': username,
      'password': password,
    });
    final map = Map<String, dynamic>.from(data as Map);
    final access = (map['access'] ?? '').toString();
    final refresh = (map['refresh'] ?? '').toString();
    final userId = map['user_id'] is int ? map['user_id'] as int : int.tryParse('${map['user_id']}');
    await _storage.saveTokens(
      access: access,
      refresh: refresh,
      userId: userId,
      role: map['role']?.toString(),
    );
    await _postLoginSyncFcm(fcmToken);
    return map;
  }

  Future<Map<String, dynamic>> refresh() async {
    final refreshToken = await _storage.readRefreshToken();
    final data = await _api.post('/auth/jwt/refresh/', data: {'refresh': refreshToken});
    final map = Map<String, dynamic>.from(data as Map);
    final nextRefresh = (map['refresh'] ?? refreshToken ?? '').toString();
    await _storage.saveTokens(
      access: (map['access'] ?? '').toString(),
      refresh: nextRefresh,
    );
    return map;
  }

  Future<Map<String, dynamic>> me() async {
    final data = await _api.get('/auth/users/me/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> payload) async {
    final data = await _api.patch('/auth/users/me/', data: payload);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> uploadAvatar(String filePath) async {
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(filePath),
    });
    final data = await _api.patch('/auth/users/me/', data: formData);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> saveFcm(String? token) async {
    await _storage.saveFcmToken(token);
    await _api.post('/auth/me/fcm/', data: {'fcm_token': token});
  }

  Future<void> syncFcmFromStorage() async {
    final token = await _storage.readFcmToken();
    if (token == null || token.isEmpty) return;
    await _api.post('/auth/me/fcm/', data: {'fcm_token': token});
  }

  Future<void> logoutWithBlacklist() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _api.post('/auth/jwt/blacklist/', data: {'refresh': refreshToken});
      } catch (_) {}
    }
    await _storage.clearAuth();
  }

  Future<void> deleteAccount() async {
    await _api.delete('/auth/me/delete/', data: {'confirm': true});
    await _storage.clearAuth();
  }

  Future<Map<String, dynamic>> stats() async {
    final data = await _api.get('/auth/me/stats/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> league() async {
    final data = await _api.get('/auth/me/league/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> home() async {
    final data = await _api.get('/auth/home/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final data = await _api.get('/auth/search/', queryParameters: {'search': query});
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> publicUserProfile(int id) async {
    final data = await _api.get('/auth/users/$id/profile/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> coaches() async {
    final data = await _api.get('/auth/coaches/');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> logout() async => _storage.clearAuth();

  Future<bool> hasSession() => _storage.isLoggedIn();

  Future<String> _ensureDeviceId() async {
    final existing = await _storage.readDeviceId();
    if (existing != null && existing.isNotEmpty) return existing;
    final fallback = 'ios-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 32)}-${const Uuid().v4()}';
    await _storage.saveDeviceId(fallback);
    return fallback;
  }

  Future<void> _postLoginSyncFcm(String? fcmToken) async {
    try {
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await saveFcm(fcmToken);
        return;
      }
      await syncFcmFromStorage();
    } catch (_) {}
  }
}
