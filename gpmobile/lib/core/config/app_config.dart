class AppConfig {
  AppConfig._();

  static const String baseUrl = 'http://213.155.23.227/api';
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);

  static String withApi(String path) {
    if (path.startsWith('/')) return '$baseUrl$path';
    return '$baseUrl/$path';
  }
}
