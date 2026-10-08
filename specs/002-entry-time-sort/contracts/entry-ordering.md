# 契约：条目排序纯函数

**模块**: `lib/modules/period_book/services/entry_ordering.dart`（**新建文件**）
**对应**: [data-model.md §5](../data-model.md#5-位置与落位的状态转移) · FR-003 / FR-005 / FR-011

本文件定义落位与拖拽判定的**接口契约**。实现必须符合此处签名与语义，不得偏离。

---

## 设计要点

1. **纯函数、无 IO、无 Flutter 依赖**：不 import `dart:ui` / `package:flutter/*`，不触碰数据库。这是宪法 IV「贴近改动的测试」能低成本落地的前提——单测直接调用，不需要 `testWidgets` 或内存数据库。
2. **以「日期列」为输入载体**：函数只接收 `List<String?>`（即一组条目的 `entryDate` 序列），而非 4 个模型类。理由：
   - 4 个模型类在这一逻辑上是**同构**的，为每个类写一份函数是纯粹的重复；
   - 页面只需 `list.map((e) => e.entryDate).toList()` 即可调用，索引与原列表 **1:1 对应**，无需回映射；
   - 测试无需构造任何模型对象。
3. **日期比较用字符串 `compareTo`，不解析 `DateTime`**：`YYYY-MM-DD` 为定长零填充格式，字典序 **等价于** 时间序（见 [research.md R6](./../research.md)）。省去解析开销，也省去「本地时区 vs UTC」这类在只比较「日」的场景下毫无意义的歧义。
4. **`null` 一律表示「未填写时间」**，且在所有比较中**被跳过**——既不算更早也不算更晚。这是 FR-005 在代码层面的唯一落点。

---

## 公开接口

### 1. `resolveInsertIndex`

```dart
/// 计算一条新条目应插入的位置。
///
/// [siblings] 是同一分组内**已按 sort_order 排好序**的条目的 entryDate 序列，
/// 且**不包含**本次要落位的条目本身。元素为 null 表示该条目未填写时间。
/// [entryDate] 是本次要落位的条目自身的日期，null 表示未填写。
///
/// 返回插入索引，取值区间为 [0, siblings.length]。
int resolveInsertIndex(List<String?> siblings, String? entryDate);
```

**语义**（FR-003）：

| 条件 | 返回 |
| :--- | :--- |
| `entryDate == null` | `siblings.length`（追加到末尾） |
| 存在最小的 `i` 使 `siblings[i] != null && siblings[i].compareTo(entryDate) > 0` | `i`（落在第一个更晚者**之前**） |
| 不存在这样的 `i` | `siblings.length`（末尾） |

**不变量**：
- 返回值**永不越界**：`0 <= result <= siblings.length`
- `siblings` 为空时恒返回 `0`
- **不修改** `siblings`（不排序、不插入）
- 与 `entryDate` 相同的日期**不**构成阻挡（`> 0` 严格大于）→ 新条目落在已有同日条目**之后**，即同日多次录入按录入正序排列

### 2. `normalizeReorderIndex`

```dart
/// 把 ReorderableListView.onReorder 回传的 newIndex 归一化为实际落点索引。
///
/// Flutter 在向下拖动时回传的 newIndex 是「元素被移除之前」的插入位，
/// 因此需要减 1 才是移除后的真实落点。
int normalizeReorderIndex(int oldIndex, int newIndex);
```

**语义**：`newIndex > oldIndex ? newIndex - 1 : newIndex`

**为什么必须显式暴露**：这是 `ReorderableListView` 的一个反直觉约定，把它藏进 `canReorder` 内部会让调用方在「自己移动列表」时用错索引，造成校验与实际落点不一致——即「校验通过了但落到了别处」。暴露成独立函数强制调用方走同一条路径。

### 3. `canReorder`

```dart
/// 判定一次拖拽是否被日期约束允许。
///
/// [orderedEntryDates] 是**卡片当前渲染的那个列表**（不是页面的全量列表）的
/// entryDate 序列，顺序即用户看到的顺序。
/// [oldIndex]、[newIndex] 为 ReorderableListView.onReorder 原样回传的索引。
///
/// 返回 true 表示允许落位，false 表示必须拒绝（调用方不得修改任何状态）。
bool canReorder(List<String?> orderedEntryDates, int oldIndex, int newIndex);
```

**前置条件**：`0 <= oldIndex < orderedEntryDates.length`；`0 <= newIndex <= orderedEntryDates.length`。调用方保证；违反时实现可以 `RangeError` 或直接返回 `false`（取其一并保持一致）。

**语义**（FR-011）：

| 条件 | 返回 |
| :--- | :--- |
| `orderedEntryDates[oldIndex] == null` | **`true`**（未填写时间 → 无条件任意拖动，SC-005） |
| 被拖条目已填时间，且在目标落点**前方**存在 `d != null && d > entryDate` | `false` |
| 被拖条目已填时间，且在目标落点**后方**存在 `d != null && d < entryDate` | `false` |
| 其他 | `true` |

**判定步骤**（实现必须等价于此）：
1. `target = normalizeReorderIndex(oldIndex, newIndex)`
2. 若 `target == oldIndex` → `true`（无位移）
3. 令 `moved = orderedEntryDates[oldIndex]`，构造 `preview` = 将 `oldIndex` 处元素移到 `target` 后的新序列
4. 若 `moved == null` → `true`；否则按上表检查 `preview` 中 `target` 之前/之后的元素

**不变量**：
- `moved == null` 时**恒为 `true`**——不存在任何例外路径。这是 SC-005「无一例被拒绝」的直接保证，单测必须覆盖「无日期条目在两个有日期条目之间来回拖动」。
- **不修改** `orderedEntryDates`
- 未填时间的**其他**条目在 `preview` 的前后检查中**被跳过**，不构成阻挡（它们可以待在任意位置）

### 4. `applyReorder`

```dart
/// 按 ReorderableListView 的语义把 [list] 中的元素从 [oldIndex] 移到 [newIndex]。
///
/// 泛型版本，供页面直接对 _expenses / _additions 等真实列表使用。
List<T> applyReorder<T>(List<T> list, int oldIndex, int newIndex);
```

**语义**：先按 `normalizeReorderIndex` 归一化，再移出+插入；**返回新列表，不修改入参**。

**存在理由**：页面若自己手写这段移动，就会与 `canReorder` 内部的 `preview` 构造形成第二份实现；两份一旦漂移，就会出现「校验通过但落点不同」。共用同一函数即可消除。

### 5. 日期格式工具

```dart
/// 把 DateTime 格式化为存储用的 YYYY-MM-DD 字符串（零填充）。
String formatEntryDate(DateTime date);

/// 把存储用的 YYYY-MM-DD 字符串解析为 DateTime；解析失败返回 null。
DateTime? parseEntryDate(String? raw);

/// 把 YYYY-MM-DD 格式化为界面展示文案（如 "10月8日"）；null 返回 null。
String? formatEntryDateForDisplay(String? raw);
```

**约定**：
- `formatEntryDate` 月/日**必须零填充**（`2026-10-08` 而非 `2026-10-8`），否则定长字典序性质被破坏，`compareTo` 比较将出错。**这是本契约最容易踩的坑，单测必须覆盖个位数月/日**。
- `parseEntryDate` 对 `null`、空串、非法格式一律返回 `null`，**不抛异常**——旧数据或手改的备份可能含脏值，抛异常会让整个列表渲染失败。
- `formatEntryDateForDisplay` 与 `formatEntryDate` 输出**不同**：前者面向用户（`10月8日`），后者面向存储。不得混用。

---

## 调用方契约（页面侧）

`stage_edit_page.dart` 与 `large_items_edit_page.dart` 的 `onReorder` 处理器必须遵循：

```text
onReorder(oldIndex, newIndex):
  1. dates = <卡片当前列表>.map((e) => e.entryDate).toList()
  2. if (!canReorder(dates, oldIndex, newIndex)):
         showSnackBar('已填写时间的条目只能在同一天内调整顺序')   # SC-006
         return                                                  # 不修改任何 state、不落库
  3. next = applyReorder(<卡片当前列表>, oldIndex, newIndex)
  4. 把 next 写回页面 state，并调用对应的 updateXxxOrder(...)
```

**禁止**：
- ❌ 在 `canReorder` 返回 false 时仍改动 state 再回滚（会造成可见的闪烁）
- ❌ 用页面的全量 `_expenses` 构造 `dates`（索引空间与卡片不符，见 [research R5](./../research.md)）
- ❌ 在筛选态（`_expenseFilter != null`）下启用 `onReorder` —— 既有代码已用 `onReorder: filter != null ? null : _onShoppingReorder` 禁用，**保持不动**

---

## 测试契约

`test/modules/period_book/entry_ordering_test.dart` **必须**覆盖：

| # | 用例 | 依据 |
| :--- | :--- | :--- |
| 1 | SC-002 端到端序列：`null → 10-09 → null → 10-08` 依次落位得到 `0-3-1-2` 顺序 | SC-002 |
| 2 | `resolveInsertIndex` 在 `siblings` 为空时返回 `0` | — |
| 3 | `resolveInsertIndex` 传入 `null` 恒返回 `siblings.length` | FR-003 |
| 4 | `resolveInsertIndex` 落在第一个更晚者之前（跳过 `null` 元素） | FR-003 |
| 5 | 个位数月/日的零填充：`DateTime(2026,1,5)` → `'2026-01-05'` | 契约 §5 |
| 6 | `parseEntryDate` 对 `null` / `''` / `'2026-13-99'` 返回 `null` 不抛异常 | 契约 §5 |
| 7 | `canReorder`：未填时间条目拖到任意位置恒为 `true`（含两个有日期条目之间） | SC-005 / FR-011 |
| 8 | `canReorder`：有日期条目拖到更晚条目之后 → `false` | FR-011 / US3-3 |
| 9 | `canReorder`：有日期条目拖到更早条目之前 → `false` | FR-011 / US3-4 |
| 10 | `canReorder`：同日条目之间调整 → `true` | US3-2 |
| 11 | `normalizeReorderIndex` 向下拖时减 1 | 契约 §2 |
| 12 | `applyReorder` 向下拖与向上拖的落点都正确，且不改入参 | 契约 §4 |
