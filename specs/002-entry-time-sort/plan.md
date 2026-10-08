# Implementation Plan: 记账条目可选时间与按时间排序

**Branch**: `20261008-225439-entry-time-sort` | **Date**: 2026-10-08 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/002-entry-time-sort/spec.md`

## Summary

为 `period_book` 模块的**阶段详情页**与**大额页**的全部 6 个新增条目表单增加一个**可选的日粒度时间字段**，并让填写了时间的条目自动落到列表中对应的位置，使列表呈现「按时间顺叙」的观感；未填写时间的条目行为与改动前一致（追加到末尾），但可被无条件拖到任意位置。

技术要点（推导见 [research.md](./research.md)）：

1. **时间不参与排序比较**。列表顺序由既有的 `sort_order` 列**独占承载**；时间字段只在「新增 / 修改时间」时充当一次性的**落位依据**。这是 spec「排序模型」章节的直接落地——任何由日期派生的排序键都会把无时间条目钉死在日期区间里，与「未填写时间可无条件任意拖动」互斥。
2. **落位算法**（FR-003）：扫描同组已排序条目，落在**第一个 `entry_date` 晚于新日期**的条目前面；不存在则追加到末尾。该算法精确复现 SC-002 的 `0-3-1-2`。
3. **新增与修改共用同一条落位路径**：`addXxx` 先按现有 `max(sort_order)+1` 插入拿到 id，随后调用与「修改时间」完全相同的 `_rescheduleXxx(id, entryDate)`，避免两套插入逻辑分叉。
4. **拖拽约束**（FR-011）在 `ReorderableListView.onReorder` 中前置校验：未填时间放行；已填时间要求「前方无更晚、后方无更早」，否则拒绝并给出 SnackBar 反馈。
5. **Schema**：4 张业务表各增一列 `entry_date TEXT`（可空，`YYYY-MM-DD`），`DatabaseService._currentVersion` 由 **17 → 18**，走既有 `onUpgrade` 迁移路径。**不删表重建**。

## Technical Context

**Language/Version**: Dart（SDK `>=3.0.0 <4.0.0`）/ Flutter stable

**Primary Dependencies**: `sqflite` + `sqflite_common_ffi`、GoRouter、`fl_chart`。**本次不新增任何依赖**

**Storage**: 本地 SQLite `toolbox.db`（`DatabaseService.instance`，schema 版本 17 → 18）。涉及 4 张表：
`mod_period_book_addition(s|s)`、`mod_period_book_expenses`、`mod_period_book_large_additions`、`mod_period_book_large_expenses`

**Testing**: `flutter test`。新增纯函数单测 `test/modules/period_book/entry_ordering_test.dart`；跑 `flutter test test/modules/period_book`

**Target Platform**: Android、Windows

**Project Type**: 移动 / 桌面单应用（Flutter），模块化插件架构

**Performance Goals**: 重排结果 1 秒内可见（SC-004）；单次落位写入 ≤ 同组条目数条 UPDATE

**Constraints**:
- 全程离线，**不得**引入云端同步、账号体系或遥测（宪法 I）
- schema 变更**必须**走版本递增 + `onUpgrade`，**禁止**删表重建（宪法 III / FR-009）
- 备份 JSON **必须**向后兼容：旧备份（无 `entry_date`）可导入并按「未填写」处理（FR-008）
- 视觉改动**必须**先读 `docs/UI.md`，颜色/间距取自 `AppThemeExtension`，禁止硬编码

**Scale/Scope**: 单用户本地数据。典型规模为每个阶段/周期几十条条目——允许「整组重编号」这种 O(n) 写入策略，不需要间隙法或浮点位序

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 原则 | 门禁项 | 结论 |
| :--- | :--- | :--- |
| **I. 本地优先与隐私不可妥协** | 是否引入云端同步 / 账号 / 遥测？ | ✅ 通过。时间字段仅落在本地 `toolbox.db`；无网络调用。 |
| **II. 模块化插件架构** | 是否越界改动模块外结构？ | ✅ 通过。改动全部落在 `lib/modules/period_book/` 与 `lib/core/storage/database_service.dart`、`lib/core/settings/import_export_service.dart`（后两者是 schema / 备份的既有归属地，任何模块的 schema 变更都要经过它们）。不新增模块、不改注册顺序与路由。 |
| **III. 数据完整性与迁移安全** | 是否递增版本并在 `onUpgrade` 提供迁移？是否保留备份兼容？ | ✅ 通过。`_currentVersion` 17→18 + `_migrateToV18`（4 条 `ALTER TABLE ... ADD COLUMN entry_date TEXT`）；旧行该列为 NULL，天然满足 FR-006；导入侧 `map['entry_date']` 缺失取 NULL，导出/导入结构向后兼容（FR-008）。整组重编号包在 `DatabaseService.transaction` 中。 |
| **IV. 按需且贴近改动的测试** | 是否有对应测试？ | ✅ 通过。落位算法与拖拽合法性抽为**纯函数**，单测覆盖 SC-002 与 FR-011；测试目录镜像 `lib/` 结构。 |
| **V. 视觉一致性遵循 UI 规范** | 是否先读 `docs/UI.md`？是否使用主题 token？ | ⚠️ 实现阶段**必须先读 `docs/UI.md`**。计划层面的约定：日期字段与列表上的日期标记一律取 `Theme.of(context).appTheme` 的 token 与 `AppSpacing`，**不得**硬编码色值/间距；文案简体中文，标识符英文。 |

**初检结论**：无违规，无需 Complexity Tracking。**Phase 1 后复检**：见文末「Post-Design Constitution Check」。

## Project Structure

### Documentation (this feature)

```text
specs/002-entry-time-sort/
├── spec.md              # 已存在（/speckit-specify 产出）
├── plan.md              # 本文件
├── research.md          # Phase 0 产出
├── data-model.md        # Phase 1 产出
├── quickstart.md        # Phase 1 产出
├── contracts/           # Phase 1 产出
│   └── entry-ordering.md        # 排序纯函数契约
│   └── period-book-service.md   # service 层接口变更契约
├── checklists/
│   └── requirements.md  # 已存在
└── tasks.md             # Phase 2 产出（/speckit-tasks，本命令不生成）
```

### Source Code (repository root)

```text
lib/
├── core/
│   ├── storage/
│   │   └── database_service.dart          # [改] _currentVersion 17→18；建表 DDL 增列；_migrateToV18
│   └── settings/
│       └── import_export_service.dart     # [改] 导出含 entry_date；导入读取 entry_date（缺失→NULL）；
│                                          #      顺手补齐 large_additions 导入遗漏的 sort_order
└── modules/period_book/
    ├── models/
    │   ├── expense_record.dart            # [改] +entryDate
    │   ├── addition_record.dart           # [改] +entryDate
    │   ├── large_expense_record.dart      # [改] +entryDate
    │   └── large_addition_record.dart     # [改] +entryDate
    ├── services/
    │   ├── period_book_service.dart       # [改] addXxx/updateXxx 支持 entryDate；新增 _rescheduleXxx
    │   └── entry_ordering.dart            # [新] 落位与拖拽合法性的纯函数（无 IO，可直接单测）
    ├── widgets/
    │   ├── add_form.dart                  # [改] +可选日期字段（selectedDate / onDateChanged）
    │   ├── expense_section_card.dart      # [改] ExpenseItemData +entryDate；行内展示日期
    │   ├── addition_section_card.dart     # [改] AdditionItemData +entryDate；行内展示日期
    │   └── expense_category_helper.dart   # [改] buildExpenseItem 渲染日期标记
    └── pages/
        ├── stage_edit_page.dart           # [改] 3 个表单的日期 state；落位；onReorder 约束；编辑弹窗
        └── large_items_edit_page.dart     # [改] 同上

test/modules/period_book/
└── entry_ordering_test.dart               # [新] 落位算法 + 拖拽合法性 + SC-002 端到端序列
```

**Structure Decision**：沿用既有模块化布局，不新建目录层级。落位与拖拽判定逻辑单独抽到 `lib/modules/period_book/services/entry_ordering.dart` 作为**纯函数模块**——它是本特征唯一有实质分支的逻辑，抽出来才能在不启动 Flutter 的情况下按宪法 IV 快速单测（对齐既有的 `widgets/category_filter_helper.dart` 先例）。

## Complexity Tracking

> 无宪法违规项，本表留空。

| Violation | Why Needed | Simpler Alternative Rejected Because |
| :--- | :--- | :--- |
| — | — | — |

## Phase 0 / Phase 1 产出

- [research.md](./research.md) — 5 项关键技术决策与备选方案对比
- [data-model.md](./data-model.md) — 4 张表的字段变更、实体属性、迁移与兼容规则
- [contracts/entry-ordering.md](./contracts/entry-ordering.md) — 排序纯函数签名与语义契约
- [contracts/period-book-service.md](./contracts/period-book-service.md) — service 层方法签名变更契约
- [quickstart.md](./quickstart.md) — 端到端可执行验证步骤（含 SC-002 复现脚本）

## Post-Design Constitution Check

Phase 1 设计完成后复检：

| 原则 | 复检项 | 结论 |
| :--- | :--- | :--- |
| I | 设计产物中无网络/云端/遥测 | ✅ 通过 |
| II | 无新增模块、无路由改动、无 `main.dart` 顺序改动 | ✅ 通过 |
| III | 迁移为纯 `ADD COLUMN`（可空、无默认值），不触碰既有列；旧数据全部落在 `entry_date = NULL` 分支，与 FR-006 一致；重编号包在事务中 | ✅ 通过 |
| IV | 核心逻辑已抽为纯函数并配单测；改动面覆盖 `lib/core/`，但**仅** `database_service.dart` 与 `import_export_service.dart` 两个文件、且不影响其他模块行为，按「改动范围匹配」原则跑 `test/modules/period_book` 即可；若实现中改到 `lib/shared/` 则升级为全量 | ✅ 通过 |
| V | 实现前置条件：先读 `docs/UI.md`；日期字段样式复用页面既有 `showDatePicker` 约定（`firstDate: DateTime(2020)` / `lastDate: DateTime(2030)`），与 `stage_edit_page._buildDialogDateRow` 保持一致 | ✅ 通过（附带前置条件） |

**门禁结论**：通过，可进入 `/speckit-tasks`。
