class ApiError implements Exception {
  final int? statusCode;
  final String message;

  ApiError({this.statusCode, required this.message});

  factory ApiError.fromDynamic(dynamic data, {int? statusCode, String fallback = 'Request failed'}) {
    if (data is Map<String, dynamic>) {
      if (data['detail'] != null) {
        return ApiError(statusCode: statusCode, message: data['detail'].toString());
      }
      if (data['error'] != null) {
        return ApiError(statusCode: statusCode, message: data['error'].toString());
      }
      for (final entry in data.entries) {
        final value = entry.value;
        if (value is List && value.isNotEmpty) {
          return ApiError(statusCode: statusCode, message: value.first.toString());
        }
      }
    }
    return ApiError(statusCode: statusCode, message: fallback);
  }

  @override
  String toString() => message;
}
