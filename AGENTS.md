# 仓库指南(Repository Guidelines)

## 项目结构与模块组织

本项目是 Flutter 应用(`my_assistant`)——轻量级个人工具集(周期记账、生理期记录、密码保险箱),数据仅存本地 SQLite,禁止引入网络同步或遥测。

- `lib/main.dart` —— 入口,按固定顺序初始化数据库、模块、设置、主题、路由。
- `lib/core/` —— 模块系统(`module_system/`)、GoRouter 路由(`routing/`)、设置、SQLite 存储、主题。
- `lib/modules/` —— 插件式模块(如 `period_book/`、`period_tracker/`、`vault/`),各含 `models/`、`services/`、`pages/`、`widgets/` 和实现 `ToolModule` 的 `*_module.dart`。新增模块须在 `main()` 中注册,并在模块内用 `buildSubRoutes()` 声明子路由;顶层 `/<moduleId>` 路由由 `AppRouter` 依注册表自动生成,无需手工添加。
- `lib/pages/`、`lib/shared/` —— 外壳页面与可复用组件。
- `test/` —— 目录结构镜像 `lib/`;
- `docs/UI.md` —— 改视觉样式前必读。

## 构建、测试与开发命令

- `flutter run [-d android|ios]` —— 在设备/模拟器上运行。
- `flutter analyze` —— 静态分析(基于 `flutter_lints`)。
- `flutter test <路径>` —— 按需运行指定测试(见测试指南)。
- `flutter build appbundle|apk|ios` —— 构建发布版本(暂不支持iOS)。

## 发布版本规范

- 发布版本必须通过仓库脚本执行：Windows 使用 `powershell -ExecutionPolicy Bypass -File scripts/release.ps1 <版本号> "<发布说明>"`，其他环境使用 `bash scripts/release.sh <版本号> "<发布说明>"`；
- 用户仅要求“发布版本”但未指定版本号时，默认只递增修订号，例如 `1.2.3` → `1.2.4`；构建号由发布脚本自动递增。
- 只有用户明确指定目标版本号时，才允许变更主版本号或次版本号，并严格使用用户指定的版本号执行发布脚本。

## 编码风格与命名约定

- Dart SDK `>=3.0.0 <4.0.0`;格式化用 `dart format`,lint 见 `analysis_options.yaml`。
- 命名:类 `PascalCase`,成员 `camelCase`,文件 `snake_case`。
- 核心服务用静态单例:`static final instance = ClassName._();`。
- 模块数据表统一前缀 `mod_{moduleId}_...`。
- 标识符与日志用英文,注释与文档用简体中文。

## 测试指南

- 框架 `flutter_test`;文件命名 `*_test.dart`,路径镜像源码。
- **按需运行,禁止默认全量**:改单文件 → 跑对应测试文件;改整个模块 → 跑该模块测试目录;精确过滤用 `--name "关键字"`。
- **例外**:改动 `lib/core/`、`lib/shared/` 且影响多模块时,才全量 `flutter test`。
- 无覆盖率门槛;新模块逻辑需补 widget/unit 测试。

## 提交规范

- **提交前必须执行 [`commit/SKILL.md`](./.codex/skills/commit/SKILL.md)**,它是提交规范的唯一权威来源。
- 每完成一个小需求提交一次;纯样式/间距调整不单独提交。
- 提交前先跑 `flutter analyze` 和相关测试。

## Agent 专属说明

- 默认用简体中文回复与写文档。
- PowerShell 读写文件必须 UTF-8:读取 `Get-Content -Raw -Encoding UTF8`,写入 `Out-File -Encoding UTF8`;禁用 `Set-Content` / `Add-Content`。
