import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'api_error.dart';

typedef RefreshTokensFn = Future<Map<String, String>> Function(String refreshToken);

class AuthInterceptor extends Interceptor {
  final Dio dio;
  final TokenStorage storage;
  final RefreshTokensFn refreshTokens;

  bool _refreshing = false;
  Completer<void>? _refreshCompleter;

  AuthInterceptor({
    required this.dio,
    required this.storage,
    required this.refreshTokens,
  });

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await storage.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 || err.requestOptions.path.contains('/auth/jwt/refresh/')) {
      return handler.next(err);
    }

    try {
      await _refreshTokenIfNeeded();
      final newToken = await storage.readAccessToken();
      if (newToken == null || newToken.isEmpty) {
        throw ApiError(statusCode: 401, message: 'Session expired');
      }
      final req = err.requestOptions;
      req.headers['Authorization'] = 'Bearer $newToken';
      final response = await dio.fetch(req);
      return handler.resolve(response);
    } catch (_) {
      await storage.clearAuth();
      return handler.next(err);
    }
  }

  Future<void> _refreshTokenIfNeeded() async {
    if (_refreshing) {
      await _refreshCompleter?.future;
      return;
    }
    _refreshing = true;
    _refreshCompleter = Completer<void>();
    try {
      final refreshToken = await storage.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        throw ApiError(statusCode: 401, message: 'No refresh token');
      }
      final tokens = await refreshTokens(refreshToken);
      final access = tokens['access'];
      final refresh = tokens['refresh'];
      if (access == null || refresh == null) {
        throw ApiError(statusCode: 401, message: 'Refresh failed');
      }
      await storage.saveTokens(access: access, refresh: refresh);
      _refreshCompleter?.complete();
    } catch (e) {
      _refreshCompleter?.completeError(e);
      rethrow;
    } finally {
      _refreshing = false;
      _refreshCompleter = null;
    }
  }
}
