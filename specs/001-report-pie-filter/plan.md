# Implementation Plan: 历史记录报表饼图点击联动周期卡片筛选

**Branch**: `001-report-pie-filter` | **Date**: 2026-09-20 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-report-pie-filter/spec.md`

## Summary

在「历史记录」页（`AggPage`）的报表饼图上增加分类筛选：点击扇区或图例行后，下方三个视图（日常 / 大额 / 合计）的周期卡片在下钻到该分类、给出小计与逐条明细，再次点击取消。筛选是纯展示层的页面临时状态，不落盘、不改账目数据。

技术路径：把 `ReportCard` 内部的「选中扇区」私有状态（现为 tooltip 用的 `_touchedIndex`）提升为页面级的「选中分类名」，由 `AggPage` 持有并下发给卡片；卡片端新增一个纯函数聚合层，按周期算出该分类的小计与明细（日常侧来自 `_expenseMap`、大额侧来自 `_largeExpensesMap`，均为内存数据），再以「汇总行 + 分类小计 + 至多 3 条明细 + 查看全部」三段式渲染。取消入口除再次点击外，另加一条吸顶筛选标签常驻。

## Technical Context

**Language/Version**: Dart 3.x（`sdk: '>=3.0.0 <4.0.0'`），Flutter stable

**Primary Dependencies**: `fl_chart ^0.69.0`（`PieChart` / `PieTouchData` / `FlTapDownEvent`，已在使用）；`go_router`（卡片跳转，不变）。**本次不新增任何依赖**

**Storage**: 无 schema 变更。筛选状态只驻留内存，不写 `toolbox.db`、不写 `app_settings`（FR-014 / FR-015 / SC-006）

**Testing**: `flutter_test`；靶向 `test/modules/period_book/`。纯函数聚合层用 unit test，交互用 widget test

**Target Platform**: Android 与 Windows（两平台行为一致）

**Project Type**: Flutter 单工程桌面/移动应用，改动限于 `lib/modules/period_book/`

**Performance Goals**: 点击到卡片重绘在同一帧完成。筛选重算 MUST NOT 新增数据库往返——`_loadData` 已把 `_expenseMap` / `_largeExpensesMap` / `_calcMap` / `_stagesMap` 全部载入内存，重算只遍历这些既有 Map

**Constraints**: 颜色/圆角/间距一律取 `Theme.of(context).appTheme` 的 token，禁止硬编码色值；不引入第三方字体；不得放宽 lint

**Scale/Scope**: 1 个页面（3 个子视图）× 3 类卡片；改动面约 `agg.dart`（1400 行）+ `report_card.dart`（985 行），新增 1 个纯函数 helper 与 1 个吸顶标签 delegate

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 原则 | 判定 | 依据 |
| :--- | :--- | :--- |
| I. 本地优先与隐私不可妥协 (NON-NEGOTIABLE) | PASS | 无云端同步、无账号体系、无遥测；筛选状态不落盘、不写设置。数据读取沿用既有本地 SQLite 查询 |
| II. 模块化插件架构 | PASS | 改动全部落在 `lib/modules/period_book/` 内；不新增模块、不改 `ModuleRegistry`、不动 `AppRouter` 的顶层路由生成 |
| III. 数据完整性与迁移安全 | PASS | 无 schema 变更，`DatabaseService._currentVersion` 不动；新增能力不写库，不存在迁移风险 |
| IV. 按需且贴近改动的测试 | PASS | 靶向 `test/modules/period_book/`；新增测试置于 `test/modules/period_book/`，与 `lib/` 同构；提交前跑 `flutter analyze` |
| V. 视觉一致性遵循 UI 规范 | PASS（含前置动作） | 高亮色、标签底色、间距均取 `appTheme` token。**实施第一步 MUST 先读 `docs/UI.md`** |

**结论**：无违反项，Complexity Tracking 留空。本次不新增文件类型、不引入新依赖、不改数据库，属于典型的前端交互增强。

### 设计后复核（Phase 1 完成）

Phase 1 产出的三个视图模型、纯函数聚合层与吸顶标签契约均未改变上述判定，逐条复核如下：

| 原则 | 设计后判定 | 复核依据 |
| :--- | :--- | :--- |
| I. 本地优先与隐私 | 仍 PASS | `data-model.md` §1 明确「不写 `toolbox.db`、不写 `app_settings`、不进 `SettingsController`」；§5 列明不存在任何持久化 |
| II. 模块化插件架构 | 仍 PASS | 新增的两个文件都在 `lib/modules/period_book/widgets/` 内；契约 C1–C5 不涉及模块注册或路由 |
| III. 数据完整性与迁移安全 | 仍 PASS | 契约 C2-8 明确要求聚合层「MUST NOT 发起任何数据库查询」，设计上排除了读写副作用 |
| IV. 按需且贴近改动的测试 | 仍 PASS | `quickstart.md` §2 给出三个靶向测试命令；`category_filter_helper.dart` 被设计为无 IO 纯函数，正是为 unit test 而拆分 |
| V. 视觉一致性 | 仍 PASS | 契约 C1-2 / C3-5 与 `quickstart.md` §1 均要求取 `appTheme` token 并在实施前先读 `docs/UI.md` |

**无新增违反项，门禁通过，可进入 `/speckit-tasks`。**

## Project Structure

### Documentation (this feature)

```text
specs/001-report-pie-filter/
├── plan.md              # 本文件
├── spec.md              # 需求规格（累计 21 项澄清）
├── research.md          # Phase 0 输出
├── data-model.md        # Phase 1 输出
├── quickstart.md        # Phase 1 输出
├── contracts/
│   └── ui-contract.md   # Phase 1 输出（UI 契约：props / 回调 / 纯函数签名）
├── checklists/
│   ├── requirements.md  # 规格质量清单（16/16）
│   └── state-coverage.md # 状态覆盖清单（45 项，reviewer-owned）
└── tasks.md             # Phase 2 输出（/speckit-tasks 生成）
```

### Source Code (repository root)

```text
lib/modules/period_book/
├── pages/
│   └── agg.dart                                  # 【改】筛选状态、吸顶标签、三类卡片的下钻渲染
├── widgets/
│   ├── report_card.dart                          # 【改】筛选状态外提、扇区/图例可点、选中态高亮
│   ├── expense_category_helper.dart              # 【不动】分类映射（注意 mapCategoryForDisplay 的剥前缀行为）
│   └── category_filter_helper.dart               # 【新】纯函数聚合层：按周期算小计/明细/前 3 条
└── services/
    └── period_book_service.dart                  # 【不动】无新查询

test/modules/period_book/
├── category_filter_helper_test.dart              # 【新】纯函数单测（主战场）
└── agg_page_filter_test.dart                     # 【新】吸顶标签与卡片下钻的 widget 测试
```

**Structure Decision**: 沿用仓库既有的「模块内 `pages/` + `widgets/` + `services/`」三层，与 `expense_category_helper.dart` 把纯静态工具类放在 `widgets/` 的既有约定一致。本次**不新增页面、不新增路由、不改数据库**，因此不需要任何模块注册或迁移工作。吸顶标签的 `SliverPersistentHeaderDelegate` 就地定义在 `agg.dart` 内（仅此一处使用，单开文件反而增加跳转成本），纯函数聚合层独立成文件，以便在 unit test 里直接覆盖排序、阶段口径与「杂项」分支。

## Phase 0 研究结论（详见 research.md）

1. **筛选状态必须外提到 `AggPage`** —— `ReportCard` 的 `_touchedIndex` 是「扇区数组下标」，而该数组按金额降序排列（`report_card.dart:680`）。范围条件一变，排序即变，下标会指向另一个分类。筛选键必须改为**分类显示名**。
2. **入口与出口的落点已经存在** —— `report_card.dart:715-739` 已实现「点扇区选中 / 再点取消 / 点空白取消」，与 FR-003 / FR-005 完全吻合，改造而非重写；`_touchedIndex == null` 的既有语义即「未筛选」。
3. **图例当前完全不可点** —— `_buildLegend`（`:946`）只是一行 `Row`，无手势、无选中态，FR-001 与 FR-006 需要新增。
4. **扇区目前没有选中视觉** —— `_buildPieSection`（`:858`）只渲染徽标，选中仅靠 tooltip 体现；FR-006 的「高亮」需要新增视觉表达。
5. **「其他」的归类必须发生在归一化之前** —— `mapCategoryForDisplay` 对 `other:购物` 会剥掉前缀返回 `'购物'`（`expense_category_helper.dart:26-31`），这正是当前合计饼图把其他消费混进同名列的原因。判定必须先用 `ExpenseRecord.isOther`，再归一化。
6. **「杂项」不是数据库分类** —— 它由 `livingTotal` 倒推产生（`agg.dart:180-189 / 285-288`），没有任何 `ExpenseRecord` 对应，因此必须是独立展示分支（FR-022）。
7. **明细行的组件已就绪且已无标签** —— `_buildDetailRow` 是 `agg.dart` 的顶层函数，只渲染描述与金额，天然满足 FR-023，直接复用。
8. **吸顶用 Flutter 内建 `SliverPersistentHeader(pinned: true)`** —— 三个 `CustomScrollView`（`agg.dart:564 / 631 / 695`）结构一致，均在图表 adapter 与 `SliverList` 之间插入即可。
9. **切换视图清空筛选有现成钩子** —— `_tabController` 已在 `initState` 注册了监听（`agg.dart:73-81`），FR-018 在其中清空即可；滑动切换也会触发，无需额外处理。
10. **FR-015 天然成立但需复核** —— `AggPage` 未使用 `AutomaticKeepAliveClientMixin`，pop 后状态销毁。因为筛选状态放在 `AggPage` 而非 Tab 子页，`TabBarView` 的页面复用也不会造成残留。

## Phase 1 设计产物

- [data-model.md](./data-model.md) —— 筛选选择、周期分类汇总、明细项三个视图模型与排序/口径规则
- [contracts/ui-contract.md](./contracts/ui-contract.md) —— `ReportCard` 新 props、纯函数聚合层签名、吸顶标签契约
- [quickstart.md](./quickstart.md) —— 端到端验证步骤与期望结果

## Complexity Tracking

无违反项，不适用。本次不新增架构元素：无新依赖、无新表、无新路由、无新模块。
