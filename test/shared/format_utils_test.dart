import 'package:flutter_test/flutter_test.dart';
import 'package:my_assistant/shared/utils/format_utils.dart';

void main() {
  group('FormatUtils.formatAmount', () {
    test('positive integer', () {
      expect(FormatUtils.formatAmount(100), '¥100');
    });

    test('positive decimal', () {
      expect(FormatUtils.formatAmount(99.99), '¥99.99');
    });

    test('zero', () {
      expect(FormatUtils.formatAmount(0), '¥0');
    });

    test('negative amount shows absolute value', () {
      // formatAmount is for transaction entries — always shows positive
      expect(FormatUtils.formatAmount(-50), '¥50');
    });
  });

  group('FormatUtils.formatBalance', () {
    test('positive balance', () {
      expect(FormatUtils.formatBalance(500), '¥500');
    });

    test('negative balance preserves sign', () {
      expect(FormatUtils.formatBalance(-200), '¥-200');
    });

    test('zero balance', () {
      expect(FormatUtils.formatBalance(0), '¥0');
    });

    test('negative decimal preserves sign', () {
      expect(FormatUtils.formatBalance(-150.50), '¥-150.50');
    });
  });

  group('FormatUtils.formatPercent', () {
    test('50%', () {
      expect(FormatUtils.formatPercent(0.5), '50%');
    });

    test('33.3%', () {
      expect(FormatUtils.formatPercent(0.333), '33%');
    });

    test('100%', () {
      expect(FormatUtils.formatPercent(1.0), '100%');
    });

    test('0%', () {
      expect(FormatUtils.formatPercent(0), '0%');
    });
  });
}
