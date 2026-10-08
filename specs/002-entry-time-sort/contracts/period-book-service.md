# 契约：PeriodBookService 接口变更

**模块**: `lib/modules/period_book/services/period_book_service.dart`
**对应**: [data-model.md §4](../data-model.md#4-迁移与兼容规则) · FR-001 ~ FR-012

本文件定义 service 层的**方法签名变更**与**语义约定**。只列变更项，未提及的方法保持不变。

---

## 设计要点

1. **`addXxx` 只增加一个可选具名参数 `entryDate`**，既有调用点零改动。
   > ⚠️ 勘误：本文件初稿写的是「签名不变、日期随模型对象传入（`record.entryDate`）」，
   > 那是对现状的误判——4 个 `addXxx` 实际接收的都是原始类型参数而非 record
   > （如 `addAddition(int stageId, double amount, String reason)`），方法体自行拼装 map。
   > 因此改为追加**可选具名**参数 `{String? entryDate}`：5 个既有调用点
   > （`stage_edit_page.dart` 3 处、`large_items_edit_page.dart` 3 处）全部无需改动，
   > 与原设计意图等价。
2. **新增与修改时间共用一条落位路径**（[research R4](../research.md)）。`addXxx` 内部在插入拿到 id 后调用与 `updateXxx` 相同的私有 `_rescheduleXxx`。`entryDate == null` 时 `_rescheduleXxx` 立即返回 → 新增无日期条目的行为与改动前**逐字节一致**（SC-001）。
3. **清空时间用显式标志**，复用 `null` 会造成歧义（[data-model §2](../data-model.md#模型层改动清单4-个文件同一套模式) 的 `copyWith` 陷阱）。**清空不得走 `copyWith`**。
4. **`updateXxxOrder` 的签名与实现全部不变**。它们在语义上已经就是「按给定顺序整组重编号」，正是落位所需要的操作——落位只是「先算出新顺序，再调它」。

---

## 1. 追加记录

### `updateAddition`（变更）

```dart
// 现状
Future<void> updateAddition(int id, {double? amount, String? reason});

// 变更后
Future<void> updateAddition(
  int id, {
  double? amount,
  String? reason,
  String? entryDate,          // 非 null → 写入并重新落位
  bool clearEntryDate = false, // true → 置 NULL，位置不变
});
```

**参数语义**（4 个 `updateXxx` 完全一致）：

| 组合 | 行为 |
| :--- | :--- |
| `entryDate = null, clearEntryDate = false` | **不动日期、不落位**（与既有行为一致） |
| `entryDate != null` | 写入该日期，随后按 FR-003 **重新落位**（整组重编号） |
| `entryDate = null, clearEntryDate = true` | 置 `entry_date = NULL`，**停在当前位置不动**（FR-004） |
| `entryDate != null && clearEntryDate == true` | **非法**，实现须 `assert` 拦截 |

**注意**：`entryDate` 为 `String?`（`YYYY-MM-DD`），而非 `DateTime`。格式化在 UI 层用 `formatEntryDate` 完成，service 层只做存取——避免同一日期在「UI 表示」与「存储表示」之间来回转换。

**既有早退行为保留**：现状是 `if (data.isEmpty) return;`。新增日期参数后，该判断须覆盖新字段——**只有 4 个参数全为空/未设时才早退**，否则「只改日期」的调用会被静默吞掉。

### `addAddition`（新增可选具名参数）

```dart
// 现状
Future<int> addAddition(int stageId, double amount, String reason);

// 变更后
Future<int> addAddition(
  int stageId, double amount, String reason, {
  String? entryDate,
});
```

**内部变更**：`insert` 的 map 中增加 `'entry_date': entryDate`；Phase 4 起，插入成功后若 `entryDate != null`，调用 `_rescheduleAddition(id, entryDate)`。

### `updateAdditionsOrder`（不变）

```dart
Future<void> updateAdditionsOrder(List<AdditionRecord> additions);  // 不变
```

与 `_rescheduleAddition` **共用同一实现**（按列表顺序写回 `sort_order: i`）。

### `_rescheduleAddition`（新增，私有）

```dart
Future<void> _rescheduleAddition(int id, String? entryDate) async;
```

**职责**（4 个 `_rescheduleXxx` 同构）：
1. `entryDate == null` → **立即返回**，不做任何写入
2. 写入 `entry_date = entryDate`
3. 查出同 `stage_id` 的全部追加记录，按 `ORDER BY sort_order ASC, created_at ASC` 排序，**排除自身**
4. 调 `resolveInsertIndex(siblings.map((e) => e.entryDate).toList(), entryDate)` 得到 `index`
5. 把自身插入 `index` 处，得到完整新顺序
6. 在 `DatabaseService.instance.transaction` 中，按新顺序写回 `sort_order: 0..n-1`
7. `_notifyChanged()`

---

## 2. 支出明细

### `updateExpense`（变更）

```dart
Future<void> updateExpense(
  int id, {
  String? category,
  double? amount,
  String? description,
  String? entryDate,
  bool clearEntryDate = false,
});
```

参数语义同上。**`category` 变更不影响落位**——跨 `isOther` 边界移动时由页面重新组装列表（[data-model §5.4](../data-model.md#54-不变量)）。

### `addExpense`（新增可选具名参数）

```dart
Future<int> addExpense(
  int stageId, String category, double amount, String description, {
  String? entryDate,
});
```

**内部变更**：`insert` 的 map 中增加 `'entry_date': entryDate`；Phase 4 起，插入后若 `entryDate != null`，调用 `_rescheduleExpense(id, entryDate)`。

### `getExpensesByStage` / `getExpensesByPeriod` / `getExpensesByCategory`（全部不变）

`orderBy` 保持 `'sort_order ASC, created_at ASC'`。**`entry_date` 不得出现在任何 `ORDER BY` 中**（FR-005 / [research R1](../research.md)）。

### `updateExpensesOrder`（不变）

### `_rescheduleExpense`（新增，私有）

同 `_rescheduleAddition`，外键列换成 `stage_id`。

---

## 3. 大额记录

### `updateLargeAddition` / `updateLargeExpense`（变更）

```dart
Future<void> updateLargeAddition(
  int id, {
  double? amount,
  String? reason,
  String? entryDate,
  bool clearEntryDate = false,
});

Future<void> updateLargeExpense(
  int id, {
  String? category,
  double? amount,
  String? description,
  String? entryDate,
  bool clearEntryDate = false,
});
```

### `addLargeAddition` / `addLargeExpense`（新增可选具名参数）

```dart
Future<int> addLargeAddition(
  int periodId, double amount, String reason, {
  String? entryDate,
});

Future<int> addLargeExpense(
  int periodId, String category, double amount, String description, {
  String? entryDate,
});
```

**内部变更**：`insert` 的 map 中增加 `'entry_date': entryDate`；Phase 4 起，插入后分别调用 `_rescheduleLargeAddition` / `_rescheduleLargeExpense`。

### `getLargeExpensesByPeriod` / `getLargeAdditionsByPeriod` / `updateLargeExpensesOrder` / `updateLargeAdditionsOrder`（全部不变）

### `_rescheduleLargeAddition` / `_rescheduleLargeExpense`（新增，私有）

外键列换成 `period_id`。

---

## 4. 不受影响的方法（显式声明）

以下方法**不得**因本特征发生任何改动。列出它们是为了让实现者明确边界：

| 类别 | 方法 | 理由 |
| :--- | :--- | :--- |
| 金额聚合 | `getStageTotalExpense` / `getStageTotalAddition` / `getPeriodTotalExpense` / 余额与饼图构成相关的全部方法 | FR-010：时间不得影响任何金额统计口径 |
| 删除 | `deleteAddition` / `deleteExpense` / `deleteLargeAddition` / `deleteLargeExpense` | FR-012：删除不触发重编号，其余条目相对顺序不变 |
| 阶段 / 周期 | `addStage` / `updateStage` / `updateStageBalance` / `getStagesByPeriod` / 全部 Period 相关方法 | 不在本特征范围内 |
| 查询 | 全部 `getXxx` | `orderBy` 必须保持原样 |

> **实现自检**：改完后 `grep -n "entry_date\|entryDate" lib/modules/period_book/services/period_book_service.dart` 的结果应当**只出现在** `addXxx` / `updateXxx` / `_rescheduleXxx` 三类方法体内，不出现在任何聚合或 `ORDER BY` 语句中。

---

## 5. 数据库层契约

### `DatabaseService`（`lib/core/storage/database_service.dart`）

| 项 | 变更 |
| :--- | :--- |
| `_currentVersion` | `17` → `18` |
| `_onCreate` 的 4 条建表 DDL | 各增 `entry_date TEXT`（可空、无 DEFAULT） |
| `_onUpgrade` | 追加 `if (oldVersion < 18 && newVersion >= 18) await _migrateToV18(db);` |
| `_migrateToV18` | **新增**，4 条 `ALTER TABLE <t> ADD COLUMN entry_date TEXT` |

**禁止**：删除或改建任何既有列、删除或重建任何表、改动 `_migrateToV1` ~ `_migrateToV17`（宪法 III）。

**允许**：使用 `DatabaseService.transaction<T>(action)`（`database_service.dart:663`，已存在，无需新增）。

### `ImportExportService`（`lib/core/settings/import_export_service.dart`）

| 位置 | 变更 |
| :--- | :--- |
| 导出（`import_export_service.dart:48-56`） | **无需改动**。导出走 `_db.query` 取全列，`entry_date` 自然进入 JSON |
| 导入 additions（`:386`） | SQL 增 `entry_date` 列与 `map['entry_date']` 参数 |
| 导入 expenses（`:406`） | 同上 |
| 导入 large_additions（`:428`） | 同上，**并补上遗漏的 `sort_order` 列**（既有缺陷，见 [data-model §4.3](../data-model.md#43-备份导入的既有缺陷修复)） |
| 导入 large_expenses（`:448`） | 同上 |
| 结构校验（`:671-680`） | **无需改动**。校验的是「键存在但非 List」，与新增字段无关 |

**导入参数的关键约定**：`map['entry_date']` **不加任何兜底**（不写 `?? ''`、不写 `?? 0`）。列可空，键缺失时 Dart 的 `map['entry_date']` 求值为 `null`，写入 SQLite 即 `NULL`，正是「未填写时间」的语义（FR-008）。

> ⚠️ 反例：写成 `map['entry_date'] ?? ''` 会让旧备份导入后得到**空串**而非 `NULL`。空串在 `resolveInsertIndex` 中**不是 null**，会被当作一个合法的日期参与比较（且 `''` 字典序小于任何 `YYYY-MM-DD`），导致这些条目在落位时被当作「极早日期」推向列表最前。**必须写 `null`。**

---

## 6. 兼容性声明

| 契约消费者 | 影响 |
| :--- | :--- |
| `stage_edit_page.dart` | 需传新的日期参数 |
| `large_items_edit_page.dart` | 需传新的日期参数 |
| 单元测试 / widget 测试 | 既有测试**不受影响**（新参数全部可选且默认不改变行为） |
| 备份文件（外部） | 旧备份可导入（FR-008）；新备份含新字段，旧版本应用导入时会忽略该列（SQL 白名单式 INSERT，不报错） |
| `vault` / `period_tracker` 模块 | **零影响**。改动全部收敛在 `period_book` 与两处 core 基础设施 |
