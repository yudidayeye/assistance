<!--
Sync Impact Report
==================
Version change: 1.0.0 → 2.0.0
Bump rationale: MAJOR —— 移除了「开发工作流与质量门禁」中关于需求/计划文档存储位置与命名的
强制约束（原则移除）。本次另含两处事实性更正，按最高变更级别取 MAJOR。

Modified principles:
  - V. 视觉一致性遵循 UI 规范 —— 提交信息语言条款修正。原文第 91 行「commit message MUST
    使用英文」与工作流章节第 109 行「提交信息 MUST 使用中文」自相矛盾，现统一为
    「英文 type/scope 前缀 + 简体中文描述」，与 .codex/skills/commit/SKILL.md 对齐。

Added sections: 无

Removed sections: 无（无整节移除），但移除条款一条：
  - 「需求文档与开发计划 MUST 保存到 .claude/plans/，命名 requirement-<日期>-<标题>.md
    与 plan-<日期>-<标题>.md」（原属「开发工作流与质量门禁」）
    说明：该约定确在活跃使用（.claude/plans/ 已入库 30 个文件），并非形同虚设；但仓库同时
    存在平行的 .codex/plans/，且 CLAUDE.md 精简后不再声明该规则。经维护者决定，计划文档
    位置不再由宪法约束，改由各 agent 运行时指引自行约定。

Corrected clauses:
  - 「技术约束与平台标准」中「flutter_riverpod 负责局部状态」与实现不符：该包在 lib/ 与
    test/ 中零引用，实际状态管理为 ChangeNotifier + 静态单例。现按事实改写。

Follow-up TODOs: 无（RATIFICATION_DATE 已依文件创建日与 v1.0.0 定稿日回填 2026-09-17）
-->
# 理解（my_assistant）宪法

## Core Principles

### I. 本地优先与隐私不可妥协 (NON-NEGOTIABLE)

所有业务数据 MUST 仅保存在设备本地 SQLite 数据库 `toolbox.db` 中。

- MUST NOT 引入云端同步、账号体系或遥测上报；局域网同步 MUST 仅在用户主动进入同步页面并
  发起操作时使用本地网络。
- 密码保险箱 MUST 使用 Argon2id 从主密码派生 256-bit 密钥，并以 AES-256-GCM 加密内容，
  盐与 IV MUST 随机生成。
- 主密码 MUST NOT 以明文或可逆形式落盘；派生密钥 MUST NOT 被持久化。
- 生理期预测 MUST 明确标注为基于历史记录的估算，不构成医疗建议。

理由：应用定位为个人本地工具集，数据泄露面必须收敛到单台设备；加密是保险箱唯一的安全边界，
任何绕过都会直接导致用户凭证暴露。

### II. 模块化插件架构

每个功能模块 MUST 实现 `ToolModule` 接口，并遵循统一的结构与注册流程。

- 模块 MUST 位于 `lib/modules/<module_id>/`，包含 `models/`、`services/`、`pages/`、
  `widgets/` 与实现 `ToolModule` 的 `<module_id>_module.dart`。
- 模块 MUST 在 `lib/main.dart` 的 `ModuleRegistry.registerAll()` 中注册。
- 模块子路由 MUST 通过 `buildSubRoutes()` 自行声明；根路由由 `AppRouter` 动态生成，
  MUST NOT 为单个模块重复添加顶层 `GoRoute`。
- 模块数据表 MUST 使用 `mod_<moduleId>_...` 前缀。
- 核心服务 MUST 采用静态单例模式 `static final instance = ClassName._();`，并保持
  `main()` 中「数据库 → 模块注册 → 设置 → 主题 → 路由」的初始化顺序不变。路由 MUST 最后
  初始化，否则模块路由会静默缺失。

理由：模块是唯一的功能扩展单元；结构、表名与注册点统一后，模块才能被安全地启停、排序与
隔离，路由与首页卡片也才能由注册表推导而非手工维护。

### III. 数据完整性与迁移安全

用户数据 MUST 被视为不可重建的资产，任何 schema 演进都不得造成静默丢失。

- 数据库 schema 变更 MUST 递增 `DatabaseService` 的版本号，并在 `onUpgrade` 中提供迁移；
  MUST NOT 以删表重建的方式处理已有数据。
- 导入 MUST 先执行结构校验与预览，再在事务中原子合并（`INSERT OR REPLACE`）；部分写入
  MUST NOT 被接受为成功。
- 导出/导入的 JSON 结构 MUST 保持向后兼容；破坏性变更 MUST 在发布说明中显式声明。
- 清除模块数据、清除全部业务数据与恢复出厂设置 MUST 是相互独立且需用户确认的显式操作。

理由：本地存储没有服务端备份作为兜底，一次失败的迁移或半途中断的导入即是永久数据损失。

### IV. 按需且贴近改动的测试

测试范围 MUST 与改动范围匹配，测试目录结构 MUST 镜像 `lib/` 结构。

- 修改单个文件时 MUST 运行对应的测试文件；修改整个模块时 MUST 运行该模块的测试目录；
  需要精确筛选时使用 `flutter test <路径> --name "关键字"`。
- 仅当改动 `lib/core/` 或 `lib/shared/` 且影响多个模块时，才 MUST 运行全量 `flutter test`。
- 新增模块逻辑 MUST 补充 unit 或 widget 测试，文件命名为 `*_test.dart` 并置于
  `test/modules/<module_id>/` 下。
- `flutter analyze` MUST 在提交前通过且无新增告警。

理由：全量测试成本高而反馈慢，按改动范围选择靶向测试能在保持反馈速度的同时覆盖真实风险面。

### V. 视觉一致性遵循 UI 规范

任何涉及视觉、配色、间距或圆角改动的工作，MUST 先阅读 `docs/UI.md`。

- 颜色、圆角与间距 MUST 取自 `Theme.of(context).appTheme`（`AppThemeExtension`）暴露的
  设计 token；MUST NOT 在页面中硬编码色值或间距。
- 模块主题色 MUST 通过 `Theme.of(context).moduleTheme` 获取。
- 全局 MUST 使用系统默认字体，MUST NOT 引入任何第三方字体或运行时下载字体。
- 界面文案 MUST 使用简体中文；标识符与日志 MUST 使用英文；commit message MUST 采用英文
  Conventional Commits type/scope 前缀加简体中文祈使句描述，格式以
  `.codex/skills/commit/SKILL.md` 为唯一权威来源。

理由：主题 token 是四套配色与明暗一致性的唯一来源，硬编码会在此后新增或切换主题时产生
无法穷举的视觉缺陷。

## 技术约束与平台标准

- Flutter stable，Dart SDK `>=3.0.0 <4.0.0`；依赖 MUST 通过 `pubspec.yaml` 显式声明并锁定。
- 状态与路由：GoRouter 负责导航；状态管理使用 `ChangeNotifier`（如 `ThemeProvider`、
  `SettingsController`），核心服务使用静态单例。
- 存储：`sqflite` + `sqflite_common_ffi`；`lib/core/storage/` 统一封装建表与迁移。
- 图表 MUST 使用 `fl_chart`；文件选择与打开 MUST 使用 `file_picker` / `path_provider` /
  `open_filex`。
- 主要目标平台为 Android 与 Windows；iOS 当前不支持发布。
- 新增依赖 MUST 说明用途，并评估其对包体积、平台兼容性与隐私面的影响。
- 代码格式化 MUST 使用 `dart format`；lint 规则以 `analysis_options.yaml` 为准且不得放宽。

## 开发工作流与质量门禁

- 每完成一个小需求 MUST 立即 commit；提交信息 MUST 采用英文 type/scope 前缀加简体中文
  祈使句描述，并说明该需求做了什么。
- 纯样式、间距、配色调整 MUST NOT 单独 commit，应随关联需求一并提交。
- 提交前 MUST 执行 `flutter analyze` 与相关测试；提交规范以
  `.codex/skills/commit/SKILL.md` 为唯一权威来源。
- 版本发布 MUST 通过仓库脚本执行：
  `powershell -ExecutionPolicy Bypass -File scripts/release.ps1 <版本号> "<发布说明>"`
  或 `bash scripts/release.sh <版本号> "<发布说明>"`。
- 用户仅要求「发布版本」而未指定版本号时，MUST 只递增修订号（patch），构建号由脚本自动递增；
  仅当用户明确指定目标版本号时，才允许变更主版本号或次版本号。
- MUST NOT 以手动改版本号、打 Tag 或建 Release 的方式替代发布脚本。
- 在 Windows 上通过 PowerShell 读写文件时 MUST 指定 UTF-8：
  读取用 `Get-Content -Raw -Encoding UTF8`，写入用 `Out-File -Encoding UTF8`；
  MUST NOT 使用 `Set-Content` / `Add-Content`。

## Governance

- 本宪法 MUST 优先于其他开发实践；与本宪法冲突的既有约定 MUST 被修订或废止。
- 修订流程：提出修订 → 在本文件中记录 Sync Impact Report → 更新版本号与「Last Amended」→
  由项目维护者批准后生效。修订内容 MUST 与实现变更同批提交。
- 版本策略遵循语义化版本：MAJOR 用于不兼容的治理变更或原则移除/重定义；MINOR 用于新增原则
  或实质性扩展；PATCH 用于措辞澄清与非语义性修正。
- 合规审查：每次代码评审 MUST 校验本宪法各项原则；违反 NON-NEGOTIABLE 原则的变更 MUST 被
  拒绝，任何偏离 MUST 在评审记录中说明理由与回退方案。
- 运行时开发指引以 `CLAUDE.md` 与 `AGENTS.md` 为准；两者与本宪法冲突时以本宪法为准，并
  MUST 同步修正前者。

**Version**: 2.0.0 | **Ratified**: 2026-09-17 | **Last Amended**: 2026-09-20
