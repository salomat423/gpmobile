import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  TokenStorage._();
  static final TokenStorage instance = TokenStorage._();

  static const _secure = FlutterSecureStorage();
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kDeviceId = 'device_id';
  static const _kUserId = 'user_id';
  static const _kRole = 'role';
  static const _kIsLoggedIn = 'is_logged_in';
  static const _kFcmToken = 'fcm_token';

  Future<String?> readAccessToken() => _secure.read(key: _kAccess);
  Future<String?> readRefreshToken() => _secure.read(key: _kRefresh);
  Future<String?> readDeviceId() => _secure.read(key: _kDeviceId);
  Future<String?> readFcmToken() => _secure.read(key: _kFcmToken);

  Future<void> saveDeviceId(String id) => _secure.write(key: _kDeviceId, value: id);

  Future<void> saveFcmToken(String? token) async {
    if (token == null || token.isEmpty) {
      await _secure.delete(key: _kFcmToken);
      return;
    }
    await _secure.write(key: _kFcmToken, value: token);
  }

  Future<void> saveTokens({
    required String access,
    required String refresh,
    int? userId,
    String? role,
  }) async {
    await _secure.write(key: _kAccess, value: access);
    await _secure.write(key: _kRefresh, value: refresh);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsLoggedIn, true);
    if (userId != null) await prefs.setInt(_kUserId, userId);
    if (role != null && role.isNotEmpty) await prefs.setString(_kRole, role);
  }

  Future<void> clearAuth() async {
    await _secure.delete(key: _kAccess);
    await _secure.delete(key: _kRefresh);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kIsLoggedIn);
    await prefs.remove(_kUserId);
    await prefs.remove(_kRole);
  }

  Future<bool> isLoggedIn() async {
    final access = await readAccessToken();
    return access != null && access.isNotEmpty;
  }

  Future<String?> readRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRole);
  }
}
