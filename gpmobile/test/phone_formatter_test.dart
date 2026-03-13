import 'package:flutter_test/flutter_test.dart';
import 'package:gppadel/screens/auth_screen.dart';

void main() {
  test('KzPhoneFormatter adds spaces', () {
    const oldValue = TextEditingValue.empty;
    const newValue = TextEditingValue(text: '7000000000');
    final formatter = KzPhoneFormatter();

    final formatted = formatter.formatEditUpdate(oldValue, newValue);
    expect(formatted.text, '700 000 00 00');
  });

  test('KzPhoneFormatter blocks over 10 digits', () {
    final formatter = KzPhoneFormatter();
    const oldValue = TextEditingValue(text: '700 000 00 00');
    const newValue = TextEditingValue(text: '70000000001');
    final formatted = formatter.formatEditUpdate(oldValue, newValue);
    expect(formatted.text, oldValue.text);
  });
}
