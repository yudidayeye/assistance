# Phase 1 数据模型：记账条目可选时间与按时间排序

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md) | **Date**: 2026-10-08

---

## 1. 实体总览

本特征**不新增实体**，只为 `period_book` 模块既有的 4 个记账条目实体各增加**一个可空属性**。

```text
PeriodRecord (阶段)
  └── AdditionRecord          追加记录        [+ entryDate]
  └── ExpenseRecord           支出明细        [+ entryDate]

PeriodRecord (周期)
  └── LargeAdditionRecord     大额追加        [+ entryDate]
  └── LargeExpenseRecord      大额支出明细    [+ entryDate]
```

**位置（Sort Position）** 不是一个新实体——它由既有的 `sortOrder` 属性承载。本特征改变的是它的**地位**：从「与 `createdAt` 共同参与排序的次要键」升格为「列表顺序的唯一真相」。

---

## 2. 属性变更

4 个实体完全相同的一处新增：

| 属性 | Dart 类型 | 可空 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `entryDate` | `String?` | ✅ 是 | `null` | 该笔记录**实际发生**的日期，`YYYY-MM-DD`。`null` 表示用户未填写。 |

### 各实体完整属性

**AdditionRecord**（`lib/modules/period_book/models/addition_record.dart`）

| 属性 | 类型 | 备注 |
| :--- | :--- | :--- |
| `id` | `int?` | 自增主键 |
| `stageId` | `int` | 所属阶段 |
| `amount` | `double` | 追加金额 |
| `reason` | `String` | 追加原因 |
| `sortOrder` | `int` | **列表顺序的唯一真相** |
| `createdAt` | `String` | 创建时间（ISO8601）；仅作展示与「同日追加」的兜底排序 |
| **`entryDate`** | **`String?`** | **新增**：发生日期 |

**ExpenseRecord**：`id` / `stageId` / `category` / `amount` / `description` / `sortOrder` / `createdAt` / **`entryDate`**，另有派生 getter `isOther`。

**LargeAdditionRecord**：`id` / `periodId` / `amount` / `reason` / `sortOrder` / `createdAt` / **`entryDate`**。

**LargeExpenseRecord**：`id` / `periodId` / `category` / `amount` / `description` / `sortOrder` / `createdAt` / **`entryDate`**。

### 模型层改动清单（4 个文件同一套模式）

1. 增加 `final String? entryDate;` 字段
2. 构造函数增加 `this.entryDate`（**无默认值，非 required** → 既有全部调用点零改动）
3. `toMap()` 增加 `'entry_date': entryDate`（**不做 `?? ...` 兜底**，写 `null` 就是 `NULL`）
4. `fromMap()` 增加 `entryDate: map['entry_date'] as String?`（**关键**：旧行 / 旧备份读出来就是 `null`，无需任何迁移代码即满足 FR-006 与 FR-008）
5. `copyWith()` 增加 `String? entryDate` 形参

> ⚠️ `copyWith` 的已知陷阱：形参为 `null` 时究竟表示「不改」还是「清空」？本项目既有 `copyWith` 全部采用 `?? this.x` 语义（即 `null` = 不改）。因此**清空时间不得走 `copyWith`**，必须由 service 层直接写 `{'entry_date': null}`。见第 4 节。

---

## 3. 数据库 Schema

### 3.1 现状（v17）

4 张表结构对称，此处以 `mod_period_book_expenses` 为代表（`database_service.dart:148`）：

```sql
CREATE TABLE mod_period_book_expenses (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  stage_id    INTEGER NOT NULL,
  category    TEXT    NOT NULL,
  amount      REAL    NOT NULL,
  description TEXT    NOT NULL,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT    NOT NULL,
  FOREIGN KEY (stage_id) REFERENCES mod_period_book_stages(id) ON DELETE CASCADE
)
```

| 表名 | 归属域 | 外键 | 现有排序列 |
| :--- | :--- | :--- | :--- |
| `mod_period_book_additions` | `stage_id` | `mod_period_book_stages(id)` | `sort_order` |
| `mod_period_book_expenses` | `stage_id` | `mod_period_book_stages(id)` | `sort_order` |
| `mod_period_book_large_additions` | `period_id` | `mod_period_book_periods(id)` | `sort_order` |
| `mod_period_book_large_expenses` | `period_id` | `mod_period_book_periods(id)` | `sort_order` |

### 3.2 目标（v18）

4 张表各增一列，**其余一字不改**：

```sql
entry_date TEXT          -- 可空，无 DEFAULT
```

完整 DDL（以 expenses 为例）：

```sql
CREATE TABLE mod_period_book_expenses (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  stage_id    INTEGER NOT NULL,
  category    TEXT    NOT NULL,
  amount      REAL    NOT NULL,
  description TEXT    NOT NULL,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT    NOT NULL,
  entry_date  TEXT,                        -- ← 新增，可空
  FOREIGN KEY (stage_id) REFERENCES mod_period_book_stages(id) ON DELETE CASCADE
)
```

**不加索引**：`ORDER BY` 不涉及 `entry_date`（R1），落位扫描在内存中完成，加索引只增写入成本。

### 3.3 查询语义（**不变**）

4 个查询方法（`getExpensesByStage` / `getExpensesByPeriod` / `getExpensesByCategory` / `getAdditionsByStage` 及各 `Large*` 版本）的 `orderBy` **一律保持**：

```sql
ORDER BY sort_order ASC, created_at ASC
```

`created_at` 保留为兜底键——当 `sort_order` 因任何原因出现并列时保证顺序稳定（既有设计，本特征不改变）。

> **注意**：`entry_date` **必须不出现在任何 `ORDER BY` 中**。这是 R1 决策的核心，也是 FR-005 的实现前提。

---

## 4. 迁移与兼容规则

### 4.1 Schema 迁移

| 项 | 值 |
| :--- | :--- |
| 版本变更 | `DatabaseService._currentVersion` **17 → 18** |
| 新增函数 | `_migrateToV18(Database db)` |
| 挂载点 | `_onUpgrade` 中按既有模式追加 `if (oldVersion < 18 && newVersion >= 18) await _migrateToV18(db);` |
| 迁移语句 | 4 条 `ALTER TABLE <t> ADD COLUMN entry_date TEXT` |

**命令序列**（严格按此顺序，与 `_migrateToV7` 的写法对齐）：

```sql
ALTER TABLE mod_period_book_additions       ADD COLUMN entry_date TEXT;
ALTER TABLE mod_period_book_expenses        ADD COLUMN entry_date TEXT;
ALTER TABLE mod_period_book_large_additions ADD COLUMN entry_date TEXT;
ALTER TABLE mod_period_book_large_expenses  ADD COLUMN entry_date TEXT;
```

**同时修改 `_onCreate` 的建表 DDL**（`database_service.dart:137-195`），为 4 张表补上同一列。全新安装走 `_onCreate`，升级安装走 `_onUpgrade`，**两条路径都必须覆盖**，否则新装用户会缺列。

**迁移安全论证**：
- `ADD COLUMN` + 可空 + 无 `DEFAULT` 是 SQLite 上唯一不触发表重建的加列方式 → 满足宪法 III「禁止删表重建」
- 既有行自动取 `NULL` → 语义上即「未填写时间」→ **零数据搬迁、零丢失、零错序** → 满足 FR-006 / SC-003
- 不改动 `sort_order` 与 `created_at` → 升级前后列表顺序逐条一致

**实现前置确认**：`_migrateToV18` 依赖这 4 张表在 v18 之前必定已存在。`database_service.dart:544-596` 区段内既有的 `_migrateToV7` / `_migrateToV13` 含条件建表逻辑，实现时**必须**确认所有升级路径（尤其 v6 → v18 的跨度升级）在这条 `ALTER TABLE` 执行前 4 张表都已建好；若有路径不满足，需在 `_migrateToV18` 内加存在性判断。

### 4.2 向后兼容矩阵

| 场景 | 输入 | 期望行为 | 依据 |
| :--- | :--- | :--- | :--- |
| 升级既有库 | 旧行 `entry_date` 不存在 | 迁移后为 `NULL`，顺序不变 | FR-006 / SC-003 |
| 导入旧备份（无 `entry_date` 键） | `map['entry_date']` 为 `null` | 按「未填写时间」导入，**不报错** | FR-008 / US4-2 |
| 导入旧备份（无 `sort_order` 键，v7 前） | `map['sort_order'] ?? 0` | 保持既有兜底行为，不劣化 | 既有实现 |
| 导出新备份 | 全列带出 | JSON 含 `entry_date` | — |
| 导入新备份 | 有 `entry_date` + 有 `sort_order` | 时间与列表顺序**完整还原** | FR-008 / US4-3 |
| 结构校验 | `period_book_*` 键存在但非 List | 拒绝导入 | 既有校验（`import_export_service.dart:671-680`） |

### 4.3 备份导入的既有缺陷修复

`import_export_service.dart:428` 处 `mod_period_book_large_additions` 的 `INSERT OR REPLACE` **遗漏 `sort_order` 列**（另 3 张表均有）。

**这是本特征的前置依赖，不是可选清理**：US4 场景 3 要求「含时间字段的新备份导入后时间与列表顺序都被完整还原」，而当前该表的导入路径根本不写 `sort_order` → 大额追加的顺序会全部退化为 `created_at` 序 → FR-008 在实现当天就是坏的。

**修复**：该条 SQL 补上 `sort_order` 列与 `map['sort_order'] ?? 0` 参数，**并同时**补上 `entry_date`。

**风险**：无。旧备份中该表若 `sort_order` 全为 0（v7 之前的极老备份），修复后仍全为 0，与修复前行为一致。

---

## 5. 位置与落位的状态转移

### 5.1 位置的可变性

| 事件 | `sortOrder` 变化 | `entryDate` 变化 |
| :--- | :--- | :--- |
| 新增条目（不填时间） | 追加到同组末尾（`max+1`） | — |
| 新增条目（填了时间） | 按 R2 落位后**整组重编号** | 写入该日期 |
| 修改时间（新值非空） | 按 R2 落位后**整组重编号** | 写入新日期 |
| **清空时间** | **不变**（原地不动） | 置为 `NULL` |
| 手工拖拽（通过合法性校验） | 按新顺序**整组重编号** | 不变 |
| 手工拖拽（被拒绝） | **不变**（不落库） | 不变 |
| 删除条目 | **其余条目相对顺序不变** | — |

### 5.2 落位算法（FR-003）

**输入**：同组已按 `sort_order ASC, created_at ASC` 排序的条目列表 `siblings`（**不含**本次落位的条目）、新日期 `entryDate`。

**输出**：插入索引 `index ∈ [0, siblings.length]`。

```text
若 entryDate == null                 → index = siblings.length        # 追加到末尾
否则，对 i = 0 .. siblings.length-1：
     若 siblings[i].entryDate != null 且 siblings[i].entryDate > entryDate
                                      → index = i                      # 落在第一个更晚者之前
          （未找到）                   → index = siblings.length        # 无更晚者 → 末尾
```

**`null` 的处理**：未填时间的条目在扫描中**被跳过**——既不算「更早」也不算「更晚」。它们不构成屏障，也不被推挤。

**执行**：得到 `index` 后，构造 `nextOrder = 插入 index 后的完整列表`，对 `nextOrder` 逐项写回 `sort_order = i`（`i` 从 0 起），**包在 `DatabaseService.transaction` 中**。

### 5.3 拖拽合法性（FR-011）

**输入**：卡片当前渲染的列表 `list`、`oldIndex`、`newIndex`（`ReorderableListView` 原样回传）、被拖条目自身的 `entryDate`。

**归一化**：`target = newIndex > oldIndex ? newIndex - 1 : newIndex`（Flutter 的 `newIndex` 在向下拖时是「移除前」的插入位）。

**判定**：

```text
若 entryDate == null                → 允许（无条件任意拖动）
否则，把条目从 oldIndex 移出、插入到 target，得到 preview：
     对 preview[0 .. target-1] 中任一项 e：
           若 e.entryDate != null 且 e.entryDate > entryDate → 拒绝
     对 preview[target+1 .. ] 中任一项 e：
           若 e.entryDate != null 且 e.entryDate < entryDate → 拒绝
     否则 → 允许
```

**拒绝时**：`onReorder` 直接 `return`，**不修改任何 state、不落库**（列表自动回弹到原位），并由页面弹出 SnackBar 说明「只能在同一天内调整顺序」。满足 SC-006 的 1 秒内反馈要求。

**已填时间且列表中无同日邻居时**：允许移动（前后都找不到更晚/更早者 → 天然满足）——即在「与它日期相同的连续区块」内可自由调整。这与「仅限同一天内」的表述等价。

### 5.4 不变量

1. **同组内 `sort_order` 稠密且唯一**：任何时候同组的 `sort_order` 都是 `0..n-1` 的一个排列。所有写入路径（新增落位、修改落位、拖拽、既有 `updateXxxOrder`）都经由整组重编号，无一例外。
2. **`entry_date` 不影响任何金额计算**：所有小计 / 合计 / 余额 / 饼图构成的计算路径（`period_book_service.dart` 的聚合方法）**不得**读取 `entry_date`。依据 FR-010。
3. **`created_at` 仍是兜底序**：`ORDER BY sort_order ASC, created_at ASC` 的第二键保留。
4. **删除不重排**：`deleteXxx` 保持原实现，不触发重编号。依据 FR-012。

---

## 6. 界面数据载体（DTO）

两个 section 卡片向渲染层传递的 DTO 需要携带日期以在行内展示：

| DTO | 位置 | 新增字段 |
| :--- | :--- | :--- |
| `ExpenseItemData` | `widgets/expense_section_card.dart` | `final String? entryDate;` |
| `AdditionItemData` | `widgets/addition_section_card.dart` | `final String? entryDate;` |

`id` 字段的类型**保持不变**（`String`，由 `${e.id}` 转换）—— 页面既有的 `onEdit` / `onDelete` 都依赖这个约定，改动它会波及全部回调。

**展示规则**：`entryDate != null` 时在条目行内展示日期标记（建议跟随既有分类 chip 的视觉层级）；`null` 时不渲染任何占位，**不显示「未填写」字样**——否则每条历史记录都会多出一个噪声标签。

---

## 7. 数据规模与性能

| 项 | 量级 | 依据 |
| :--- | :--- | :--- |
| 单组条目数 | 十位数量级 | 个人记账，一个阶段/一个周期内的条目 |
| 单次落位写入 | ≤ 同组条目数条 UPDATE，单事务 | R3 整组重编号 |
| 目标耗时 | 重排结果 1 秒内可见 | SC-004 |
| 预期耗时 | 亚毫秒级（本地 SQLite，几十次 UPDATE） | 余量充足 |

无需分页、无需惰性计算、无需索引优化。
