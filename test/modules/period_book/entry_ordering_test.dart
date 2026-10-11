import 'package:flutter_test/flutter_test.dart';
import 'package:my_assistant/modules/period_book/services/entry_ordering.dart';

/// 覆盖 `specs/002-entry-time-sort/contracts/entry-ordering.md` 的「测试契约」。
///
/// 本文件不触碰 `DatabaseService`、也不初始化 Flutter binding：
/// `entry_ordering.dart` 是纯函数层，若它偷偷 import `package:flutter/*`
/// 或发起数据库查询，这些用例会在测试环境里直接失败——这正是该契约的可执行化断言。
void main() {
  // ═══════════════════════════════════════════════════════════
  // 日期格式工具（契约 §5）
  // ═══════════════════════════════════════════════════════════

  group('formatEntryDate', () {
    test('月与日必须零填充（定长字典序是排序比较的前提）', () {
      expect(formatEntryDate(DateTime(2026, 1, 5)), '2026-01-05');
      expect(formatEntryDate(DateTime(2026, 10, 8)), '2026-10-08');
      expect(formatEntryDate(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('输出恒为 10 个字符且字典序等于时间序', () {
      final earlier = formatEntryDate(DateTime(2026, 9, 30));
      final later = formatEntryDate(DateTime(2026, 10, 1));
      expect(earlier.length, 10);
      expect(later.length, 10);
      expect(earlier.compareTo(later) < 0, isTrue);
    });

    test('忽略时分秒', () {
      expect(
        formatEntryDate(DateTime(2026, 10, 8, 23, 59, 59)),
        '2026-10-08',
      );
    });
  });

  group('parseEntryDate', () {
    test('null 返回 null 且不抛异常', () {
      expect(parseEntryDate(null), isNull);
    });

    test('空串与空白串返回 null', () {
      expect(parseEntryDate(''), isNull);
      expect(parseEntryDate('   '), isNull);
    });

    test('非法格式返回 null 而不是抛异常（旧数据或手改备份可能含脏值）', () {
      expect(parseEntryDate('2026-13-99'), isNull);
      expect(parseEntryDate('2026-10-08T12:00:00'), isNull);
      expect(parseEntryDate('not a date'), isNull);
      expect(parseEntryDate('2026/10/08'), isNull);
    });

    test('合法值正常解析', () {
      final parsed = parseEntryDate('2026-10-08');
      expect(parsed, isNotNull);
      expect(parsed!.year, 2026);
      expect(parsed.month, 10);
      expect(parsed.day, 8);
    });

    test('与 formatEntryDate 互为逆运算', () {
      final original = DateTime(2026, 1, 5);
      final roundTrip = parseEntryDate(formatEntryDate(original));
      expect(roundTrip, isNotNull);
      expect(roundTrip!.year, original.year);
      expect(roundTrip.month, original.month);
      expect(roundTrip.day, original.day);
    });
  });

  group('formatEntryDateForDisplay', () {
    test('null 返回 null', () {
      expect(formatEntryDateForDisplay(null), isNull);
    });

    test('非法值返回 null 而不是原样吐出脏值', () {
      expect(formatEntryDateForDisplay('bogus'), isNull);
    });

    test('同年展示为「MM.dd」，补齐前导零', () {
      expect(
        formatEntryDateForDisplay('2026-10-08',
            reference: DateTime(2026, 11, 1)),
        '10.08',
      );
      expect(
        formatEntryDateForDisplay('2026-01-05',
            reference: DateTime(2026, 11, 1)),
        '01.05',
      );
    });

    test('跨年时带上年份，避免列表里新旧年份混淆', () {
      expect(
        formatEntryDateForDisplay('2025-12-31',
            reference: DateTime(2026, 1, 2)),
        '2025.12.31',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════
  // 落位（契约 §1）
  // ═══════════════════════════════════════════════════════════

  group('resolveInsertIndex', () {
    test('SC-002 端到端：依次录入「不填 / 10-09 / 不填 / 10-08」得到 0-3-1-2', () {
      // order 记录「原始录入序号」，用它还原用户实际看到的那 4 条
      final order = <int>[];
      final dates = <String?>[];

      void add(int createdIndex, String? entryDate) {
        final at = resolveInsertIndex(dates, entryDate);
        order.insert(at, createdIndex);
        dates.insert(at, entryDate);
      }

      add(0, null);
      add(1, '2026-10-09');
      add(2, null);
      add(3, '2026-10-08');

      expect(order, [0, 3, 1, 2]);
    });

    test('空列表返回 0', () {
      expect(resolveInsertIndex(const [], '2026-10-08'), 0);
      expect(resolveInsertIndex(const [], null), 0);
    });

    test('未填写时间恒追加到末尾', () {
      expect(resolveInsertIndex(const [null, '2026-10-08'], null), 2);
      expect(resolveInsertIndex(const ['2026-10-08', '2026-10-09'], null), 2);
    });

    test('落在第一个「更晚」者之前，且扫描中跳过 null 元素', () {
      // null 既不算更早也不算更晚：它不能作为障碍挡住落位
      expect(
        resolveInsertIndex(const [null, '2026-10-09', null], '2026-10-08'),
        1,
      );
    });

    test('同日条目排在其后（比较是严格大于，同日不插队）', () {
      expect(
        resolveInsertIndex(const ['2026-10-08', '2026-10-08'], '2026-10-08'),
        2,
      );
    });

    test('没有更晚者时追加到末尾', () {
      expect(
        resolveInsertIndex(
            const ['2026-10-01', null, '2026-10-07'], '2026-10-08'),
        3,
      );
    });

    test('不修改入参', () {
      final siblings = <String?>[null, '2026-10-09'];
      resolveInsertIndex(siblings, '2026-10-08');
      expect(siblings, [null, '2026-10-09']);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // 拖拽（契约 §2 / §3 / §4）
  // ═══════════════════════════════════════════════════════════

  group('normalizeReorderIndex', () {
    test('向下拖时减 1（Flutter 回传的是移除前的插入位）', () {
      expect(normalizeReorderIndex(0, 1), 0);
      expect(normalizeReorderIndex(0, 2), 1);
      expect(normalizeReorderIndex(1, 3), 2);
    });

    test('向上拖与原地不动时原样返回', () {
      expect(normalizeReorderIndex(2, 0), 0);
      expect(normalizeReorderIndex(2, 1), 1);
      expect(normalizeReorderIndex(1, 1), 1);
    });
  });

  group('canReorder', () {
    test('SC-005 未填写时间的条目拖到任意位置恒为 true', () {
      // 目标落点落在这两条有日期条目之间
      final dates = <String?>['2026-10-08', '2026-10-10', null];
      expect(canReorder(dates, 2, 1), isTrue);
      // 拖到最前
      expect(canReorder(dates, 2, 0), isTrue);
      // 本身就在末尾，拖到末尾
      expect(canReorder(dates, 2, 3), isTrue);
    });

    test('SC-005 未填写时间的条目在两个有日期条目之间来回拖动均不被拒绝', () {
      final dates = <String?>['2026-10-08', null, '2026-10-10'];
      expect(canReorder(dates, 1, 0), isTrue);
      expect(canReorder(dates, 1, 3), isTrue);
    });

    test('有日期条目拖到更晚条目之后 → false', () {
      final dates = <String?>['2026-10-08', '2026-10-10'];
      expect(canReorder(dates, 0, 2), isFalse);
    });

    test('有日期条目拖到更早条目之前 → false', () {
      final dates = <String?>['2026-10-08', '2026-10-10'];
      expect(canReorder(dates, 1, 0), isFalse);
    });

    test('同日条目之间调整顺序 → true', () {
      final dates = <String?>['2026-10-08', '2026-10-08'];
      expect(canReorder(dates, 0, 2), isTrue);
    });

    test('无位移恒为 true', () {
      final dates = <String?>['2026-10-08', '2026-10-10'];
      expect(canReorder(dates, 0, 0), isTrue);
      expect(canReorder(dates, 0, 1), isTrue);
      expect(canReorder(dates, 1, 1), isTrue);
      expect(canReorder(dates, 1, 2), isTrue);
    });

    test('无日期条目不构成阻挡：有日期条目穿过它仍是合法范围', () {
      // 10-08 拖到 10-10 之前：中间那条没有日期，既不算更早也不算更晚
      final dates = <String?>['2026-10-08', null, '2026-10-10'];
      expect(canReorder(dates, 0, 2), isTrue);
    });

    test('不修改入参', () {
      final dates = <String?>['2026-10-08', null, '2026-10-10'];
      canReorder(dates, 0, 3);
      expect(dates, ['2026-10-08', null, '2026-10-10']);
    });
  });

  group('applyReorder', () {
    test('向下拖落点正确', () {
      expect(applyReorder(['a', 'b', 'c'], 0, 2), ['b', 'a', 'c']);
      expect(applyReorder(['a', 'b', 'c'], 0, 3), ['b', 'c', 'a']);
    });

    test('向上拖落点正确', () {
      expect(applyReorder(['a', 'b', 'c'], 2, 0), ['c', 'a', 'b']);
      expect(applyReorder(['a', 'b', 'c'], 2, 1), ['a', 'c', 'b']);
    });

    test('无位移时顺序不变', () {
      expect(applyReorder(['a', 'b', 'c'], 1, 1), ['a', 'b', 'c']);
      expect(applyReorder(['a', 'b', 'c'], 1, 2), ['a', 'b', 'c']);
    });

    test('不修改入参', () {
      final list = ['a', 'b', 'c'];
      applyReorder(list, 0, 2);
      expect(list, ['a', 'b', 'c']);
    });
  });
}
