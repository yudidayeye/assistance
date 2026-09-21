---

description: "Task list for 历史记录报表饼图点击联动周期卡片筛选"
---

# Tasks: 历史记录报表饼图点击联动周期卡片筛选

**Input**: Design documents from `/specs/001-report-pie-filter/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/ui-contract.md](./contracts/ui-contract.md), [quickstart.md](./quickstart.md)

**Tests**: 本清单**包含测试任务**。依据不是 TDD，而是项目宪法原则 IV 的硬性要求——「新增模块逻辑 MUST 补充 unit 或 widget 测试，文件命名为 `*_test.dart` 并置于 `test/modules/<module_id>/` 下」。本特性新增了一个纯函数聚合层，属于必须补测的范围。

**Organization**: 任务按用户故事分组。Phase 2 是三个故事共同的阻塞前置；Phase 2 完成后 US1 / US2 / US3 可并行推进、各自独立验证（对应 SC-005）。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 可并行（不同文件、不依赖未完成任务）
- **[Story]**: 所属用户故事（US1 / US2 / US3）
- 所有描述均含确切文件路径

## Path Conventions

Flutter 单工程，模块内三层结构，与 `lib/` 同构的测试目录：

- 实现：`lib/modules/period_book/pages/`、`lib/modules/period_book/widgets/`
- 测试：`test/modules/period_book/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: 改动前的准备与基线确认

- [X] T001 通读 `docs/UI.md`，盘点本特性所需的 `appTheme` token（选中高亮色、标签底色、间距、圆角），产出一份「用哪个 token」的清单。宪法原则 V 要求任何视觉改动前必读此文件
- [X] T002 建立改动前基线：在仓库根目录运行 `flutter analyze` 与 `flutter test test/modules/period_book/`，记录两者当前的通过状态与告警数，作为后续比对的基准

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 三个用户故事共同的阻塞前置——纯函数聚合层、筛选状态、受控化的报表卡片、吸顶筛选标签

**⚠️ CRITICAL**: 本阶段完成前，任何用户故事都无法开始

### 饼图分类口径（FR-001a / FR-001b）

> 本组任务改的是**饼图自身的取数**，不是卡片筛选。它决定用户能点到哪些分类，因此 MUST 先于聚合层完成——聚合层的分类归属 MUST 与饼图采用同一套判定顺序，否则又会回到「点得着 A、列出 B」的老问题。
>
> （编号 `T002a`–`T002c` 为**插入任务**，沿用字母后缀以免重排既有 34 条任务的 ID 与其中大量的交叉引用。）

- [X] T002a 在 `lib/modules/period_book/pages/agg.dart` 的 `_calculateStats` 中修正**日常饼图**的分类归属：把 `:180` 的 `expenses.where((expense) => !expense.isOther)` 拆成两支——其他消费累加进「其他」桶，非其他消费维持走 `_normalizeCategory`。改后 `_expenseTypeData` 在范围内存在其他消费时 MUST 含「其他」键。键名 MUST 取 `mapCategoryForDisplay('other')` 的返回值，MUST NOT 硬编码字面量。补上该桶后，饼图各扇区金额之和 MUST 覆盖该周期的全部支出类型（FR-001a）。归类 MUST 复用 T004 抽出的共享判定方法，MUST NOT 内联
- [X] T002b 在 `lib/modules/period_book/pages/agg.dart` 的 `_calculateStats` 中修正**合计饼图与大额饼图**的分类归属：合计侧的分类累加（`:352-356` 日常部分、`:365-368` 大额部分）与大额侧（`:303-307`）MUST 先判 `isOther`、命中的归入「其他」，未命中的再走 `_normalizeCategory`。`other:购物` MUST 归入「其他」、MUST NOT 混入「购物」（FR-001b，research R5）。归类 MUST 复用 T004 抽出的共享判定方法，MUST NOT 内联
- [X] T002c 在 `lib/modules/period_book/pages/agg.dart` 的 `_calculateStats` 中修正**阶段维度数据** `_stageExpenseTypeData`（`:274-278`）：先按 `e.stageId == targetStageId` 收敛，再判 `isOther` 归类，两个判定的先后顺序 MUST NOT 颠倒。该数据是日常饼图在选中阶段时的取数口径，FR-001b 对三个视图同等适用（FR-001b）。归类 MUST 复用 T004 抽出的共享判定方法，MUST NOT 内联

### 聚合层（纯函数，无 IO）

- [X] T003 [P] 新建 `lib/modules/period_book/widgets/category_filter_helper.dart`，定义两个视图模型：`FilterItem { description, amount }` 与 `PeriodCategorySummary { periodId, categoryName, dailySubtotal, largeSubtotal, dailyItems, largeItems, isResidualOnly, totalCount }`。约束：`totalCount` MUST 等于两侧明细条数之和；`FilterItem` MUST NOT 携带分类名或子类名字段（FR-023）；`description` 为空或仅含空白时 MUST 以该记录所属分类的**显示名**占位，MUST NOT 渲染空文本（Edge Case 无描述的支出记录）
- [X] T004 在 `lib/modules/period_book/widgets/category_filter_helper.dart` 实现 `buildSummaries` 的分类归属：对每条记录**先**用 `ExpenseRecord.isOther` / `LargeExpenseRecord.isOther` 判类，**再**对非其他记录调用 `mapCategoryForDisplay`。`other:购物` MUST 归入「其他」、MUST NOT 归入「购物」（契约 C2-2，依据 research R5；顺序颠倒即筛错）。该判定 MUST 抽成 `CategoryFilterHelper` 上的一个共享静态方法（入参为 `bool isOther` 与原始 `category`，返回显示名），T002a / T002b / T002c 涉及的四处饼图取数 MUST 调用同一个方法，MUST NOT 各自内联一份 `isOther` 分支——该判定正是本特性要修的既有 bug 的病根（`mapCategoryForDisplay` 会剥掉 `other:` 前缀），多处实现必然漂移
- [X] T005 在 `lib/modules/period_book/widgets/category_filter_helper.dart` 实现两个特殊分支：①`categoryName == '杂项'` 时 `isResidualOnly = true`、明细恒空、小计为各阶段正残值之和（FR-022，契约 C2-3）；②结余（`balance`）MUST NOT 进入任何分类的统计（FR-019）
- [X] T006 在 `lib/modules/period_book/widgets/category_filter_helper.dart` 实现阶段收敛：`selectedStage != null` 且 `includeDaily` 时，日常侧 MUST 只统计 `stageId == stages[selectedStage - 1].id` 的记录；大额侧 MUST NOT 按阶段收敛（FR-016a，契约 C2-6）
- [X] T007 在 `lib/modules/period_book/widgets/category_filter_helper.dart` 实现排序与裁剪辅助：组内沿用 `getExpensesByPeriod` 的既有顺序（`sort_order ASC, created_at ASC`）；合计场景 MUST 先 `dailyItems` 后 `largeItems`、跨组不混排（契约 C2-5/C2-7）；导出 `visibleItems(summary, {expanded})` —— `expanded == false` 返回前 3 条（FR-011，契约 C2-9）
- [X] T008 [P] 新增 `test/modules/period_book/category_filter_helper_test.dart`，逐条覆盖契约 C2-1..C2-9：无该分类支出的周期仍产出对象、`other:购物` 归入「其他」、杂项只出小计、阶段收敛开/关两种情形、合计前 3 条取序、零金额周期小计为零

### 状态与报表卡片

- [X] T009 在 `lib/modules/period_book/pages/agg.dart` 的 `_AggPageState` 引入两个页面临时状态：`String? _selectedCategory` 与 `Set<int> _expandedPeriodIds`，并实现其收敛入口（选中、取消、切换分类时清空展开集合）。二者 MUST NOT 写入 `toolbox.db` 或 `app_settings`（FR-014，契约 C5-1/C5-3）。此外 MUST 实现「范围变更后的自动取消」：`_calculateStats` 重算完成后，若 `_selectedCategory != null` 且该分类在全部 `_filteredPeriods` 上的**小计之和为 0**，则置空筛选并清空展开集合（FR-016）。判定口径是聚合层产出的小计，因此「杂项」这类只有残值、没有记录的分类在改范围后 **不会** 被自动取消——其小计大于零
- [X] T010 改造 `lib/modules/period_book/widgets/report_card.dart` 为受控组件：新增 `selectedCategory` 与 `onCategorySelected`，删除以 `_touchedIndex` 作为真值的做法，改为由 `widget.selectedCategory` 反查选中项。既有 `touchCallback` 的三条分支（点中扇区 / 再点取消 / 点空白取消）MUST 保留其行为、只把内部 `setState` 换成回调（契约 C1-4/C1-5/C1-6/C1-7）
- [X] T011 [P] 在 `lib/modules/period_book/widgets/report_card.dart` 的 `_buildLegend` 增加 `isSelected` 与 `onTap`，使图例行可点、可与扇区派发同一回调，并渲染选中态。其余图例行 MUST 保持未选中外观、MUST NOT 淡化（FR-001/FR-006，契约 C1-2/C1-3）。选中态的视觉表达 MUST 与扇区高亮**不同形**（建议行底色或左侧色条，二选一），色值一律取 `Theme.of(context).appTheme` 的 token，MUST NOT 硬编码（宪法 V，research R3）；图例行的可点区域不小于 44×44 逻辑像素，以保证占比极小的分类仍有尺寸充足的入口（SC-008）
- [X] T012 [P] 在 `lib/modules/period_book/widgets/report_card.dart` 的 `_buildPieSection` 增加 `isSelected` 与选中视觉（如半径外扩 / 徽标强化），使当前分类在图上可辨。MUST NOT 淡化其余扇区（FR-006，依据 research R4）
- [X] T013 在 `lib/modules/period_book/pages/agg.dart` 的三个 `CustomScrollView`（日常 / 大额 / 合计）中，于图表 `SliverToBoxAdapter` 与卡片 `SliverList` 之间插入 `SliverPersistentHeader(pinned: true)` 承载吸顶筛选标签。标签 MUST 显示分类名、MUST 提供关闭控件、未筛选时 MUST NOT 渲染；底色 MUST 不透明（FR-006a/FR-020/FR-021，契约 C3-1..C3-5）
- [X] T014 在 `lib/modules/period_book/pages/agg.dart` 既有的 `_tabController` 监听（`initState` 内）中清空 `_selectedCategory` 与 `_expandedPeriodIds`。挂在监听上而非分段按钮的回调上，使**左右滑动**与点击两种切换方式都被覆盖（FR-018，契约 C5-2，依据 research R9）
- [X] T015 [P] 新增 `test/modules/period_book/agg_page_filter_test.dart`，覆盖共享组件行为：标签在筛选态渲染且未筛选时不渲染、关闭控件派发取消、切换视图后筛选被清空、报表从占比切到趋势时筛选保留且标签仍在（FR-015/FR-017/FR-018/FR-021，契约 C3/C5）

**Checkpoint**: 聚合层与共享交互就绪，三个用户故事可并行推进

---

## Phase 3: User Story 1 - 日常视图：按分类下钻各周期的支出 (Priority: P1) 🎯 MVP

**Goal**: 日常视图点击饼图分类后，下方每张周期卡片给出该分类的小计与逐条明细，可原地展开，再次点击取消

**Independent Test**: 停留在日常视图，点击任意分类扇区或图例行，确认下方每张卡片改为显示该分类小计与明细；再次点击恢复原样。全程不依赖另外两个视图

### Implementation for User Story 1

- [X] T016 [US1] 在 `lib/modules/period_book/pages/agg.dart` 扩展 `_buildPeriodCard`：筛选生效时在既有汇总行下方追加「分类小计 + 至多 3 条明细」。明细行 MUST 复用既有的顶层函数 `_buildDetailRow`（只渲染描述与金额，无分类标签），MUST NOT 改用 `ExpenseCategoryHelper.buildExpenseItem`（FR-007/FR-023，契约 C4-1/C4-3，依据 research R7）
- [X] T017 [US1] 在 `lib/modules/period_book/pages/agg.dart` 为日常卡片实现「查看全部 N 条 / 收起」控件：`totalCount > 3` 时显示，点击后在该卡片内原地展开、MUST NOT 跳页或弹窗，展开状态以 `_expandedPeriodIds` 按周期记录、允许多张同时展开；点击控件 MUST NOT 冒泡触发卡片主体的跳转（FR-011/FR-012，契约 C4-4/C4-5/C4-6）
- [X] T018 [US1] 在 `lib/modules/period_book/pages/agg.dart` 实现日常卡片的两个空态分支：①该周期在所选分类下小计为零时保留卡片、显示零、MUST NOT 渲染空明细区（FR-010，契约 C4-9）；②所选分类为「杂项」时只渲染小计与一行「来自未逐条记录的部分」说明，MUST NOT 渲染明细区或「查看全部」控件（FR-022，契约 C4-7）
- [X] T019 [US1] 扩展 `test/modules/period_book/agg_page_filter_test.dart`，覆盖 US1：扇区与图例两个入口等价、再次点击取消、点空白取消、超过 3 条与不超过 3 条两种展示、零小计周期保留、汇总行数值在筛选前后不变
- [X] T020 [US1] 按 [quickstart.md](./quickstart.md) 的 S1–S6 在 Windows 上手工验证日常视图（含「其他」归类与图例入口两项），记录实际结果与偏差

**Checkpoint**: 日常视图可独立交付并独立验证——这就是本特性的 MVP

---

## Phase 4: User Story 2 - 大额视图：按分类下钻大额支出 (Priority: P2)

**Goal**: 大额视图点击分类后，卡片既有的三组明细被该分类的小计与明细整体替换

**Independent Test**: 切换到大额视图，点击任意分类，确认三组明细全部被替换为该分类内容；再次点击恢复三组

### Implementation for User Story 2

- [X] T021 [US2] 在 `lib/modules/period_book/pages/agg.dart` 扩展 `_buildLargePeriodCard`：筛选生效时，未筛选可见的「大额追加」「个人支出」「其他支出」三组 MUST 全部被替换为该分类的小计与明细，MUST NOT 与筛选结果叠加显示（FR-008，契约 C4-8）
- [X] T022 [US2] 在 `lib/modules/period_book/pages/agg.dart` 校验大额卡片第一行净额在筛选态下的口径：MUST 保持「大额追加合计 − 大额支出合计」原样，MUST NOT 改为「仅所选分类的支出金额」（FR-013，契约 C4-1）
- [X] T023 [US2] 在 `lib/modules/period_book/pages/agg.dart` 为大额卡片接入 T017 的展开机制与 T018 的零小计分支，使其行为与日常视图一致（FR-010/FR-011）
- [X] T024 [US2] 扩展 `test/modules/period_book/agg_page_filter_test.dart`，覆盖 US2：三组被替换、无该分类支出的周期保留并显示零、再次点击恢复三组、净额数字不随筛选变化
- [X] T025 [US2] 按 [quickstart.md](./quickstart.md) 的 S13 手工验证大额视图，并确认该视图不出现「杂项」扇区

**Checkpoint**: US1 与 US2 各自独立可用

---

## Phase 5: User Story 3 - 合计视图：同时下钻日常与大额两部分 (Priority: P3)

**Goal**: 合计视图点击分类后，卡片把该分类记录分成日常与大额两组，各自给出小计与明细

**Independent Test**: 切换到合计视图，点击同时存在于两边的分类，确认卡片分别给出日常组与大额组的小计与明细；仅存在于单边的分类也能正常筛选

### Implementation for User Story 3

- [X] T026 [US3] 在 `lib/modules/period_book/pages/agg.dart` 扩展 `_buildSummaryPeriodCard`：在既有「日常消费 / 大额记录」汇总行下方，把所选分类的记录分为日常与大额两组，各自给出小计与明细（FR-009，契约 C4-1）
- [X] T027 [US3] 在 `lib/modules/period_book/pages/agg.dart` 落实合计视图的取序与计数：前 3 条 MUST 先取日常组、再取大额组、跨组不混排；「查看全部 N 条」的 N MUST 为两组条目之和（FR-011，契约 C4-4）
- [X] T028 [US3] 在 `lib/modules/period_book/pages/agg.dart` 处理合计视图的两处边界：①所选分类为「杂项」时小计落在日常侧、大额侧显示为零（FR-022）；②某分类只存在于单边时，另一侧小计显示为零且无条目（US3 场景 2）
- [X] T029 [US3] 扩展 `test/modules/period_book/agg_page_filter_test.dart`，覆盖 US3：日常 2 条 + 大额 3 条时显示 3 条并提示「查看全部 5 条」、展开后 5 条全可见、仅单边存在的分类、杂项落日常侧
- [X] T030 [US3] 按 [quickstart.md](./quickstart.md) 的 S14 手工验证合计视图

**Checkpoint**: 三个视图全部独立可用

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: 跨视图的边界验证与交付前收尾

- [X] T031 按 [quickstart.md](./quickstart.md) 的 S7–S12 与 S15 验证跨视图与边界场景：「其他」归类、阶段口径、报表视图切换（**含「支出趋势」下筛选仍可通过标签取消的死状态检查**）、视图切换清空、筛选不持久化
- [X] T032 在仓库根目录运行 `flutter analyze` 与 `dart format lib test`，确认无新增告警、无格式改动残留（宪法原则 IV）
- [X] T033 运行 `flutter test test/modules/period_book/`（本特性改动了该模块的多个文件，按宪法原则 IV 跑模块级测试）
- [X] T034 起草发布说明草稿，**必须**包含本次引入的三处既有图表行为变更：①日常饼图由"部分支出类型"改为覆盖全部支出类型、各扇区占比整体变化；②其他消费不再按子类并入同名普通分类、整体归入「其他」；③报表标题旁总金额随「其他」扇区补入而变大（并从此与日常卡片第一行的周期支出对齐）。**MUST NOT** 自行执行 `scripts/release.ps1`，版本发布由用户单独发起

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: 无依赖，立即开始
- **Phase 2 (Foundational)**: 依赖 Phase 1；**阻塞全部用户故事**
- **Phase 3 (US1)**: 依赖 Phase 2 完成
- **Phase 4 (US2)**: 依赖 Phase 2 完成；**不依赖 US1**（卡片实现各自独立，用到的展开机制在 US1 中建成后即可复用）
- **Phase 5 (US3)**: 依赖 Phase 2 完成；与 US1/US2 相互独立
- **Phase 6 (Polish)**: 依赖所选用户故事完成

### 关键依赖链

```text
Phase 1 → Phase 2 → ┬→ US1 (T016→T017→T018→T019→T020)
                    ├→ US2 (T021→T022, T023 复用 T017/T018 → T024→T025)
                    └→ US3 (T026→T027→T028→T029→T030)
                                ↓
                            Phase 6 (T031 → T032 → T033 → T034)
```

- `T002a` / `T002b` / `T002c` 定下**可筛选分类的集合**，是 `T003`–`T008` 聚合层的前提：饼图扇区与卡片分类 MUST 同源
- `T004` 的归类顺序是 `T005`/`T006` 的前提：先定归属，再谈特殊分支
- `T010` 的受控化是 `T011`/`T012` 的前提：先有回调与状态，再谈两种选中态
- `T017` 的展开机制被 `T023`（大额）与 `T027`（合计）复用，故 US1 抢先实现可降低后续成本

### 并行机会

- **Phase 1**：`T001` 与 `T002` 可并行
- **Phase 2 内**：`T003`（模型）可与 `T001`/`T002` 并行；`T011`/`T012` 改的是 `report_card.dart` 的不同方法，可并行；`T008` 与 `T015` 分属两个测试文件，可并行
- **`T002a` / `T002b` / `T002c` MUST NOT 并行**：三者同处 `_calculateStats` 一个方法内，并发编辑会互相覆盖；建议串行，或由同一人一次改完再对 `:180` / `:274-278` / `:300-311` / `:352-368` 四处逐段自检
- **US1 / US2 / US3 之间**：Phase 2 完成后三条故事线可并行，各自改不同的卡片构建方法、各写各的测试用例

---

## Implementation Strategy

### MVP First（仅 US1）

1. Phase 1 → Phase 2 → Phase 3
2. 停在 Phase 3 即可交付：日常视图是默认与最高频视图，本特性已可独立产生价值
3. 交付前完成 T020 的独立验证

### Incremental Delivery

1. Phase 1 + Phase 2 打通共享能力
2. 加 US1 → 手工验证 → 可交付（MVP）
3. 加 US2 → 手工验证 → 可交付
4. 加 US3 → 手工验证 → 可交付
5. Phase 6 统一收口：跨视图边界 + analyze/format/test + 发布说明草稿

### 说明

- 本特性**不涉及数据库变更**，因此没有 schema 或迁移任务
- 本特性**不新增依赖**，因此没有依赖安装任务
- 三处既有图表行为变更 MUST 走发布说明声明，但**发布动作本身由用户单独发起**

---

## Notes

- 全程 MUST NOT 硬编码色值或间距，一律取 `Theme.of(context).appTheme` 的 token（宪法原则 V）
- 筛选与展开状态 MUST NOT 落盘（FR-014 / FR-015 / SC-006）
- 两处**尚未写进 spec 的待办**（来自 `checklists/state-coverage.md` 的探针项，用户尚未拍板是否补入）：
  1. `CHK029` —— 左右**滑动**切换视图是否也要求清空筛选。本清单按"是"处理（T014 把清空挂在 `_tabController` 监听上，两种切换方式都被覆盖）
  2. `CHK025` —— 「视图」一词在 FR-018 中指代日常/大额/合计，与「报表视图」（占比/趋势）存在术语撞车。**已于 2026-09-20 修正**：FR-018 现写作「记账视图（日常 / 大额 / 合计）」并显式排除「报表视图」

---

## Phase 7: Convergence

- [X] T035 **CRITICAL** 对本次特性触及的 Dart 文件执行 `dart format` 并提交其结果：`lib/modules/period_book/widgets/report_card.dart`（新增的选中边框 / 图例高亮 / tooltip 圆点代码）、`test/modules/period_book/agg_page_filter_test.dart`、`test/modules/period_book/category_filter_helper_test.dart` 三者在 `dart format --output=none --set-exit-if-changed` 下仍报 CHANGED，不满足「无格式改动残留」。`agg.dart` 与 `category_filter_helper.dart` 已符合，无需再动。注意 SDK 3.13.2 的 tall style 会连带重排这些文件中的既有代码（`report_card.dart` 约 13 处），须与 `agg.dart` 已采纳的处理保持一致并在提交说明中披露；MUST NOT 扩大到与本特性无关的仓库文件（T032 的全量口径另论） per Constitution 技术约束（代码格式化 MUST 使用 `dart format`）与 T032 (partial)
- [X] T036 在调整范围条件（`agg.dart` 的 `_onYearChanged` / `_onMonthChanged` / `_onStageChanged`，现仅调用 `_calculateStats()`）与切换报表视图（`report_card.dart` 内 `_currentView = viewType` 未通知 `AggPage`）时，一并清空 `_expandedPeriodIds`，使所有卡片的展开状态随筛选结果重算整体收起。当前仅「所选分类在新范围下无金额」这一条路径会顺带收起（`_applyAutoCancelFilter`），其余路径会让上一周期的展开/收起状态残留在新内容上 per 契约 C5-3 / spec Assumptions「展开状态在筛选结果重算时重置」(partial)
