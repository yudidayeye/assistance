# Phase 1 数据模型：历史记录报表饼图点击联动周期卡片筛选

**Feature**: `001-report-pie-filter` | **Date**: 2026-09-20

**重要前提**：本功能**不涉及任何数据库 schema 变更**。`DatabaseService._currentVersion` 不动，`onUpgrade` 不动，不新增表、不新增字段。下列全部是**内存中的视图模型**，在每次点击或范围变更时由既有内存数据重算得出，页面销毁即消失。

---

## 1. CategoryFilterSelection（筛选选择）

| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| `categoryName` | `String?` | 当前选中的分类**显示名**；`null` 表示未筛选 |

**取值域（canonical，顺序即图例固有顺序）**：`购物`、`生活`、`工作`、`娱乐`、`大餐`、`杂项`、`其他`

**约束**：

- 取值 MUST 是**显示名**，MUST NOT 是扇区数组下标。扇区数组按金额降序排列，范围条件一变排序即变，下标会指向另一个分类（research R1）。
- `balance`（结余）MUST NOT 出现在取值域内（FR-019）。
- 同一时刻至多一个分类生效（FR-004）。
- **不持久化**：不写 `toolbox.db`、不写 `app_settings`、不进 `SettingsController`（FR-014 / FR-015 / SC-006）。

**状态转移**：

| 触发 | 结果 |
| :--- | :--- |
| 点击扇区 / 图例行（未选中或选中别的分类） | `categoryName = 被点分类` |
| 再次点击当前已选中的分类（扇区或图例） | `null` |
| 点击扇区与图例之外的空白 | `null` |
| 点击吸顶标签的关闭控件 | `null` |
| 调整范围条件（年 / 月 / 阶段）后该分类在新范围内无任何金额 | `null`（自动取消，FR-016） |
| 调整范围条件后该分类仍有金额 | 保持（FR-016 / FR-016a） |
| 切换视图（日常 / 大额 / 合计） | `null`（FR-018） |
| 切换报表视图（占比 ↔ 趋势） | 保持（FR-017） |
| 从卡片进入详情页再返回 | 保持（同一次页面停留，FR-015） |
| 退出历史记录页 | 随页面状态一并销毁（FR-015） |

---

## 2. PeriodCategorySummary（周期 × 分类汇总）

筛选生效后，列表中的**每一张卡片**对应一个本对象。三个视图统一使用此结构，由各自的展示层决定渲染哪一部分。

| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| `periodId` | `int` | 所属周期 |
| `categoryName` | `String` | 本次筛选的分类显示名 |
| `dailySubtotal` | `double` | 日常侧（`ExpenseRecord`）该分类小计 |
| `largeSubtotal` | `double` | 大额侧（`LargeExpenseRecord`）该分类小计 |
| `dailyItems` | `List<FilterItem>` | 日常侧明细，已按既有展示顺序排好 |
| `largeItems` | `List<FilterItem>` | 大额侧明细，已按既有展示顺序排好 |
| `isResidualOnly` | `bool` | 仅「杂项」为 `true`：有小计、必然无明细 |
| `totalCount` | `int` | `dailyItems.length + largeItems.length`，即「查看全部 N 条」的 N |

**派生（由展示层计算，不入模型）**：

- `visibleItems` = 前 3 条（FR-011）
- `isExpandable` = `totalCount > 3`
- `hasAnyAmount` = `dailySubtotal + largeSubtotal > 0`

### 计算规则

1. **分类归属顺序（关键）**：对每条记录，**先**判断 `isOther`（`category == 'other' || category.startsWith('other:')`），**再**对非其他的记录调用 `mapCategoryForDisplay`。
   - `isOther == true` → 归入 `其他`（无论其子类是不是「购物」）
   - `isOther == false` → 归入 `mapCategoryForDisplay(category)` 的结果
   若顺序颠倒，`other:购物` 会被剥前缀成 `购物` 而混入同名列（research R5）。

2. **阶段口径（FR-016a）**：当且仅当筛选栏选中了阶段，**且**当前是日常视图时，日常侧只统计 `stageId == 所选阶段的 id` 的 `ExpenseRecord`（阶段 id 由 `stages[selectedStage - 1].id` 取得，与 `agg.dart:266-271` 的既有取法一致）。大额与合计视图的饼图不响应阶段，故其卡片也 MUST NOT 按阶段收敛。

3. **「杂项」（FR-022）**：`dailySubtotal = Σ 该周期各阶段 livingTotal（仅取正值）`，`dailyItems` 恒为空，`isResidualOnly = true`。仅日常与合计视图存在；大额视图不会命中此分类。

4. **排序（FR-011）**：
   - 日常 / 大额视图：明细沿用 `getExpensesByPeriod` 的既有顺序（`ORDER BY sort_order ASC, created_at ASC`）。
   - 合计视图：**先 `dailyItems`、后 `largeItems`**，两组各自沿用上述顺序，跨组不混排（不按金额、不按日期）。因此「前 3 条」= 日常前 3 条，不足则续取大额的前若干条。

5. **零金额周期**：仍产出对象，小计为 0、明细为空，卡片保留在列表中并显示零（FR-010）。

---

## 3. FilterItem（明细项）

| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| `description` | `String` | 支出描述；为空时以分类名占位，不显示空白 |
| `amount` | `double` | 金额，渲染为 `-¥…` |

**约束**：MUST NOT 携带分类名、子类名或任何分类标签（FR-023）。子类信息（`other:购物` 中的「购物」）MUST 只保留在数据库里，不进入本模型。

**理由**：子类名与普通分类同名时（`其他·购物` vs 真正的 `购物`），带上标签会让用户无法分辨这笔钱属于哪一边。

---

## 4. FilterLabelState（吸顶筛选标签）

| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| `categoryName` | `String` | 当前筛选的分类名，直接展示 |
| `isVisible` | `bool` | 等于 `筛选选择 != null`（FR-021）。**MUST NOT 依赖当前报表视图** |

**约束**：

- 标签 MUST 提供关闭控件，点击等价于再次点击同一分类（FR-020）。
- 未筛选时 MUST NOT 渲染（FR-021）。
- 标签底色 MUST 不透明（取 `appTheme.cardBackground`），保证滚动时下方卡片穿过其底部时不被误读。
- 标签 MUST 在「支出占比」与「支出趋势」两个报表视图下**同等渲染**——「支出趋势」没有饼图与图例，标签是它唯一的取消入口（FR-006a / FR-017 / SC-002，见 research R11）。渲染条件 MUST NOT 写成 `仅当报表处于支出占比时`。

---

## 5. 明确不存在的数据

| 项 | 原因 |
| :--- | :--- |
| 新表 / 新字段 / 迁移 | 纯展示层功能，不产生任何持久化需求（FR-014） |
| 筛选状态的持久化 | FR-015 / SC-006 要求退出页面即失效 |
| 新的数据库查询方法 | 重算只遍历既有内存数据（research R10） |
| 「大额追加」的分类归属 | `LargeAdditionRecord` 结构上就没有分类字段（`add_large_addition` 只写 `period_id/amount/reason/created_at`），故它不参与任何分类筛选，筛选态下随明细区一起消失（FR-008） |
