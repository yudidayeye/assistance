/// 记账条目的**落位**与**拖拽合法性**判定 —— 纯函数层。
///
/// 对应规格：`specs/002-entry-time-sort/`（FR-003 / FR-005 / FR-011），
/// 接口契约见 `contracts/entry-ordering.md`。
///
/// ## 为什么是纯函数
///
/// 本模块是 `period_book` 中唯一有实质分支的逻辑，抽成纯函数后可以直接单测，
/// 不需要 `testWidgets` 或内存数据库。因此本文件**不得** import `package:flutter/*`，
/// 也**不得**触碰 `DatabaseService`——违反会在测试环境立刻暴露。
///
/// ## 日期为什么用字符串比较
///
/// 存储格式固定为 `YYYY-MM-DD`（定长、零填充），字典序**等价于**时间序，
/// 因此比较一律用 `String.compareTo`，不解析 `DateTime`：
/// 省去解析开销，也省去「本地时区 vs UTC」这种在只比较「日」时毫无意义的歧义。
///
/// ⚠️ 该性质依赖 [formatEntryDate] 的零填充。改成 `2026-1-5` 会让比较出错。
library;

/// 存储用的日期格式：`YYYY-MM-DD`，月与日**必须**零填充。
String formatEntryDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// 把存储串解析为 [DateTime]。
///
/// 对 `null`、空串、空白串与任何非法格式一律返回 `null`，**不抛异常**——
/// 旧数据或手改过的备份可能含脏值，抛异常会让整个列表渲染失败。
DateTime? parseEntryDate(String? raw) {
  if (raw == null) return null;
  final text = raw.trim();
  if (text.isEmpty) return null;
  // 只接受严格的 YYYY-MM-DD，不接受带时分的 ISO8601
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return null;
  // tryParse 会把 2026-13-99 归一化成别的日期，需回比一次确认原值合法
  if (formatEntryDate(parsed) != text) return null;
  return parsed;
}

/// 界面展示文案：同年为 `10月8日`，跨年带上年份为 `2025年12月31日`。
///
/// 无日期或非法值返回 `null`（调用方据此决定不渲染任何占位）。
/// [reference] 仅在测试中注入，用于固定「今年」。
String? formatEntryDateForDisplay(String? raw, {DateTime? reference}) {
  final date = parseEntryDate(raw);
  if (date == null) return null;
  final now = reference ?? DateTime.now();
  if (date.year == now.year) return '${date.month}月${date.day}日';
  return '${date.year}年${date.month}月${date.day}日';
}

/// 求 [entryDate] 应插入 [siblings] 的哪个下标（0 起，可为 `siblings.length`）。
///
/// [siblings] 是**同组**其他条目按当前列表顺序排列的 `entry_date` 快照
/// （同 `stage_id` 或同 `period_id`，且已排除自身）。
///
/// ## 语义
///
/// - [entryDate] 为 `null` → 返回 `siblings.length`：未填写时间的条目一律追加到末尾，
///   与改动前的行为一致（FR-002 / SC-001）。
/// - 否则返回**最小的** `i`，使 `siblings[i] != null && siblings[i] > entryDate`；
///   即落在第一个比它更晚的条目**之前**。若不存在这样的 `i`，返回 `siblings.length`。
///
/// ## 为什么扫描时要跳过 `null`
///
/// 未填写时间的条目「没有日期」，它既不属于「更早」也不属于「更晚」。
/// 若在扫描中把它当作障碍停下，一条 10月8日 的记录就会被排在它前面的
/// 无日期条目挡住而落不到位。
///
/// ## 同日条目的相对次序
///
/// 比较是**严格大于**，因此同日条目不会互相插队：新条目落在已有同日条目之后。
/// 这给了「先录的在先」这一可预期的稳定结果。
///
/// ⚠️ 调用方必须先把自身从 [siblings] 中排除，否则会把自己算进去。
int resolveInsertIndex(List<String?> siblings, String? entryDate) {
  if (entryDate == null) return siblings.length;
  for (var i = 0; i < siblings.length; i++) {
    final sibling = siblings[i];
    if (sibling == null) continue;
    if (sibling.compareTo(entryDate) > 0) return i;
  }
  return siblings.length;
}

/// 把 `ReorderableListView.onReorder` 回传的 [newIndex] 归一化为**移除后**的真实落点。
///
/// Flutter 向下拖时回传的 `newIndex` 是按「元素尚未被移除」的列表算的插入位，
/// 因此向下拖要减 1；向上拖时 `newIndex` 本身就是移除后的落点，不减。
///
/// ## 为什么单独暴露而不是藏进 [canReorder]
///
/// 调用方在通过校验后还要自己移动列表。若把归一化藏在 [canReorder] 内部，
/// 调用方极可能用未归一化的 [newIndex] 去移动，于是「校验过了但落到了别处」。
/// 暴露成独立函数强制两边走同一条路径。
int normalizeReorderIndex(int oldIndex, int newIndex) =>
    newIndex > oldIndex ? newIndex - 1 : newIndex;

/// 判定一次拖拽是否被日期约束允许（FR-011）。
///
/// [orderedEntryDates] 必须是**卡片当前渲染的那个列表**的 `entry_date` 序列
/// （不是页面的全量列表），顺序即用户看到的顺序；否则索引空间对不上。
/// [oldIndex] / [newIndex] 为 `onReorder` 原样回传的索引。
///
/// ## 语义
///
/// - 被拖条目**未填写时间** → 恒 `true`：它可以出现在任何位置（SC-005）。这是
///   硬承诺，不存在任何例外路径——判定的其余部分根本不会被执行到。
/// - 被拖条目已填时间 → 只允许留在「同日族」内部：落点**前方**不得有更晚的条目，
///   落点**后方**不得有更早的条目，否则返回 `false`（调用方必须原样保留当前顺序）。
/// - 其余未填写时间的条目在前后检查中**被跳过**，它们不构成阻挡。
/// - 无位移（`target == oldIndex`）恒 `true`。
///
/// 返回 `false` 时调用方**不得修改任何状态、不得落库**，否则用户会看到一次
/// 闪动后回弹。
///
/// ⚠️ 前置条件：`0 <= oldIndex < length`，`0 <= newIndex <= length`。越界返回 `false`。
/// **不修改** [orderedEntryDates]。
bool canReorder(List<String?> orderedEntryDates, int oldIndex, int newIndex) {
  if (oldIndex < 0 || oldIndex >= orderedEntryDates.length) return false;
  if (newIndex < 0 || newIndex > orderedEntryDates.length) return false;

  final target = normalizeReorderIndex(oldIndex, newIndex);
  if (target == oldIndex) return true;

  final moved = orderedEntryDates[oldIndex];
  if (moved == null) return true;

  // preview：把被拖条目先摘出来，再看它落在 target 处的邻居
  final preview = <String?>[...orderedEntryDates];
  preview.removeAt(oldIndex);
  preview.insert(target, moved);

  for (var i = 0; i < target; i++) {
    final other = preview[i];
    if (other == null) continue;
    if (other.compareTo(moved) > 0) return false;
  }
  for (var i = target + 1; i < preview.length; i++) {
    final other = preview[i];
    if (other == null) continue;
    if (other.compareTo(moved) < 0) return false;
  }
  return true;
}

/// 按 `ReorderableListView` 语义把 [list] 中 [oldIndex] 处的元素移到 [newIndex]。
///
/// 泛型版本，供页面直接对 `_expenses` / `_additions` 等真实列表使用。
/// **返回新列表，不修改入参**；内部复用 [normalizeReorderIndex]，与 [canReorder]
/// 共用同一套落点计算，避免「校验通过但落点不同」。
List<T> applyReorder<T>(List<T> list, int oldIndex, int newIndex) {
  final target = normalizeReorderIndex(oldIndex, newIndex);
  final next = <T>[...list];
  final moved = next.removeAt(oldIndex);
  next.insert(target, moved);
  return next;
}
