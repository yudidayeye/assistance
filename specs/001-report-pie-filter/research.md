# Phase 0 研究：历史记录报表饼图点击联动周期卡片筛选

**Feature**: `001-report-pie-filter` | **Date**: 2026-09-20

本阶段无 `NEEDS CLARIFICATION`（本特性累计澄清 21 项：`/speckit-specify` 阶段 3 项 + 四轮 `/speckit-clarify` 共 18 项）。下列条目是设计前对代码的实证调查，每条给出结论、依据与备选方案。

---

## R1. 筛选状态的持有者：从 `ReportCard` 外提到 `AggPage`

**Decision**: 筛选状态（当前选中的分类名，或 `null`）由 `AggPage` 持有，`ReportCard` 改为受控组件：接收 `selectedCategory` 与 `onCategorySelected`，不再自持选中态。

**Rationale**: 卡片是筛选结果的下游消费者，状态必须位于二者共同祖先。既有代码的选中态藏在 `_ReportCardState._touchedIndex`（`report_card.dart:38`），且它是**扇区数组的下标**；该数组由 `_categoryOrder` 过滤后**按金额降序排序**（`report_card.dart:676-680`）。一旦用户改年份 / 月份 / 阶段，金额排序变化，同一个下标会指向完全不同的分类——违反 FR-016「调整范围后筛选保持」与 FR-016a「按新范围重算」。因此筛选键 MUST 是**分类显示名**（`购物 / 生活 / 工作 / 娱乐 / 大餐 / 其他 / 杂项`），不能是下标。

**Alternatives considered**:
- 保持 `ReportCard` 自持状态，通过回调把选中分类「广播」给页面 —— 双向同步两份真值，改范围时下标与分类名会短暂不一致，弃用。
- 用 `InheritedWidget` / Provider 做全局筛选状态 —— 项目状态管理为 `ChangeNotifier` + 静态单例，且规格明确「页面临时状态、不持久化」，引入作用域更广的机制属于过度设计，弃用。

---

## R2. 点击入口：改造既有 `PieTouchData` 回调，而非重写

**Decision**: 保留 `report_card.dart:715-739` 的 `touchCallback` 结构，把其中的 `setState(() => _touchedIndex = …)` 替换为对 `onCategorySelected(分类名)` 的回调，并让 `_touchedIndex` 由 `widget.selectedCategory` 反查得出。

**Rationale**: 既有回调已实现规格要求的全部三种分支：点中扇区 → 选中（`:736`）；再点同一扇区 → 取消（`:732-734`）；点到扇区外空白或 `touchedSection == null` → 取消（`:719-724`）。这分别对应 FR-001/FR-004、FR-003、FR-005，直接复用可保证「点中扇区之外取消」这一既有手感不被破坏。同时保留 `event is! FlTapDownEvent` 的过滤（`:718`），即只响应点击、不响应悬浮。

**Alternatives considered**:
- 换用 `fl_chart` 的其他手势 API 或自绘命中检测 —— 无收益，且会丢掉已有的点击/悬浮区分，弃用。

---

## R3. 图例行的可点性与选中态（新增）

**Decision**: `_buildLegend`（`report_card.dart:946`）增加 `isSelected` 与 `onTap` 两个参数，整行包裹手势并渲染选中态；图例行与扇区派发**同一个** `onCategorySelected(分类名)`。

**Rationale**: 当前图例只是一行无手势的 `Row`（图标 + 名称 + 百分比 + 金额）。FR-001 要求图例行与扇区等价，FR-006 要求二者选中态一致，FR-008（SC-008）要求占比极小的分类有尺寸充足的入口。图例与扇区本就由同一个 `entries` 列表驱动，两处调用同一回调即天然等价，不需要额外的状态同步。选中态的视觉建议用**行底色 / 左侧色条**（取 `appTheme` token），与扇区高亮区分开，避免两处都用同一种表达而不易辨认。

**Alternatives considered**:
- 只让扇区可点、图例仅作展示 —— 直接被 SC-008 否决（小占比分类点不中）。
- 点击图例时通过计算扇区角度反查下标 —— 无必要，且比直接传分类名更脆弱。

---

## R4. 扇区选中态的高亮表达（新增）

**Decision**: `_buildPieSection`（`report_card.dart:858`）增加 `isSelected`，选中时通过**扇区半径外扩 + 徽标放大加边框**表达；未选中的扇区保持原状，**不淡化**（FR-006 明确禁止整体淡化）。

**Rationale**: 现有代码只对 `_touchedIndex` 渲染 tooltip，扇区本身在外观上无差别，因此「选中了哪个分类」在图上不可见（尤其当 tooltip 因空间不足而被裁切时）。`PieChartSectionData.radius` 默认取 `PieChartData` 的值，逐扇区设置是 `fl_chart` 0.69 支持的既有能力，无需新依赖。不淡化其余扇区，与既有视觉语言一致（该图从未使用过淡化表达）。

**Alternatives considered**:
- 选中扇区改为更饱和的颜色 —— 与「同一分类色相」冲突，且需为每个分类再定义一个高亮色，弃用。
- 整体淡化未选中扇区 —— FR-006 明令禁止。

---

## R5. 分类归属：`isOther` 判定必须早于归一化

**Decision**: 新增的聚合层在归类时一律先用 `ExpenseRecord.isOther` / `LargeExpenseRecord.isOther` 判「是否属于其他消费」，再对非其他的记录调用 `mapCategoryForDisplay`。

**Rationale**: `mapCategoryForDisplay`（`expense_category_helper.dart:26-31`）对 `other:购物` 会**剥掉前缀**返回 `'购物'`，使其与真正记在「购物」分类下的记录同名——这正是当前合计饼图把其他消费混入普通分类扇区的机制（规格中已作为 FR-001b 要修的既有行为）。若聚合层沿用「先归一化、再判类」的顺序，筛选「购物」时会把其他消费一并列进来，且筛选「其他」时又会漏掉它们。判定顺序是本功能最关键的正确性约束。

**Alternatives considered**:
- 在 `mapCategoryForDisplay` 内部改掉剥前缀行为 —— 该方法有 5 处调用（`agg.dart`、`stage_edit_page.dart` 等），其中编辑页依赖该行为回显子类名，改动面远超本功能范围，弃用。范围约束收在新增的聚合层内。

---

## R6. 「杂项」的呈现分支

**Decision**: 聚合层把「杂项」识别为**残值伪分类**，只产出小计、不产出任何明细项，并在视图模型上以 `hasResidualOnly = true` 标记；卡片据此只渲染小计与一行说明，不渲染明细区、不显示「查看全部」（FR-022）。

**Rationale**: 「杂项」不是数据库里的分类，没有任何 `ExpenseRecord` 与之对应。它的金额来自两处倒推残值：日常侧 `agg.dart:180-189`（各阶段 `livingTotal` 之和）与阶段维度 `agg.dart:285-288`。日常与合计两个视图的饼图都有该扇区，大额视图没有。若按普通分类处理，卡片会渲染出一个永远空白的明细区。

**Alternatives considered**:
- 直接把「杂项」从可筛选分类中剔除 —— 与 SC-008「看得见就能选」冲突（它在饼图上可见）。弃用。

---

## R7. 明细行的复用

**Decision**: 直接复用 `agg.dart:1360` 的顶层函数 `_buildDetailRow`（描述 + 金额，无任何分类或子类标签）。

**Rationale**: 该函数被大额卡片的三组明细使用，签名只含描述、金额与颜色，天然满足 FR-023「明细行不显示分类或子类标签」。**MUST NOT** 改用 `ExpenseCategoryHelper.buildExpenseItem`——后者会渲染分类图标与标签（`expense_category_helper.dart:100-142`），违反 FR-023，且会重新引入「其他·生活」与「生活」撞标签的问题。

**Alternatives considered**:
- 复用 `buildExpenseItem` 但加开关隐藏标签 —— 该方法还被编辑页以「点按编辑 / 删除」语义使用，加开关会让它的职责继续膨胀，弃用。

---

## R8. 吸顶筛选标签的实现

**Decision**: 用 Flutter 内建的 `SliverPersistentHeader(pinned: true)` 承载标签，插在三个视图各自的「图表 `SliverToBoxAdapter`」与「卡片 `SliverList`」之间（`agg.dart:564 / 631 / 695`）。未筛选时不渲染该 sliver（FR-021）。

**Rationale**: 三个视图的 `CustomScrollView` 结构完全一致（图表 adapter → SliverList → 底部间距 adapter），插入点唯一且互不干扰。用内建 sliver 无需引入 `flutter_sticky_header` 之类的依赖（宪法要求新依赖须说明用途并评估包体积）。标签底色取 `appTheme.cardBackground`（不透明），保证滚动时下方卡片穿过其底部时不会被误读（Edge Case「标签不遮挡卡片内容」）。

**Alternatives considered**:
- 用 `Stack` + `Positioned` 覆盖在页面顶层 —— 需要自行处理滚动联动与安全区，且会脱离 sliver 布局体系，弃用。

---

## R9. 切换视图与离开页面时的清空

**Decision**: 在 `_tabController` 既有的监听里（`agg.dart:73-81`）清空选中分类，实现 FR-018；FR-015 依靠 `AggPage` 状态随 pop 销毁自然满足。

**Rationale**: 该监听对**点击分段按钮与左右滑动**两种切换方式都会触发，是唯一的切换收敛点，无需在 `SegmentedButton.onSelectionChanged`（`:500`）里重复处理（滑动手势不会经过那里）。`AggPage` 未使用 `AutomaticKeepAliveClientMixin`，且筛选状态放在页面而非 Tab 子页，因此 `TabBarView` 的页面复用不会造成跨次进入的残留。

**Alternatives considered**:
- 只在 `onSelectionChanged` 里清空 —— 漏掉滑动切换，会在滑动后留下与当前视图不符的筛选，弃用。

---

## R10. 性能：全内存重算，不新增查询

**Decision**: 聚合层只遍历 `AggPage._loadData` 已载入的 `_expenseMap` / `_largeExpensesMap` / `_stagesMap` / `_calcMap`，不新增任何数据库查询。

**Rationale**: `_loadData` 已按周期批量取回全部支出与大额记录（`getExpensesByPeriod` 一次 `IN` 查询覆盖全部阶段，`period_book_service.dart:518-530`）。筛选重算是 O(周期数 × 记录数) 的纯内存过滤，且只在点击或范围变更时触发一次，与列表构建解耦。若为「当前分类」单独发起查询，反而会在每次点击时增加往返延迟。

**Alternatives considered**:
- 为筛选新增 `getExpensesByCategory` 查询 —— 该方法签名是「按阶段 + 分类」（`period_book_service.dart:532`），与「按周期 + 分类」的粒度不匹配，且会引入与内存数据不一致的风险，弃用。

---

## R11. 「支出趋势」视图下的取消入口（澄清第 4 轮 Q3，已决）

**Decision**: 吸顶筛选标签在**两个报表视图下都渲染**。切到「支出趋势」后标签仍在、关闭控件仍可用，卡片继续按该分类筛选。切换报表视图**不派发**取消筛选。

**Rationale**: 「支出趋势」视图渲染的是 `_buildStageTrend` / `_buildMonthlyTrend`（`report_card.dart:338-344`），既没有饼图扇区、也没有图例行、也没有一块"扇区与图例之外"的区域——FR-003 / FR-005 定义的三条取消路径在该视图下**全部不存在**。而 FR-017 要求筛选在此视图下保留。若标签不渲染，用户就进入一个**筛不掉的状态**：看不到筛选来源，也没有任何可点之处，只能靠猜到要切回「支出占比」自救。这属于功能性缺陷而非视觉问题。标签是该视图下唯一不依赖饼图的取消入口，让它常驻几乎零成本。

**Alternatives considered**:
- **切到「支出趋势」即取消筛选** —— 会推翻 FR-017「保留」，且用户在比对走势时往往正是想盯着某个分类，每次切报表视图都要重选一次分类，操作成本明显上升。弃用。
- **筛选只在「支出占比」下生效，切到趋势时卡片恢复未筛选展示但记住筛选、切回后恢复** —— 引入了"筛选存在但不生效"的第三态，用户看到卡片内容变了却看不出为什么（没有饼图可参照），且需要额外的记忆与恢复逻辑。弃用。

**影响面**：仅 `agg.dart` 中标签 sliver 的渲染条件与 `ReportCard` 的视图切换回调——标签的渲染条件 MUST NOT 依赖当前报表视图。聚合层与卡片渲染不受影响。
