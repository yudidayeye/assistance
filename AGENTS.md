# 仓库指南(Repository Guidelines)

## 项目结构与模块组织

本项目是一个 Flutter 应用(`my_assistant`)—— 轻量级个人工具集(记账 + 生理期记录),所有数据仅存储在本地 SQLite。

- `lib/main.dart` —— 应用入口,按固定顺序初始化数据库、模块、设置、主题和路由。
- `lib/core/` —— 模块系统(`module_system/`)、GoRouter 路由(`routing/`)、设置、SQLite 存储和主题。
- `lib/modules/` —— 插件式模块(如 `accounting/`、`period_tracker/`),每个模块包含 `models/`、`services/`、`pages/`、`widgets/`,以及一个实现 `ToolModule` 接口的 `*_module.dart` 描述文件。
- `lib/pages/`、`lib/shared/` —— 外壳页面与可复用的工具类/组件。
- `test/` —— 目录结构镜像 `lib/` 布局(`core/`、`modules/`、`shared/`)。
- `docs/UI.md` —— 修改视觉样式前必读;需求文档与开发计划保存在 `.Codex/plans/`。

## 构建、测试与开发命令

- `flutter run` —— 在已连接的设备/模拟器上运行(`-d android` / `-d ios` 指定平台)。
- `flutter test <路径>` —— 运行指定测试文件或目录(推荐,见测试指南);不带参数的全量 `flutter test` 仅在大范围改动时使用。
- `flutter analyze` —— 静态分析(基于 flutter_lints)。
- `flutter build appbundle` / `flutter build apk` / `flutter build ios` —— 构建发布版本(iOS 需要 macOS + Xcode)。

## 编码风格与命名约定

- Dart SDK 版本 `>=3.0.0 <4.0.0`;lint 规则使用 `flutter_lints`(见 `analysis_options.yaml`);格式化使用 `dart format`。
- 类名用 `PascalCase`,成员用 `camelCase`,文件名用 `snake_case`。
- 核心服务统一为静态单例:`static final instance = ClassName._();`(如 `DatabaseService.instance`)。
- 模块数据表统一前缀 `mod_{moduleId}_...`;新增模块需在 `main()` 中注册,并在 `AppRouter` 中添加子路由。
- 标识符与日志使用英文;注释与文档使用简体中文。

## 测试指南

- 测试框架:`flutter_test`。测试文件命名为 `*_test.dart`,路径镜像源码结构(如 `test/modules/accounting/...`)。
- **按需运行,禁止默认全量**:每次只运行与本次改动相关的测试,根据改动范围选择最小执行单元:
  - 改动单个文件 → 运行对应测试文件:`flutter test test/modules/accounting/xxx_test.dart`
  - 改动整个模块 → 运行该模块测试目录:`flutter test test/modules/accounting/`
  - 精确过滤用例 → `flutter test --name "用例关键字"`
- **例外**:仅当改动 `lib/core/`、`lib/shared/` 等共享层且影响多个模块时,才执行全量 `flutter test` 回归。
- 无强制覆盖率门槛;为新的模块逻辑补充 widget/unit 测试。

## 提交与 Pull Request 规范

- **每次代码提交必须执行 [`commit`](./.codex/skills/commit/SKILL.md) skill**,该 skill 是提交规范的唯一权威来源,包含完整的执行步骤、type 定义与示例。
- 提交信息遵循 [Conventional Commits(约定式提交)](https://www.conventionalcommits.org/zh-hans/):`<type>(<可选 scope>): <简体中文描述>`(详见 skill)。
- 每完成一个小需求提交一次;纯样式/间距调整不单独提交。
- PR 需包含简要描述、关联 issue;涉及 UI 变更需附截图;提交前先运行 `flutter analyze` 及与改动相关的测试(不要全量运行)。

## Agent 专属说明

- 默认使用简体中文回复与撰写文档。
- **提交代码时必须加载并执行 `.codex/skills/commit/SKILL.md`**,不得绕过。
- **运行测试时遵循"按需运行"原则**,只执行与改动相关的测试文件或目录。
- 修改颜色、间距等视觉样式前,必读 `docs/UI.md`。
- PowerShell 读写文件必须使用 UTF-8:读取用 `Get-Content -Raw -Encoding UTF8`,写入用 `Out-File -Encoding UTF8`;禁用 `Set-Content` / `Add-Content`。
- 用户数据仅保存在本地 SQLite,禁止引入网络同步或遥测上报。
