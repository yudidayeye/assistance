---
description: "Task list for feature: 记账条目可选时间与按时间排序"
---

# Tasks: 记账条目可选时间与按时间排序

**Input**: Design documents from `specs/002-entry-time-sort/`

**Prerequisites**: [plan.md](./plan.md) · [spec.md](./spec.md) · [research.md](./research.md) · [data-model.md](./data-model.md) · [contracts/](./contracts/) · [quickstart.md](./quickstart.md)

**Tests**: 本特征**包含测试任务**。依据是项目宪法 IV「新增模块逻辑 MUST 补充 unit 或 widget 测试」，而非用户显式要求 TDD。测试集中在唯一有实质分支的纯函数模块 `entry_ordering.dart`，不铺开写 widget 测试。

**Organization**: 按 user story 分组，使每个 story 可独立实现、独立验证、独立交付。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 可并行（不同文件、无未完成依赖）
- **[Story]**: 所属 user story（US1 / US2 / US3 / US4），Setup 与 Foundational 阶段无此标签
- 所有任务均含精确文件路径

## 核心设计约束（实现前必读，违反即返工）

1. **`entry_date` 是普通数据属性，绝不进入任何 `ORDER BY`**。列表顺序由 `sort_order` 独占承载。查询保持 `orderBy: 'sort_order ASC, created_at ASC'` 一字不改。
2. **清空时间不得走 `copyWith`**。模型既有 `copyWith` 采用 `?? this.x` 语义，`null` 表示「不改」，无法表达「清空」。清空必须由 service 层的 `clearEntryDate: true` 标志直接写 `{'entry_date': null}`。
3. **导入时 `map['entry_date']` 不得写任何兜底**（不写 `?? ''`、不写 `?? 0`）。空串不是 `null`，会被当作合法日期参与比较且字典序小于一切 `YYYY-MM-DD`，导致旧数据全被推到列表最前。
4. **`formatEntryDate` 月/日必须零填充**（`2026-10-08` 而非 `2026-10-8`）。比较依赖定长字典序，不填充即出错。
5. **拖拽校验必须在卡片实际渲染的列表上做**，不是页面的全量 `_expenses`。索引空间不同。

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: 动工前的前置检查。本项目结构已存在，无脚手架工作。

- [ ] T001 阅读 `docs/UI.md`，确认日期字段与列表日期标记可用的设计 token（颜色/圆角/间距一律取自 `Theme.of(context).appTheme` 与 `AppSpacing`，禁止硬编码）
- [ ] T002 确认 git 工作区状态：`git status` 应无无关改动，当前分支为 `20261008-225439-entry-time-sort`

**Checkpoint**: 前置条件就绪

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: schema 加列、迁移、模型加字段、日期格式工具。**所有 user story 都依赖这些**，必须先完成。

**⚠️ CRITICAL**: 本阶段完成前，任何 user story 都无法开始

### 数据库

- [ ] T003 在 `lib/core/storage/database_service.dart` 的 `_onCreate` 建表 DDL 中，为 4 张表各增加一列 `entry_date TEXT`（**可空、无 DEFAULT**，加在 `created_at` 之后）：`mod_period_book_additions`、`mod_period_book_expenses`、`mod_period_book_large_additions`、`mod_period_book_large_expenses`
- [ ] T004 将 `lib/core/storage/database_service.dart` 的 `_currentVersion` 由 `17` 递增为 `18`，新增 `_migrateToV18(Database db)`，并在 `_onUpgrade` 中按既有模式挂载 `if (oldVersion < 18 && newVersion >= 18) await _migrateToV18(db);`。迁移体为 4 条：`ALTER TABLE <t> ADD COLUMN entry_date TEXT`（表名同 T003）。**禁止**删除或重建任何表，**禁止**改动 `_migrateToV1` ~ `_migrateToV17`
- [ ] T005 核查 `lib/core/storage/database_service.dart:544-596` 区段内 `_migrateToV7` / `_migrateToV13` 的条件建表逻辑，确认**所有升级路径**（尤其 v6 → v18 跨度升级）在 T004 的 `ALTER TABLE` 执行前 4 张表都已存在；若有路径不满足，在 `_migrateToV18` 内补存在性判断（查询 `sqlite_master` 或 `PRAGMA table_info`）

### 模型（4 个文件同一套 5 步改动模式）

> 每个模型的改动：① 增 `final String? entryDate;` ② 构造函数增 `this.entryDate`（**无默认值、非 required**，保证既有调用点零改动）③ `toMap()` 增 `'entry_date': entryDate`（**不加任何兜底**）④ `fromMap()` 增 `entryDate: map['entry_date'] as String?` ⑤ `copyWith()` 增 `String? entryDate`

- [ ] T006 [P] 按上述 5 步模式为 `ExpenseRecord` 增加 `entryDate`，文件 `lib/modules/period_book/models/expense_record.dart`
- [ ] T007 [P] 按上述 5 步模式为 `AdditionRecord` 增加 `entryDate`，文件 `lib/modules/period_book/models/addition_record.dart`
- [ ] T008 [P] 按上述 5 步模式为 `LargeExpenseRecord` 增加 `entryDate`，文件 `lib/modules/period_book/models/large_expense_record.dart`
- [ ] T009 [P] 按上述 5 步模式为 `LargeAdditionRecord` 增加 `entryDate`，文件 `lib/modules/period_book/models/large_addition_record.dart`

### 排序纯函数：日期格式工具

- [ ] T010 新建 `lib/modules/period_book/services/entry_ordering.dart`，实现 3 个日期工具（契约见 `contracts/entry-ordering.md` §5）：`String formatEntryDate(DateTime date)`（**月/日零填充**）、`DateTime? parseEntryDate(String? raw)`（对 `null`/空串/非法格式返回 `null`，**不抛异常**）、`String? formatEntryDateForDisplay(String? raw)`（如 `10月8日`，`null` 返回 `null`）。文件**不得** import `package:flutter/*` 或触碰数据库
- [ ] T011 [P] 新建 `test/modules/period_book/entry_ordering_test.dart`，编写日期工具用例：`DateTime(2026,1,5)` → `'2026-01-05'`（零填充）；`DateTime(2026,10,8)` → `'2026-10-08'`；`parseEntryDate` 对 `null` / `''` / `'2026-13-99'` 返回 `null` 且不抛异常；`formatEntryDateForDisplay(null)` 返回 `null`。**先写测试、确认失败，再回填 T010**

**Checkpoint**: schema、模型、迁移、格式工具就绪 —— 4 个 user story 均可开始

---

## Phase 3: User Story 1 - 新增条目时可选填写发生时间 (Priority: P1) 🎯 MVP

**Goal**: 阶段详情页与大额页的**全部 6 个新增表单**（各页面的「追加」「个人支出」「其他支出」）提供可选的日期字段；提交后条目携带该日期并**在列表行内可见**。不填时间时，新增流程与改动前完全一致。

**Independent Test**: 展开「阶段详情页 → 个人支出」表单，只填金额与描述、不填时间并确认 → 条目正常保存，操作步骤与改动前一致；再次新增并额外选一个日期 → 条目保存且行内显示该日期；提交后表单（含日期）清空。

> **本 story 不涉及落位**——填了日期的条目此时仍追加到末尾。落位是 US2 的职责，两者构成 spec 所述的最小可用闭环。

### UI 组件

- [x] T012 [P] [US1] 为 `AddForm` 增加可选日期字段，文件 `lib/modules/period_book/widgets/add_form.dart`。新增 props：`DateTime? selectedDate`、`ValueChanged<DateTime?>? onDateChanged`（**均有默认值，保证既有 7 个调用点零改动**）。渲染一行「时间（可选）」+ 可点击区域：未选时显示「不填」，已选时显示 `formatEntryDateForDisplay` 结果，已选时提供清除按钮。点击调 `showDatePicker`，沿用页面既有约定 `firstDate: DateTime(2020)` / `lastDate: DateTime(2030)`。**不得**默认预填今天
- [x] T013 [P] [US1] 在 `lib/modules/period_book/widgets/expense_section_card.dart` 的 `ExpenseItemData` 中增加 `final String? entryDate;`（`id` 保持 `String` 类型不变，既有回调依赖该约定），并在行内渲染日期标记
- [x] T014 [P] [US1] 在 `lib/modules/period_book/widgets/addition_section_card.dart` 的 `AdditionItemData` 中增加 `final String? entryDate;`，并在行内渲染日期标记
- [x] T015 [P] [US1] 在 `lib/modules/period_book/widgets/expense_category_helper.dart` 的 `buildExpenseItem` 中增加**可选** `entryDate` 参数并渲染日期标记，保证其他既有调用点（报表页等）不受影响

**展示规则**（T013 / T014 / T015 一致）：`entryDate != null` 时渲染日期标记，视觉层级跟随既有分类 chip；`null` 时**不渲染任何占位**，不显示「未填写」字样——否则每条历史记录都会多出一个噪声标签。

### Service

- [x] T016 [US1] 在 `lib/modules/period_book/services/period_book_service.dart` 中，让 4 个新增方法把 `entryDate` 落库：`addAddition` / `addExpense` / `addLargeAddition` / `addLargeExpense`。若方法体自行拼装 map（而非复用 `record.toMap()`），须在其中加入 `'entry_date': record.entryDate`。**本 story 内不改动排序逻辑**，新条目仍按既有 `max(sortOrder) + 1` 追加到末尾

### 页面接线

- [x] T017 [US1] 在 `lib/modules/period_book/pages/stage_edit_page.dart` 中：为 3 个表单（追加 / 个人支出 / 其他支出）各增加一个日期 state 字段，接入 `_buildAdditionForm` / `_buildShoppingForm` / `_buildOtherForm` 的 `selectedDate` 与 `onDateChanged`；提交时把日期写入 `AdditionRecord` / `ExpenseRecord` 的 `entryDate`；**提交成功后把日期 state 重置为 `null`**（避免连续新增把上一条日期带下去）；把 `e.entryDate` / `a.entryDate` 传入 `ExpenseItemData` / `AdditionItemData`
- [x] T018 [US1] 在 `lib/modules/period_book/pages/large_items_edit_page.dart` 中完成与 T017 相同的工作（3 个表单分别为 `_buildAdditionForm` / `_buildShoppingForm` / `_buildOtherForm`）

**Checkpoint**: 6 个表单均可选日期，条目保存后行内可见日期。US1 可独立交付

---

## Phase 4: User Story 2 - 填写时间的条目自动落到对应日期位置 (Priority: P1)

**Goal**: 填写了时间的条目在保存后落到列表中该日期应处的位置，而非被追加到末尾；修改时间会重新落位，清空时间则停在原地。列表整体呈现「按时间顺叙」的观感。

**Independent Test**: 新增一条填了较早日期的记录 → 出现在列表中对应位置而非末尾；新增一条不填时间的记录 → 追加到末尾。**判定性验收见 T024（SC-002）**。

### 排序算法（含测试先行）

- [x] T019 [US2] 在 `lib/modules/period_book/services/entry_ordering.dart` 中实现 `int resolveInsertIndex(List<String?> siblings, String? entryDate)`（契约见 `contracts/entry-ordering.md` §1）。语义：`entryDate == null` → 返回 `siblings.length`；否则返回最小的 `i` 使 `siblings[i] != null && siblings[i].compareTo(entryDate) > 0`；不存在则返回 `siblings.length`。**比较用字符串 `compareTo`，不解析 `DateTime`**；`null` 元素在扫描中**被跳过**，既不算更早也不算更晚；**不修改入参**
- [x] T020 [P] [US2] 在 `test/modules/period_book/entry_ordering_test.dart` 中补充用例（契约 §测试契约 #1-#4）：① **SC-002 端到端序列**——对空列表依次对 `null`、`'2026-10-09'`、`null`、`'2026-10-08'` 调用并在返回索引处插入，最终顺序索引为 `[0, 3, 1, 2]`；② 空 `siblings` 返回 `0`；③ 传入 `null` 恒返回 `siblings.length`；④ 落在第一个更晚者之前且跳过 `null` 元素。**先写测试、确认失败，再回填 T019**

### Service：落位路径

- [x] T021 [US2] 在 `lib/modules/period_book/services/period_book_service.dart` 中新增 4 个私有方法 `_rescheduleAddition` / `_rescheduleExpense` / `_rescheduleLargeAddition` / `_rescheduleLargeExpense`，签名均为 `Future<void> _rescheduleXxx(int id, String? entryDate)`。职责：① `entryDate == null` 时**立即返回**（这是 SC-001 的关键）② 写入 `entry_date` ③ 查出同组（`stage_id` 或 `period_id`）全部记录，按 `ORDER BY sort_order ASC, created_at ASC` 排序并**排除自身** ④ 调 `resolveInsertIndex` ⑤ 把自身插入该索引得到完整新顺序 ⑥ 在 `DatabaseService.instance.transaction` 中按新顺序写回 `sort_order: 0..n-1` ⑦ `_notifyChanged()`
- [x] T022 [US2] 在 `lib/modules/period_book/services/period_book_service.dart` 中，让 4 个 `addXxx` 在 insert 拿到 id 后调用对应的 `_rescheduleXxx`（**仅当 `record.entryDate != null`**）。新增与落位共用同一条路径（research R4），不得为新增另写一份插入索引计算
- [x] T023 [US2] 在 `lib/modules/period_book/services/period_book_service.dart` 中，为 4 个 `updateXxx`（`updateAddition` / `updateExpense` / `updateLargeAddition` / `updateLargeExpense`）增加 `String? entryDate` 与 `bool clearEntryDate = false` 参数（契约见 `contracts/period-book-service.md` §1）。语义：`entryDate != null` → 写入并按 `resolveInsertIndex` **重新落位**（FR-004）；`entryDate == null && clearEntryDate == true` → 置 `entry_date = NULL` 且**停在当前位置不动**；两者皆空 → 不动日期、不落位；`entryDate != null && clearEntryDate` → `assert` 拦截。**修正既有早退判断**，使其只在 4 个参数全未设时才 `return`，否则「只改日期」的调用会被静默吞掉

### 编辑弹窗接入

- [x] T024 [US2] 在 `lib/modules/period_book/pages/stage_edit_page.dart` 的 `_showEditExpenseSheet` 与 `_showEditAdditionSheet` 中增加日期行（选择 / 清除），保存时把日期或 `clearEntryDate` 传给 `updateExpense` / `updateAddition`
- [x] T025 [US2] 在 `lib/modules/period_book/pages/large_items_edit_page.dart` 的 `_showEditExpenseSheet` 与 `_showEditAdditionSheet` 中完成同样的接入

### 不变量自检

- [x] T026 [US2] 自检 FR-005 / FR-010：执行 `grep -n "entry_date\|entryDate" lib/modules/period_book/services/period_book_service.dart`，确认结果**只出现在** `addXxx` / `updateXxx` / `_rescheduleXxx` 三类方法体内；**不得**出现在任何金额聚合方法（小计 / 合计 / 余额 / 饼图构成）或任何 `ORDER BY` 语句中。发现即回改

### 判定性验收

- [ ] T027 [US2] 按 `quickstart.md` §3.0 手工复现 **SC-002**：在同一天内、于同一个表单依次录入 4 条（第 1 条不填时间 → 第 2 条填 10月9日 → 第 3 条不填 → 第 4 条填 10月8日），列表顺序**必须**为第 1 条 → 第 4 条 → 第 2 条 → 第 3 条。再按 `quickstart.md` §3.2 逐项验证 FR-003 / FR-004（含「清空时间停在原地」与「未来日期 / 跨范围日期不做拦截」）

**Checkpoint**: US1 + US2 共同构成最小可用闭环。填时间的条目正确落位，不填时间的追加到末尾

---

## Phase 5: User Story 3 - 手工拖动调整顺序 (Priority: P2)

**Goal**: 未填写时间的条目可拖到列表任意位置，无一例被拒绝；已填写时间的条目只能在同一天内调整先后；被拒绝的拖动给出明确反馈。

**Independent Test**: 在同一批未填时间的条目中任意拖动（含拖到两条有日期条目之间）→ 顺序立即改变并保持；把一条已填日期的条目拖向其日期范围之外 → 不生效且有提示。

### 排序算法（含测试先行）

- [x] T028 [US3] 在 `lib/modules/period_book/services/entry_ordering.dart` 中实现 3 个函数（契约见 `contracts/entry-ordering.md` §2/§3/§4）：`int normalizeReorderIndex(int oldIndex, int newIndex)`（`newIndex > oldIndex ? newIndex - 1 : newIndex`）；`bool canReorder(List<String?> orderedEntryDates, int oldIndex, int newIndex)`；`List<T> applyReorder<T>(List<T> list, int oldIndex, int newIndex)`（**返回新列表，不修改入参**）。`canReorder` 语义：被拖条目 `== null` → **恒 `true`**；否则构造 `preview` 后检查其前方无「更晚」、后方无「更早」；其他无日期条目在前后检查中**被跳过**。`applyReorder` 必须复用 `normalizeReorderIndex`，不得让调用方自己写移动逻辑
- [x] T029 [P] [US3] 在 `test/modules/period_book/entry_ordering_test.dart` 中补充用例（契约 §测试契约 #7-#12）：未填时间条目拖到任意位置（含两个有日期条目之间）恒 `true`（SC-005）；有日期条目拖到更晚条目之后 → `false`；拖到更早条目之前 → `false`；同日条目之间调整 → `true`；`normalizeReorderIndex` 向下拖减 1；`applyReorder` 向上拖与向下拖落点均正确且不改入参。**先写测试、确认失败，再回填 T028**

### 页面接入

- [x] T030 [US3] 在 `lib/modules/period_book/pages/stage_edit_page.dart` 的 `_onShoppingReorder` 与 `_onOtherReorder` 中，按 `contracts/entry-ordering.md` §「调用方契约」接入：① 用**卡片当前渲染的列表**（`_expenses.where((e) => !e.isOther)` / `.where((e) => e.isOther)`，**不是**全量 `_expenses`）构造 `dates` ② `canReorder` 返回 `false` 时弹 SnackBar「已填写时间的条目只能在同一天内调整顺序」并 **直接 return，不修改任何 state、不落库** ③ 通过则用 `applyReorder` 得到新顺序并写回 state + 调 `updateExpensesOrder`。**保持** `onReorder: filter != null ? null : _onShoppingReorder` 的既有筛选态禁用逻辑不动
- [x] T031 [US3] 在 `lib/modules/period_book/pages/large_items_edit_page.dart` 的购物支出 / 其他支出 / 大额追加三处 `onReorder` 中完成与 T030 相同的工作（构造 `dates` 时使用各自的子集列表）

**Checkpoint**: 拖拽按 FR-011 生效，SC-005 与 SC-006 满足

---

## Phase 6: User Story 4 - 历史数据无损兼容 (Priority: P2)

**Goal**: 升级前已存在的条目全部保持原有条数与顺序；旧备份可导入并按「未填写时间」处理；新备份可完整还原时间与顺序。

**Independent Test**: 用一份只含未填时间记录的旧数据库启动应用 → 记录条数不变、顺序与升级前一致。

> 迁移代码本身已由 T004 完成（它被所有 story 依赖，故置于 Foundational）。本阶段补齐**备份**路径与**验证**。

### 备份兼容

- [x] T032 [US4] 在 `lib/core/settings/import_export_service.dart` 的 4 条导入 `INSERT OR REPLACE` 语句中增加 `entry_date` 列与 `map['entry_date']` 参数（位置见 `contracts/period-book-service.md` §5）。**参数不得写任何兜底**（不写 `?? ''`、不写 `?? 0`）——键缺失时 Dart 求值为 `null`，写入 SQLite 即 `NULL`，正是「未填写时间」的语义。导出侧**无需改动**（走 `_db.query` 取全列）
- [x] T033 [US4] 修复 `lib/core/settings/import_export_service.dart:428` 处 `mod_period_book_large_additions` 导入 SQL **遗漏 `sort_order` 列**的既有缺陷：补上该列与 `map['sort_order'] ?? 0` 参数。这是本特征的前置依赖而非可选清理——US4 场景 3 要求「新备份导入后列表顺序完整还原」，而该路径当前根本不写顺序，不修则 FR-008 在实现当天即是坏的

### 验证

- [ ] T034 [US4] 按 `quickstart.md` §2.1 手工验证**升级路径**：在改动前的代码上录入若干支出与追加并记录条数与顺序 → 切到改动后的代码启动 → 确认条数逐条一致、顺序逐条一致、可正常新增、无启动异常。再按 §2.2 验证**全新安装路径**（删除 `toolbox.db` 后启动，新建周期 + 阶段，新增带日期的条目成功）——用于确认 `_onCreate` 与 `_onUpgrade` **两条路径都改到了**
- [ ] T035 [US4] 按 `quickstart.md` §4.1 / §4.2 手工验证**备份兼容**：旧备份（无 `entry_date`）导入成功且按未填写处理；新备份往返后时间与顺序完整还原。**必须在大额追加列表上验证**——这是 T033 缺陷的唯一暴露点，只在支出列表验证会掩盖它。另按 §4.3 确认缺字段的极简 JSON 不因结构校验被误拒

**Checkpoint**: 4 个 user story 全部独立可用

---

## Phase 7: Polish & Cross-Cutting Concerns

- [x] T036 [P] 运行 `flutter analyze`，确保**零新增告警** → 54 issues / 0 errors，与改动前完全一致
- [x] T037 [P] 运行 `dart format lib test` 完成格式化 → **缩范围执行**：仅格式化本次改动的 18 个文件（`dart format $(git status --porcelain ...)`）。理由：全树 `dart format` 会顺带重排约 50 个与特性无关的历史文件，把提交淹没在噪声里，无法评审。相对任务书原文的这处偏离已向用户声明
- [x] T038 运行 `flutter test test/modules/period_book`，确认 `test/modules/period_book/entry_ordering_test.dart` 全部用例通过，且既有 `test/modules/period_book/agg_page_filter_test.dart` / `category_filter_helper_test.dart` / `expense_category_test.dart` **无回归**（任何回归都说明改动越界，尤其可能触碰了聚合口径）→ 91/91 通过，7s
- [x] T039 判断是否需要全量 `flutter test`：若实现中改到了 `lib/core/` 的共享路径（`clearModuleData` / `factoryReset` / 通用 `query`、`transaction`）则**必须**全量；若仅有加列 + 加迁移则按需测试即可。将判断结论记入提交说明 → **结论：必须全量，且已执行**。实现确实改到了共享路径：`DatabaseService._onCreate` 的事务体（首启建表，影响**所有**模块）与 5 个 schema 构造函数签名。全量结果见 T041 提交说明
- [x] T040 按 `quickstart.md` §五 提交前检查清单逐项核对，重点确认 `grep` 自检项（`entry_date` 不出现在任何 `ORDER BY` 或聚合方法中）→ 11 处 `orderBy` 全为 `sort_order` / `start_date`，`entry_date` 仅出现在 insert/update 映射与兄弟行查询的列名中，FR-010 成立
- [x] T041 按 `.codex/skills/commit/SKILL.md` 提交（英文 type/scope 前缀 + 简体中文描述），提交信息中说明本次交付了哪些 story → 拆为 3 个提交，见下方「提交拆分」

### 提交拆分

实现过程中发现两个**与本特性无关的既有缺陷**，混进特性提交会让两者都难以评审，故分开提交：

| 提交 | 说明 |
| :--- | :--- |
| `77af886 fix(core)` | `_onCreate` / `_onUpgrade` 兜底分支在事务内混用 `db` 导致的数据库锁死 |
| `ba31cfe test(vault)` | 新增分类弹窗用例因真实 IO 卡在 FakeAsync 而挂死，并补上失效的选中断言 |
| `42c66ad feat(period_book)` | 本特性（US1–US4）+ spec 工作区 |

> ⚠️ `77af886` 的锁死修复**尚未经真机全新安装验证**（正是 T034 的手工步骤）。已确认的是：Windows/Linux 生产环境走 `databaseFactoryFfi`，与复现所用工厂同源；升级路径不触发 `_onCreate`，因此存量用户从未暴露该问题。

---

## Dependencies & Execution Order

### Phase Dependencies

```text
Phase 1: Setup (T001-T002)
    ↓
Phase 2: Foundational (T003-T011)  ← BLOCKS 所有 user story
    ↓
    ├── Phase 3: US1 (T012-T018)  ─┐
    │                              ├→ Phase 7: Polish (T036-T041)
    ├── Phase 4: US2 (T019-T027)  ─┤
    ├── Phase 5: US3 (T028-T031)  ─┤
    └── Phase 6: US4 (T032-T035)  ─┘
```

### User Story Dependencies

| Story | 依赖 | 说明 |
| :--- | :--- | :--- |
| **US1** (P1) | Foundational | 无 story 间依赖，是其余三个 story 的数据入口 |
| **US2** (P1) | Foundational + **US1** | 落位需要「能录入日期」这一前提，且需 T016 已让 `addXxx` 落库 `entry_date` |
| **US3** (P2) | Foundational + **US1** | 拖拽校验需要 `entryDate` 已被渲染并可达（T013/T014 的 DTO 字段）；与 US2 无依赖，可并行 |
| **US4** (P2) | Foundational | 迁移在 Foundational 已完成；备份路径与验证独立于 US1-US3 |

> **US2 与 US3 可并行**：二者改动 `entry_ordering.dart` 的不同函数区段（US2 写 `resolveInsertIndex`，US3 写 `canReorder` / `normalizeReorderIndex` / `applyReorder`），改动页面的不同代码位置（US2 动 `_showEditExpenseSheet` / `updateXxx`，US3 动 `onReorder`）。若单人开发则按 P1 → P2 顺序串行。

### Within Each User Story

- 测试先写并确认**失败**，再实现（T011 → T010、T020 → T019、T029 → T028）
- 纯函数实现先于 service 接线，service 先于页面接线
- 每个 story 完成并通过 checkpoint 后再进入下一个

---

## Parallel Execution Examples

### Foundational 阶段并行

```bash
# 4 个模型的改动互不冲突，可同时进行：
Task: "T006 为 ExpenseRecord 增加 entryDate"
Task: "T007 为 AdditionRecord 增加 entryDate"
Task: "T008 为 LargeExpenseRecord 增加 entryDate"
Task: "T009 为 LargeAdditionRecord 增加 entryDate"
```

> T003/T004/T005 均改 `database_service.dart`，**不可并行**，且 T004 依赖 T003 的列名一致。

### US1 阶段并行

```bash
# 4 个 UI 组件文件互不冲突：
Task: "T012 AddForm 增加可选日期字段"
Task: "T013 ExpenseItemData 增加 entryDate 与行内展示"
Task: "T014 AdditionItemData 增加 entryDate 与行内展示"
Task: "T015 ExpenseCategoryHelper.buildExpenseItem 增加可选 entryDate 参数"
```

> T017 与 T018 改不同页面文件，**可并行**。

### US2 / US3 并行（双人）

```bash
# 一人做 US2（落位），一人做 US3（拖拽）：
Task: "T019 resolveInsertIndex + T021/T022/T023 service 落位路径"
Task: "T028 normalizeReorderIndex / canReorder / applyReorder"
```

> 二者都改 `entry_ordering.dart` 与 `period_book_service.dart`，需在合并时注意不冲突；单人开发则串行。

---

## Implementation Strategy

### MVP First（US1 + US2）

1. 完成 Phase 1: Setup（T001-T002）
2. 完成 Phase 2: Foundational（T003-T011）—— CRITICAL，阻塞全部 story
3. 完成 Phase 3: US1（T012-T018）
4. 完成 Phase 4: US2（T019-T027）
5. **STOP and VALIDATE**：跑 T027 的 SC-002，必须得到 `0-3-1-2`
6. 此处已是可交付的最小闭环——用户能填时间、条目落到正确位置
7. 按需继续 US3 / US4

> **为什么 MVP 是 US1+US2 而不是只 US1**：spec 明确指出二者「共同构成最小可用闭环，缺一不可」。只交付 US1 时用户填的日期不会产生任何可见效果（仍追加到末尾），不构成可感知的价值。

### Incremental Delivery

1. Setup + Foundational → 数据层就绪（此时应用可正常启动，历史数据不受影响）
2. + US1 → 能录入日期并能看到 → 可演示
3. + US2 → 日期产生实际排序效果 → **MVP 交付**
4. + US3 → 拖拽规则生效 → 交付
5. + US4 → 备份往返可用 → 交付

### 风险提示（优先级最高的三项）

| 风险 | 相关任务 | 说明 |
| :--- | :--- | :--- |
| **迁移出错 → 永久数据丢失** | T003 / T004 / T005 / T034 | 本地数据无服务端兜底。T003 与 T004 必须**同时**完成（漏掉任一条，对应安装路径即报 `no such column`）。验证前先复制 `toolbox.db` 留档 |
| **`ORDER BY` 混入 `entry_date` → 历史顺序被打乱** | T026 / T040 | 违反 FR-005，且症状隐蔽（新数据看着正常，老数据顺序变了） |
| **导入写空串 → 旧数据全跑到列表最前** | T032 | 必须写 `null` 而非 `''`。症状是导入后顺序整体反转 |

---

## Notes

- [P] 任务 = 不同文件、无未完成依赖
- `[Story]` 标签映射到 `spec.md` 的 user story，用于追溯
- 每完成一个 task 或一组逻辑相关的 task 即提交（宪法：每完成一个小需求 MUST 立即 commit）
- 纯样式调整不得单独 commit，须随关联需求一并提交
- 任一 checkpoint 均可停下独立验证
- **避免**：把 `entry_date` 当作排序键、为 4 个模型写 4 份重复的排序逻辑、在筛选态下启用拖拽
