import 'package:flutter_test/flutter_test.dart';
import 'package:my_assistant/shared/widgets/number_keyboard.dart';

void main() {
  group('reduceAmountText', () {
    test('basic digit input', () {
      expect(reduceAmountText('', '1'), '1');
      expect(reduceAmountText('1', '2'), '12');
      expect(reduceAmountText('12', '3'), '123');
    });

    test('decimal point from empty', () {
      expect(reduceAmountText('', '.'), '0.');
    });

    test('decimal point already present', () {
      expect(reduceAmountText('1.5', '.'), '1.5');
    });

    test('1.00 is valid — integer part can add 00', () {
      // pre-decimal: 1 + 00 => 100
      expect(reduceAmountText('1', '00'), '100');
    });

    test('00 after decimal is blocked', () {
      // 1. + 00 should be blocked — prevents three or more decimal places
      expect(reduceAmountText('1.', '00'), '1.');
      expect(reduceAmountText('1.2', '00'), '1.2');
    });

    test('decimal places limited to 2', () {
      expect(reduceAmountText('1.5', '1'), '1.51');
      expect(reduceAmountText('1.51', '2'), '1.51');
    });

    test('0.01 is valid', () {
      expect(reduceAmountText('0.', '0'), '0.0');
      expect(reduceAmountText('0.0', '1'), '0.01');
    });

    test('leading zero replaced', () {
      expect(reduceAmountText('0', '5'), '5');
      expect(reduceAmountText('0', '0'), '0');
    });

    test('delete', () {
      expect(reduceAmountText('12', 'del'), '1');
      expect(reduceAmountText('1', 'del'), '');
      expect(reduceAmountText('', 'del'), '');
    });
  });
}
