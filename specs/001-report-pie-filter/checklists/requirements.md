# Specification Quality Checklist: 历史记录报表饼图点击联动周期卡片筛选

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-09-20
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- Items marked incomplete require spec updates before `/speckit-clarify` or `/speckit-plan`
- 累计澄清 21 项。`/speckit-specify` 阶段 3 项：
  - 明细粒度 → **逐条支出记录**（分类小计 + 逐条描述与金额），而非仅金额合计
  - 卡片主金额 → **保持周期总支出不变**，仅为分类金额提供总量参照
  - 条目过多时 → **限 3 条 + 「查看全部 N 条」**入口
- `/speckit-clarify` 第 1 轮 5 项：
  - 筛选状态呈现与取消 → 扇区高亮 + **吸顶筛选标签**（含关闭控件），解决滚离饼图后无处取消的问题
  - 「杂项」同名冲突 → 经查证**不存在**：饼图渲染时已排除结余（此问题前提有误，已更正 spec 中的结余描述）
  - 「杂项」无逐条记录 → 可筛选，**卡片显示小计 + 一行说明**，不渲染明细条目、不显示「查看全部」
  - 视图间切换 → **清空筛选**，不跨视图传递
  - 图例行可点性 → **图例行与扇区等价**，均可筛选并取消
- `/speckit-clarify` 第 2 轮 5 项（每条均以读码核实为前置，作废了 2 个前提有误的待问项）：
  - 阶段筛选 → 与年/月同属"范围变更"，**保留筛选、按新阶段重算**；无金额则自动取消
  - 筛选视觉反馈 → 扇区与图例行**同步高亮**，其余不淡化
  - 大额卡片当前已全量逐条 → 仍**统一限 3 条**（已确认取舍：该视图会出现"筛后比筛前更短"）
  - 日常视图缺「其他」扇区 → **补齐**，使饼图分类与卡片第二行完全对齐
  - 其他消费归类 → **一律归入「其他」**，不按子类拆分，三个视图口径一致
- `/speckit-clarify` 第 3 轮 5 项（同样逐条读码核实；其中 3 项推翻了既定措辞或既有需求）：
  - 卡片汇总行 → **保留在筛选结果上方**，第一行与第二行数值口径均不变（推翻"明细区域被整体替换"的原措辞）
  - 无分类归属的「大额追加」组 → 筛选时**跟随明细区一起消失**（已确认取舍：净额失去可见出处）
  - 「查看全部」→ **既不跳页也不弹窗，原地展开卡片**（推翻 FR-012 原有的跳转落点定义）
  - 展开粒度 → **自由多张**，各卡片互不影响
  - 明细行标签 → **不显示任何分类或子类标签**，避免子类名与同名普通分类撞车
- `/speckit-clarify` 第 4 轮 3 项（前两问各带一处此前从未被触及的实证发现；第 3 问在 `/speckit-plan` 之后补答）：
  - 「阶段」选中时的统计口径 → **卡片跟随阶段**：筛选态下卡片小计与明细只统计所选阶段的支出，与饼图口径一致，
    使 SC-003 在选阶段时依然成立。据此新增 FR-016a。**发现**：日常视图的饼图选中阶段后本就只统计该阶段
    （`report_card.dart:673`），而卡片列表素来不看阶段（`agg.dart:423-434`），二者口径原本对不上
  - 合计视图「前 3 条」的排序 → **日常在前、大额在后**，两组各自沿用内部既有顺序，跨组不混排。
    此答案同时消解了 Assumptions「沿用既有展示顺序」与 FR-009「分两组」之间的潜在冲突
  - 「支出趋势」视图下的取消入口 → **吸顶筛选标签在两个报表视图下都常驻**。**发现**：该视图没有饼图、
    没有图例、也没有可点空白，FR-003/FR-005 定义的三条取消路径全部不存在，标签是唯一入口；
    不渲染即形成"筛选取消不掉"的死状态
- **本次引入三处既有图表行为变更**（不是新增能力，是既有显示变化，须在发布说明中声明）：
  1. 日常饼图由"部分支出类型"改为覆盖该周期全部支出类型，各扇区占比随之整体变化
  2. 其他消费不再按其子类并入同名普通分类，而整体归入「其他」
  3. 报表标题旁的总金额取自饼图各扇区之和，日常视图这个数字会随「其他」扇区补入而变大
     （附带效果：它从此与日常卡片第一行的周期总支出对齐，此前二者不相等）
- **一处已知的需求缺口**（不是待办，是刻意保留）：
  「杂项」为负的周期不进饼图，而卡片总额按实际值计算，因此这类周期上 SC-003 无法严格成立。
  已记入 Assumptions——饼图本身无法表达负扇区，本次不处理。
- 供 `/speckit-plan` 注意的六处：
  1. 「杂项」的卡片呈现需要一条区别于其他分类的展示分支（有金额、无明细），
     **日常与合计两个视图都有「杂项」扇区**，大额视图没有
  2. 汇总口径需按 FR-001a / FR-001b 改造——「是否属于其他消费」的判定必须发生在分类归一化**之前**，
     否则带有子类前缀的消费会被剥掉前缀而混入普通分类（这是当前合计饼图的实际行为）
  3. 「查看全部 / 收起」是本次唯一新增的交互控件：需要按卡片记录的"已展开集合"（FR-012 要求可同时展开多张），
     并且必须阻止点击冒泡到卡片主体的跳转
  4. 三个视图的明细行都**不带分类标签**（FR-023），不要直接复用带分类标签的既有明细组件
  5. 排版需容纳"汇总行 + 分类小计 + 至多 3 条明细"三段式，且汇总行在筛选前后不发生位移
  6. 统计口径有三处容易做漏的分支：
     ①**阶段**——日常视图选中阶段时卡片要跟着收敛（FR-016a），而大额与合计视图的饼图不响应阶段、卡片也不收敛；
     ②**「其他」的归类必须早于归一化**——`mapCategoryForDisplay` 会把 `other:购物` 剥前缀成 `购物`；
     ③**合计视图「前 3 条」先日常后大额**，跨组不混排
