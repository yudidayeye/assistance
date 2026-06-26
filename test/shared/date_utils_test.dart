import 'package:flutter_test/flutter_test.dart';
import 'package:my_assistant/shared/utils/date_utils.dart';

void main() {
  group('AppDateUtils.dateOnly', () {
    test('strips time', () {
      final dt = DateTime(2026, 6, 15, 12, 30, 45, 123);
      final result = AppDateUtils.dateOnly(dt);
      expect(result.year, 2026);
      expect(result.month, 6);
      expect(result.day, 15);
      expect(result.hour, 0);
      expect(result.minute, 0);
      expect(result.second, 0);
      expect(result.millisecond, 0);
    });
  });

  group('AppDateUtils.isDateInRangeInclusive', () {
    test('cross-month range', () {
      // 2026-01-30 to 2026-02-03
      final start = DateTime(2026, 1, 30);
      final end = DateTime(2026, 2, 3);

      expect(AppDateUtils.isDateInRangeInclusive(DateTime(2026, 1, 30), start, end), true);
      expect(AppDateUtils.isDateInRangeInclusive(DateTime(2026, 2, 1), start, end), true);
      expect(AppDateUtils.isDateInRangeInclusive(DateTime(2026, 2, 2), start, end), true);
      expect(AppDateUtils.isDateInRangeInclusive(DateTime(2026, 2, 3), start, end), true);
      // outside
      expect(AppDateUtils.isDateInRangeInclusive(DateTime(2026, 1, 29), start, end), false);
      expect(AppDateUtils.isDateInRangeInclusive(DateTime(2026, 2, 4), start, end), false);
    });

    test('cross-year range', () {
      // 2025-12-30 to 2026-01-03
      final start = DateTime(2025, 12, 30);
      final end = DateTime(2026, 1, 3);

      expect(AppDateUtils.isDateInRangeInclusive(DateTime(2025, 12, 30), start, end), true);
      expect(AppDateUtils.isDateInRangeInclusive(DateTime(2026, 1, 1), start, end), true);
      expect(AppDateUtils.isDateInRangeInclusive(DateTime(2026, 1, 2), start, end), true);
      expect(AppDateUtils.isDateInRangeInclusive(DateTime(2026, 1, 3), start, end), true);
      // outside
      expect(AppDateUtils.isDateInRangeInclusive(DateTime(2025, 12, 29), start, end), false);
      expect(AppDateUtils.isDateInRangeInclusive(DateTime(2026, 1, 4), start, end), false);
    });

    test('same month range', () {
      final start = DateTime(2026, 6, 10);
      final end = DateTime(2026, 6, 15);

      expect(AppDateUtils.isDateInRangeInclusive(DateTime(2026, 6, 10), start, end), true);
      expect(AppDateUtils.isDateInRangeInclusive(DateTime(2026, 6, 12), start, end), true);
      expect(AppDateUtils.isDateInRangeInclusive(DateTime(2026, 6, 15), start, end), true);
      expect(AppDateUtils.isDateInRangeInclusive(DateTime(2026, 6, 9), start, end), false);
      expect(AppDateUtils.isDateInRangeInclusive(DateTime(2026, 6, 16), start, end), false);
    });
  });
}
