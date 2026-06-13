import 'package:flutter_test/flutter_test.dart';
import 'package:wareeny/shared/emergency/phone_number_normalizer.dart';

void main() {
  const normalizer = PhoneNumberNormalizer();

  test('normalizes an Egyptian local mobile number to E.164', () {
    expect(normalizer.normalize('0100 123 4567'), '+201001234567');
  });

  test('preserves a valid international number', () {
    expect(normalizer.normalize('+1 415-555-2671'), '+14155552671');
  });

  test('rejects invalid numbers', () {
    expect(normalizer.normalize('123'), isNull);
  });
}
