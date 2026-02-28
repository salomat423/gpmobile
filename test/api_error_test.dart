import 'package:flutter_test/flutter_test.dart';
import 'package:gppadel/core/network/api_error.dart';

void main() {
  test('ApiError uses detail field', () {
    final e = ApiError.fromDynamic({'detail': 'Неверный код'}, statusCode: 400);
    expect(e.statusCode, 400);
    expect(e.message, 'Неверный код');
  });

  test('ApiError uses first field error list value', () {
    final e = ApiError.fromDynamic({
      'code': ['Код истек'],
    });
    expect(e.message, 'Код истек');
  });

  test('ApiError falls back when payload unknown', () {
    final e = ApiError.fromDynamic('oops', fallback: 'Unknown');
    expect(e.message, 'Unknown');
  });
}
