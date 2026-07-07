# 周期记账优化需求 v2.3

## 1. 去掉批量记账独立页面，集成到阶段编辑页

### 现状
- 周期详情页底部有 FAB「批量记账」按钮，跳转到独立的 `BatchExpensePage`
- `BatchExpensePage` 接收 `periodId`，页面内选择阶段 → 批量添加支出条目 → 一次性保存
- 阶段编辑页 `StageEditPage` 也接收 `periodId`，展示所有阶段的日期/追加/支出编辑

### 需求
- **删除** 独立的批量记账页面 `BatchExpensePage` 及其路由 `batch_expense/:periodId`
- **删除** 周期详情页 `PeriodDetailPage` 中的「批量记账」FAB 按钮
- 将批量记账功能（选择分类、金额、描述，添加到待保存列表，一次性保存）**集成到阶段编辑页 `StageEditPage`** 中
- 阶段编辑页已有"+ 添加支出"按钮，在此基础上增强：保留当前的逐条添加 + 待保存列表 + 汇总 + 批量保存的交互模式（参考现有 `BatchExpensePage` 的表单逻辑）
- 阶段编辑页中的批量记账只针对**当前编辑的阶段**，不再需要阶段选择器

### 涉及文件
- `lib/modules/period_book/pages/batch_expense_page.dart` — 删除
- `lib/modules/period_book/pages/stage_edit_page.dart` — 集成批量记账表单
- `lib/modules/period_book/pages/period_detail_page.dart` — 移除 FAB 和相关路由跳转
- `lib/modules/period_book/period_book_module.dart` — 移除 `batch_expense/:periodId` 路由
- `lib/modules/period_book/pages/add_expense_page.dart` — 评估是否保留（已有独立添加支出页）

---

## 2. 去掉卡片底部的「追加」按钮，替换为展开明细

### 现状
- `StageCard` 底部有一个操作栏 `_buildBottomActions()`，包含一个「追加」按钮（`onAddAddition`）
- 卡片头部已有展开/收起功能，展开后显示购物/其他/追加的明细列表

### 需求
- **删除** 卡片底部的操作栏（`_buildBottomActions` 方法及其调用）
- 底部操作栏原来只有「追加」一个按钮，删除后卡片底部更简洁
- 用户如需追加，改为在**阶段编辑页**中操作（阶段编辑页已有「+ 添加追加」按钮）
- 保留现有的展开/收起明细功能不变（点击卡片头部展开，显示支出和追加明细）

### 涉及文件
- `lib/modules/period_book/widgets/stage_card.dart` — 移除 `_buildBottomActions` 及相关属性
- `lib/modules/period_book/pages/period_detail_page.dart` — 移除 `onAddAddition` 回调传递

---

## 3. 阶段编辑页只能编辑当前阶段，导航标题改为阶段名

### 现状
- `StageEditPage` 接收 `periodId`，展示该周期下**所有阶段**的编辑
- 每个阶段section都有日期编辑、追加记录、支出明细、余额编辑
- 导航标题固定为「阶段管理」
- 从卡片编辑按钮点击时，跳转到 `stage_edit/:periodId`（不区分是哪个阶段）

### 需求
- `StageEditPage` 改为接收 `stageId`（而非 `periodId`），**只展示和编辑当前阶段**
- 页面只包含一个阶段的编辑区域（日期、追加、支出、余额），不再循环展示多个阶段
- 导航标题从固定的「阶段管理」改为**动态阶段名**，格式为 `第N阶段`（如「第1阶段」「第2阶段」）
- 删除「添加阶段」按钮和删除阶段功能（这些应放在周期编辑中处理）
- 卡片上的编辑按钮跳转路由改为 `stage_edit/:stageId`

### 涉及文件
- `lib/modules/period_book/pages/stage_edit_page.dart` — 改为接收 `stageId`，只展示单阶段
- `lib/modules/period_book/pages/period_detail_page.dart` — 编辑按钮传 `stage.id` 而非 `period.id`
- `lib/modules/period_book/widgets/stage_card.dart` — `onEdit` 回调传 stageId
- `lib/modules/period_book/period_book_module.dart` — 路由参数从 `periodId` 改为 `stageId`

---

## 4. 阶段按自然周（周一到周日）划分

### 现状
- `_generateStages()` 按从开始日期起每 7 天一个阶段划分
- 例如：开始日期是周三，则第一阶段是周三到周二

### 需求
- 阶段按**自然周**划分，即每周一到周日为一个阶段
- 如果周期开始日期不是周一，则第一个阶段从**开始日期到当周周日**
- 如果周期结束日期不是周日，则最后一个阶段从**当周周一到结束日期**
- 中间完整覆盖的阶段均为周一到周日

#### 示例
- 周期 3.5（周三）~ 4.15（周二）
  - 第1阶段：3.5（周三）~ 3.9（周日）— 开始到当周周日
  - 第2阶段：3.10（周一）~ 3.16（周日）
  - 第3阶段：3.17（周一）~ 3.23（周日）
  - 第4阶段：3.24（周一）~ 3.30（周日）
  - 第5阶段：3.31（周一）~ 4.6（周日）
  - 第6阶段：4.7（周一）~ 4.13（周日）
  - 第7阶段：4.14（周一）~ 4.15（周二）— 当周周一到结束

### 涉及文件
- `lib/modules/period_book/services/period_book_service.dart` — 修改 `_generateStages()` 方法

---

## 5. 支出明细支持拖动排序

### 现状
- `StageCard` 展开后显示支出明细列表，目前使用 `Dismissible` 支持左滑删除
- 支出列表按 `created_at ASC` 排序
- `StageEditPage` 中的支出表格不支持排序

### 需求
- 在 `StageCard` 展开的支出明细中，支持**长按拖动交换顺序**
- 拖动排序后，更新所有受影响支出的 `sort_order`（需要在 `mod_period_book_expenses` 表中新增 `sort_order` 字段）
- 拖动交互：长按条目 → 出现拖动手感反馈 → 拖动到新位置松手 → 自动更新顺序
- 追加记录不需要拖动排序功能
- 排序仅在同一分类内有效（购物类内部排序、其他类内部排序），还是全局排序需确认
  - **建议方案：全局排序** — 拖动时在整个支出列表中调整位置，不按分类分组

### 数据模型变更
- `mod_period_book_expenses` 表新增 `sort_order` 字段（INTEGER，默认值 0）
- `ExpenseRecord` 模型新增 `sortOrder` 字段
- 数据库版本升级（v3 → v4），`onUpgrade` 中 ALTER TABLE 添加字段

### 涉及文件
- `lib/modules/period_book/models/expense_record.dart` — 新增 `sortOrder` 字段
- `lib/modules/period_book/widgets/stage_card.dart` — 展开明细区域用 `ReorderableListView` 或自定义拖拽实现
- `lib/modules/period_book/services/period_book_service.dart` — 新增 `updateExpenseOrder()` 方法
- `lib/core/storage/database_service.dart` — 数据库迁移 v3 → v4
