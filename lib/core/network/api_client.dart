import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_error.dart';
import 'auth_interceptor.dart';

class ApiClient {
  ApiClient._() {
    final opts = BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {'Accept': 'application/json'},
    );
    dio = Dio(opts);
    dio.interceptors.add(
      AuthInterceptor(
        dio: dio,
        storage: TokenStorage.instance,
        refreshTokens: _refreshTokens,
      ),
    );
  }

  static final ApiClient instance = ApiClient._();
  late final Dio dio;

  Future<Map<String, String>> _refreshTokens(String refresh) async {
    final response = await Dio(BaseOptions(baseUrl: AppConfig.baseUrl)).post(
      '/auth/jwt/refresh/',
      data: {'refresh': refresh},
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw ApiError(statusCode: response.statusCode, message: 'Invalid refresh response');
    }
    return {
      'access': (data['access'] ?? '').toString(),
      'refresh': (data['refresh'] ?? '').toString(),
    };
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await dio.get(path, queryParameters: queryParameters);
      return response.data;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<dynamic> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await dio.post(path, data: data, queryParameters: queryParameters);
      return response.data;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<dynamic> patch(String path, {dynamic data}) async {
    try {
      final response = await dio.patch(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<dynamic> delete(String path, {dynamic data}) async {
    try {
      final response = await dio.delete(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  ApiError _mapDioError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    if (data != null) {
      return ApiError.fromDynamic(data, statusCode: status, fallback: 'HTTP $status');
    }
    return ApiError(statusCode: status, message: e.message ?? 'Network error');
  }
}
