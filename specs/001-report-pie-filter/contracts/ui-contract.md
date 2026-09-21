# Phase 1 契约：历史记录报表饼图点击联动周期卡片筛选

**Feature**: `001-report-pie-filter` | **Date**: 2026-09-20 | **类型**: UI 契约（Flutter widget 与纯函数接口）

本项目不对外暴露 API / CLI / 网络端点，因此契约以**组件接口**形式记录：新增或变更的 widget 参数、回调、纯函数签名，以及每个接口必须满足的可观测行为。实施时这些签名即为 `agg.dart` / `report_card.dart` / `category_filter_helper.dart` 之间的边界。

---

## C1. `ReportCard`（受控化改造）

**文件**: `lib/modules/period_book/widgets/report_card.dart`

```text
// 新增参数
final String? selectedCategory;                  // null = 未筛选
final ValueChanged<String?>? onCategorySelected;  // 传 null 表示取消
```

**行为契约**：

| 编号 | 契约 |
| :--- | :--- |
| C1-1 | `selectedCategory == null` 时，饼图与图例 MUST 与改造前完全一致——无高亮、无 tooltip 残留 |
| C1-2 | `selectedCategory != null` 时，**该分类对应的扇区** MUST 高亮；图例中**该分类所在行** MUST 同步高亮。两个入口的选中态 MUST 一致 |
| C1-3 | 其余扇区与图例行 MUST 保持未选中时的外观，MUST NOT 整体淡化 |
| C1-4 | 点击扇区、点击图例行，二者 MUST 派发**同一个** `onCategorySelected(分类显示名)` |
| C1-5 | 再次点击当前已选中的分类（扇区或图例）MUST 派发 `onCategorySelected(null)` |
| C1-6 | 点击扇区与图例之外的空白 MUST 派发 `onCategorySelected(null)` |
| C1-7 | 真实来源是 `widget.selectedCategory`，组件 MUST NOT 自持选中状态（禁止再以 `_touchedIndex` 作为真值） |
| C1-8 | 悬浮 MUST NOT 改变选中态（只响应点击） |
| C1-9 | 切换报表视图（占比 ↔ 趋势）MUST NOT 派发取消；`selectedCategory` 原样保留（FR-017） |

**不变量**：分类名的取值域 MUST 与 `CategoryFilterSelection` 一致，且 MUST NOT 出现 `balance`。

---

## C2. `CategoryFilterHelper`（新增纯函数聚合层）

**文件**: `lib/modules/period_book/widgets/category_filter_helper.dart`（与既有的 `expense_category_helper.dart` 同类同目录）

**建议签名**（纯函数，无 IO、无 `BuildContext`，可直接 unit test）：

```text
static List<PeriodCategorySummary> buildSummaries({
  required String categoryName,
  required List<PeriodRecord> periods,
  required Map<int, List<ExpenseRecord>> expenseMap,
  required Map<int, List<LargeExpenseRecord>> largeExpenseMap,
  required Map<int, List<StageRecord>> stagesMap,
  required Map<int, PeriodCalculations> calcMap,
  required int? selectedStage,   // 非空时日常侧按该阶段收敛（FR-016a）
  required bool includeDaily,    // 日常视图 true；大额视图 false
  required bool includeLarge,    // 大额与合计视图 true；日常视图 false
})
```

**行为契约**：

| 编号 | 契约 |
| :--- | :--- |
| C2-1 | 每个入参周期 MUST 产出一个对象，包括无该分类支出的周期（小计 0、明细空） |
| C2-2 | 分类归属 MUST 先判 `isOther`、后归一化；`other:购物` MUST 归入 `其他`，MUST NOT 归入 `购物` |
| C2-3 | `categoryName == '杂项'` 时 MUST 产出 `isResidualOnly = true`、`dailyItems` 为空、小计为各阶段正残值之和 |
| C2-4 | `includeDaily && !includeLarge` 时 `largeSubtotal == 0` 且 `largeItems` 为空；反之亦然 |
| C2-5 | 合计场景（两者皆 true）下，明细顺序 MUST 为先 `dailyItems` 后 `largeItems`，跨组不混排 |
| C2-6 | `selectedStage != null` 且 `includeDaily` 时，日常侧 MUST 只统计该阶段的记录（FR-016a）；`selectedStage != null` 且仅大额侧时（大额 / 合计视图）MUST NOT 按阶段收敛 |
| C2-7 | 组内明细顺序 MUST 沿用 `getExpensesByPeriod` 的既有顺序（`sort_order ASC, created_at ASC`） |
| C2-8 | 本函数 MUST NOT 发起任何数据库查询 |
| C2-9 | 返回对象的 `totalCount` MUST 等于两侧明细条数之和，即「查看全部 N 条」的 N |

**建议同时导出**（便于展示层与测试共用）：

```text
static List<FilterItem> visibleItems(PeriodCategorySummary s, {required bool expanded});
```

`expanded == false` 时返回前 3 条，`true` 时返回全部（FR-011 / FR-012）。

---

## C3. 吸顶筛选标签

**承载**: `SliverPersistentHeader(pinned: true)`，插在三个视图各自的图表 `SliverToBoxAdapter` 与卡片 `SliverList` 之间（`agg.dart:564 / 631 / 695`）

**行为契约**：

| 编号 | 契约 |
| :--- | :--- |
| C3-1 | `selectedCategory == null` 时 MUST NOT 渲染该 sliver（FR-021） |
| C3-2 | 筛选生效时 MUST 显示当前筛选的分类名（FR-006a） |
| C3-3 | MUST 提供关闭控件，点击后与再次点击同一分类效果完全一致（FR-020） |
| C3-4 | 列表滚动时 MUST 吸顶常驻于可视区域顶部，用户在列表任意位置都能看到并关闭（SC-002） |
| C3-5 | 底色 MUST 不透明，MUST NOT 让下方卡片内容透出造成误读 |
| C3-6 | 打开 / 关闭的滑动 MUST 不得引起卡片列表重排跳动 |
| C3-7 | 渲染条件 MUST NOT 依赖当前的报表视图：切到「支出趋势」后标签 MUST 仍然渲染、关闭控件 MUST 仍可用（FR-006a / FR-017 / SC-002，见 research R11）。该视图没有饼图与图例，标签是唯一的取消入口 |

---

## C4. 卡片展示契约（三个视图共用规则）

| 编号 | 契约 |
| :--- | :--- |
| C4-1 | 筛选结果 MUST 追加在**既有汇总行下方**；汇总行（日常 / 合计的第一行主金额与第二行两列；大额的第一行净额）MUST 原样保留，数值口径不变（FR-013） |
| C4-2 | 卡片结构为「汇总行 → 分类小计 → 至多 3 条明细 → 查看全部 / 收起」；未展开时高度不随条目总数增长（SC-004） |
| C4-3 | 明细行 MUST 只显示描述与金额，MUST NOT 显示分类或子类标签（FR-023）；实现上复用 `agg.dart:1360` 的 `_buildDetailRow` |
| C4-4 | `totalCount > 3` 时 MUST 显示「查看全部 N 条」；点击后**在该卡片内原地展开**，MUST NOT 跳页、MUST NOT 弹窗 / 浮层（FR-011） |
| C4-5 | 展开后 MUST 提供收起路径；展开状态以卡片为单位相互独立，允许多张同时展开（FR-012） |
| C4-6 | 展开与收起 MUST NOT 触发卡片主体的跳转；卡片主体点击的落点保持既有行为——日常与合计为周期详情页，大额为周期的大额记录页（FR-012） |
| C4-7 | `isResidualOnly == true` 时 MUST 只渲染小计与一行「来自未逐条记录的部分」的说明，MUST NOT 渲染明细区、MUST NOT 显示「查看全部」（FR-022） |
| C4-8 | 大额视图筛选时，未筛选时可见的「大额追加」「个人支出」「其他支出」三组 MUST 全部被替换，MUST NOT 与筛选结果叠加（FR-008） |
| C4-9 | 小计为 0 的周期卡片 MUST 保留在列表中并显示零，MUST NOT 渲染空的明细区域（FR-010） |

---

## C5. 页面状态契约（`AggPage`）

| 编号 | 契约 |
| :--- | :--- |
| C5-1 | `AggPage` 是筛选状态的唯一持有者；三个视图共用同一个 `selectedCategory` 字段，但切换视图时 MUST 清空（FR-018） |
| C5-2 | 清空动作 MUST 挂在 `_tabController` 的既有监听上（`agg.dart:73-81`），使**点击分段按钮与左右滑动**两种切换方式都能触发（FR-018） |
| C5-3 | 卡片展开状态 MUST 随筛选结果重算而整体重置（取消筛选、切换分类、调整范围条件、切换报表视图）|
| C5-4 | 调整范围条件（年 / 月 / 阶段）后，若该分类在新范围内无任何金额，MUST 清空筛选（FR-016） |
| C5-5 | 筛选 MUST NOT 产生任何数据写入（FR-014 / SC-006） |
| C5-6 | 视图切换与三个视图的筛选能力 MUST 相互独立，任一视图可单独交付、单独验证（SC-005） |
