# Phase 0 研究：记账条目可选时间与按时间排序

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-10-08

本文件记录进入设计前必须拍板的技术选型。每项按「决策 / 理由 / 已否决的备选」记录。

---

## R1. 排序模型：位置承载 vs. 排序键派生

**决策**：列表顺序由既有的 `sort_order` 列**独占承载**。`entry_date` 是一份**普通数据属性**，只在「新增 / 修改时间」的那一刻充当一次性的**落位依据**，此后不再参与任何比较。

**理由**：spec 的 Clarifications 第 4 条明确要求「未填写时间的条目不按创建时间参与全局排序」。这是硬约束而非偏好——只要列表顺序由任何形式的时间派生键决定，无日期条目就会被永久钉死在其创建日期所处的区间内，物理上不可能被拖到区间之外。用户要求的「无条件任意拖动」与「时间排他决定顺序」在机制上互斥，只能二选一，用户选了前者。

**已否决的备选**：

| 备选 | 否决原因 |
| :--- | :--- |
| **A. 排序键 = `COALESCE(entry_date, created_at)` 升序** | 首版方案。无法实现「未填时间任意拖动」：拖动只改变 `sort_order`，而查询并不看 `sort_order`，拖完刷新即被日期键覆盖回原位。同时它需要假设 SC-002 的 4 条记录**创建跨天**才能复现 `0-3-1-2`，与用户原文「依次创建」不符。 |
| **B. 排序键 = `COALESCE(entry_date, NULL)`，NULL 排末尾** | 无日期条目全部挤到列表尾部且相互间仅按创建序，同样拖不走（会被强行归位到尾部区块）。 |
| **C. 引入独立的位置列（浮点/分数位序）** | 需要新增列并迁移全部既有数据，而 `sort_order` **已经存在**且已承担位置语义（`getExpensesByStage` 即 `ORDER BY sort_order ASC, created_at ASC`）。多引入一列只会制造「两套顺序真相」。 |

**对 SC-002 的验证**（同一批次依次录入，全部无初始条目）：

| 步骤 | 录入 | 依据 | 列表 |
| :--- | :--- | :--- | :--- |
| 1 | 0｜不填时间 | 追加到末尾 | `0` |
| 2 | 1｜10月9 | 扫描无「晚于 10/9」者 → 追加 | `0, 1` |
| 3 | 2｜不填时间 | 追加到末尾 | `0, 1, 2` |
| 4 | 3｜10月8 | 第一个「晚于 10/8」者是 1 → 插到它前面 | **`0, 3, 1, 2`** ✅ |

注意第 4 步插入到 `1` 之前而非 `0` 之后：`0` 无日期，不参与比较，被跳过。这正是「时间不参与比较、只作落位依据」的直接体现。

---

## R2. 落位算法

**决策**：线性扫描 + 插入索引，**不做**二分查找。

```text
resolveInsertIndex(siblings, entryDate):
  若 entryDate == null            → siblings.length          # 追加到末尾
  对 i 从 0 到 siblings.length-1:
    若 siblings[i].entryDate != null 且 siblings[i].entryDate > entryDate
        → 返回 i                                            # 落在第一个更晚的条目前面
  返回 siblings.length                                       # 无更晚者 → 末尾
```

**理由**：`siblings` 由 `getXxxbyYyy` 直接返回且已按 `sort_order` 排序，无需再排。个人记账的单组条目规模在几十量级，O(n) 扫描的绝对耗时在微秒级，二分查找带来的常数优化无意义，反而引入「在含 NULL 的序列上做二分」这类易错边界。

**关键语义约定**：`null`（未填）在落位扫描中一律**跳过**，既不视为「更早」也不视为「更晚」。这保证了 FR-005（未填时间者不被强制归位）与 US3（无日期条目可任意拖动）自洽。

**已否决的备选**：二分查找（收益为零、边界复杂）；「扫描到第一个更晚者即在其后插入」（与 FR-003「落在……之前」的字面语义相反，会导致同日条目插到已有同日条目之后，破坏 US2 场景 4 的预期）。

---

## R3. 位置值的写入策略：整组重编号

**决策**：插入到中间位置时，把**同组全部条目**按新顺序重写为 `0..n-1`，包在 `DatabaseService.transaction` 中。

**理由**：
1. 现有的 `updateExpensesOrder` / `updateAdditionsOrder` / `updateLargeExpensesOrder` / `updateLargeAdditionsOrder` **已经在做整组重编号**（遍历列表写回 `sort_order: i`）。复用同一策略意味着落位与拖拽走同一条代码路径，不存在两套编号规则互相踩踏。
2. 不需要为位序预留间隙，也就不存在「间隙耗尽需要重建」的隐藏状态与偶发重排。
3. 单组规模几十条 → 几十次 UPDATE，在 SQLite 本地事务中是亚毫秒级，远低于 SC-004 的 1 秒要求。
4. `DatabaseService.transaction<T>(action)`（`database_service.dart:663`）已存在，无需新增能力。

**已否决的备选**：

| 备选 | 否决原因 |
| :--- | :--- |
| **间隙法**（`sort_order` 以 10/100 递增，取中值插入） | 需要定义并处理间隙耗尽后的重建路径；且与既有 `updateXxxOrder` 的稠密编号（0..n-1）**语义冲突**——拖拽重排后间隙会被擦除，下一次插入仍需重建。两套规则并存是缺陷温床。 |
| **浮点 `sort_order REAL`** | 需要 `ALTER TABLE` 改列类型 → SQLite 需重建表，直接违反宪法 III「禁止删表重建」。 |
| **只更新受影响的区间** | 省下的写入量在微秒级，换来的是「哪段区间受影响」的边界推理，风险收益倒挂。 |

---

## R4. 新增与修改走同一条落位路径

**决策**：`addXxx` 保持「以 `max(sort_order)+1` 插入」不变（拿 id），插入成功后**调用与「修改时间」完全相同的 `_rescheduleXxx(id, entryDate)`**；`entryDate == null` 时 `_rescheduleXxx` 直接返回，等于什么都没做。

**理由**：若为新增单独写一套「算插入索引 → 重编号」逻辑，它就与修改时间那套是两份必须保持同步的实现。二者唯一的差别只是「id 是否已存在」，而这恰好就是 `_rescheduleXxx` 内部一次查询能覆盖的。合并后：

- 新增无日期 → `_rescheduleXxx` 早退 → 行为与改动前**逐字节一致**（满足 SC-001 零新增步骤）
- 新增有日期 → 与「给已有条目标日期」走同一算法 → SC-002 与 US2 场景 1 不可能出现行为分叉
- 修改时间 / 清空时间 → 明确落在 FR-004 的两条分支上

**已否决的备选**：在 `addXxx` 内联一份插入索引计算（两份实现需同步）；先算索引再插入（SQLite 无「插入到第 N 位」，仍需重编号两步走，无净收益）。

---

## R5. 拖拽约束的判定位置与数据流

**决策**：约束判定放在各页面 `ReorderableListView.onReorder` 的**最前面**，依据是**该卡片实际渲染的那个列表**（即 `ExpenseSectionCard` / `AdditionSectionCard` 收到的 `expenses` / `additions`），判定纯函数实现于 `entry_ordering.dart`。

**理由**：`ReorderableListView` 回传的 `oldIndex` / `newIndex` 是**它渲染的那个列表**的索引空间，而非页面 `_expenses` 全量列表的索引空间。`stage_edit_page._buildShoppingSection`（`stage_edit_page.dart:729`）传入的是 `_expenses.where((e) => !e.isOther)` 的子集，`large_items_edit_page` 同样把支出拆成 `_shoppingExpenses` / `_otherExpenses` 两份。在错误的索引空间里做判定会得到张冠李戴的结果，因此**必须在卡片自身的列表上判定**。

**索引补偿**：Flutter 的 `ReorderableListView` 在 `newIndex > oldIndex` 时，`newIndex` 是「移除前」的插入位，实际落点是 `newIndex - 1`。判定函数必须先做这次归一化，否则向上拖动会被误判。

**判定语义**（FR-011 原文）：把该条目按归一化后的索引放到目标位置后，检查

- 它**前方**是否存在 `entryDate` 晚于它的条目 → 存在则拒绝
- 它**后方**是否存在 `entryDate` 早于它的条目 → 存在则拒绝

`entryDate == null` 直接放行（无条件任意拖动）。被拒绝时 `onReorder` **不修改任何状态**（列表回弹到原位），并由页面弹出 SnackBar 给出可感知反馈（SC-006，1 秒内）。

**已否决的备选**：

| 备选 | 否决原因 |
| :--- | :--- |
| 在 `_expenses` 全量列表上判定 | 索引空间错位；且全量列表是「shopping 子集 + other 子集」的拼接（`_buildShoppingSection` + `_buildOtherSection` 分卡片渲染），拼接顺序并不等于用户看到的顺序。 |
| 用 `onReorderStart` / `onReorderEnd` 做动画拦截 | Flutter 未提供可靠的中途落点否决钩子，且无法在拖动过程中动态禁用某些落点；实现复杂度远超收益。 |
| 改为「允许拖动但事后按日期拉回」 | 会被用户感知为「拖了却没反应」——正是 FR-011 明确禁止的状态。 |

---

## R6. 时间字段的存储格式

**决策**：新列 `entry_date TEXT`，可空，存 `YYYY-MM-DD`（如 `2026-10-08`）。

**理由**：
1. 与项目既有约定一致——`stages.start_date` / `periods.start_date` 等日期字段同为 TEXT，页面侧用 `DateTime.parse` 读取。
2. `YYYY-MM-DD` 是**定长字典序 == 时间序**的，即使未来需要下推到 SQL 排序（`ORDER BY entry_date`），也不需要转换函数。虽然本特征刻意**不**用它排序，但保留了这条退路。
3. 日粒度（FR-002）与 spec 示例「10月8号」「10月9」一致，录入成本最低。

**已否决的备选**：存 `INTEGER` 时间戳（丢失「日」的可读性，排查数据时要手工换算，且与模块内其他日期字段风格割裂）；存 ISO8601 带时分的完整串（精度超出需求，会诱导出「同日不同时分谁在前」这种 spec 已明确排除的复杂度）。

---

## R7. 迁移写法

**决策**：`DatabaseService._currentVersion` 由 17 递增至 18，新增 `_migrateToV18(Database db)`，执行 4 条 `ALTER TABLE ... ADD COLUMN entry_date TEXT`；同时在 `_onCreate` 的建表 DDL 里为这 4 张表补上该列。

**理由**：可空且无 `DEFAULT` 的 `ADD COLUMN` 是 SQLite 上唯一**不触表重建**的加列方式，完全落在宪法 III 的允许范围内。旧行该列自动为 `NULL` → 语义上即「未填写时间」→ **零迁移代码即满足 FR-006 与 SC-003**（历史条目顺序由 `ORDER BY sort_order ASC, created_at ASC` 保持不变，因为 `sort_order` 列一个字节都没动）。

`_onCreate` 与 `_onUpgrade` 两处都要改：前者服务于全新安装，后者服务于升级安装。这是本仓库既有的、已被 `_migrateToV7` 等 11 个迁移函数验证过的模式。

**已否决的备选**：把 `entry_date` 并入既有 JSON 列（如需扩展还得再迁移一次，且失去可查询性）；删表重建（宪法 III 明令禁止）。

---

## R8. 备份结构与一处既有缺陷

**决策**：
1. 导出：4 张表的记录原样带出，`entry_date` 自然进入 JSON（导出走 `_db.query`，无需改导出代码）。
2. 导入：4 张表的 `rawInsert` 语句各增加 `entry_date` 列与 `map['entry_date']` 参数。参数值**不加** `?? 0` 之类的兜底——列可空，缺失键取 `null` 即是正确的「未填写」语义（满足 FR-008 与 US4 场景 2）。
3. **一并修复既有缺陷**：`import_export_service.dart:428` 处 `mod_period_book_large_additions` 的 `INSERT OR REPLACE` **遗漏了 `sort_order` 列**（另 3 张表都有）。这会导致「导入后大额追加记录的顺序全部退化为 `created_at` 序」。本特征的设计**依赖 `sort_order` 作为顺序的唯一真相**，若不同时修复，导入一份含 `entry_date` 的新备份会丢失落位结果，直接违反 FR-008 的「完整还原」。

**理由**：第 3 点不是顺手清理，而是本特征的**前置依赖**——spec 的 US4 场景 3 要求「含时间字段的新备份导入后时间与列表顺序都被完整还原」，而当前导入路径根本不写 `sort_order`，无法还原任何顺序。

**风险与说明**：修复后，导入**旧备份**（无 `entry_date`）仍取 `map['sort_order'] ?? 0`，而旧备份是带 `sort_order` 的（导出即全列），行为不变。旧备份中若 `sort_order` 全为 0（v7 之前导出的极老备份），修复后仍是全 0，与修复前行为一致，不会更差。

**已否决的备选**：只加 `entry_date`、把 `sort_order` 的遗漏留作后续独立修复（会让本特征的 FR-008 在实现当天就是坏的）。

---

## 未决项

**无。** 所有 `NEEDS CLARIFICATION` 已在 spec 的 Clarifications 章节解决，本阶段未产生新的待澄清问题。
