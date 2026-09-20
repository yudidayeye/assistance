# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

「理解」（`my_assistant`）— 轻量级个人工具集 Flutter App，包含三个模块：**周期记账**（`period_book`）、**生理期记录**（`period_tracker`）、**密码保险箱**（`vault`）。

所有业务数据仅存储在本地 SQLite（`toolbox.db`）。**不得引入云端同步、账号体系或遥测上报**；局域网同步只在用户主动进入同步页操作时使用本地网络。主要支持 Android 与 Windows，iOS 暂不发布。

## 注意事项

1. 默认使用中文回答；标识符、日志与 commit message 用英文，注释与文档用简体中文
2. 修改前端视觉、调颜色、调间距时 → 必读 [`docs/UI.md`](docs/UI.md)
3. 提交前必须执行 `flutter analyze` 与**相关**测试；提交规范以 [`.codex/skills/commit/SKILL.md`](.codex/skills/commit/SKILL.md) 为唯一权威来源（Conventional Commits，中文描述）
4. 发布版本必须走 `scripts/release.ps1` / `release.sh` 脚本，禁止手动改版本号、打 Tag 或建 Release

## 常用命令

```bash
flutter run -d windows          # 运行（Windows）
flutter run -d android          # 运行（Android 设备/模拟器）
flutter analyze                 # 静态分析（基于 flutter_lints）
dart format lib test            # 格式化

# 测试：按需运行，禁止默认全量
flutter test test/modules/vault                            # 整个模块
flutter test test/modules/vault/vault_service_test.dart    # 单个文件
flutter test test/modules/vault/vault_service_test.dart --name "关键字"  # 精确筛选
flutter test                                               # 仅共享层改动影响多模块时才全量
```

## 架构约束

只列会静默咬人的不变量；模块系统、同步、路由等结构说明见 [`README.md`](README.md) 与 [`AGENTS.md`](AGENTS.md)。

- **新增模块**：实现 `ToolModule` → 在 `main()` 注册 → 在模块内用 `buildSubRoutes()` 声明子路由。顶层 `/<moduleId>` 路由由 `AppRouter._buildModuleRoutes()` 依注册表自动生成，**不要**在 `AppRouter` 里重复添加 `GoRoute`
- **`main.dart` 顺序**：`AppRouter.initRouter()` 必须晚于 `ModuleRegistry.registerAll()`，否则 `_buildModuleRoutes()` 遍历空注册表，模块路由**静默消失**（应用照常启动、不报错、不自愈）
- **保险箱密钥**：主密码与 Argon2id 派生密钥均只驻留内存（`VaultSession._keyCache`），离开模块即清除。**不得**引入"记住主密码"或任何形式的密钥持久化

## 数据库

- 全局设置：`app_settings`（key-value）；模块表统一前缀 `mod_{moduleId}_...`
- 变更 schema 必须递增 `DatabaseService._currentVersion` 并在 `onUpgrade` 中提供迁移；**禁止删表重建**（本地数据无服务端兜底，一次失败迁移即永久丢失）
- `DatabaseService` 另提供 `clearModuleData()` / `clearAllBusinessData()` / `factoryReset()`，三者是相互独立且需用户确认的操作
- `ImportExportService` 负责 JSON 备份与恢复：导入先 preview 校验结构，再在事务中原子合并（`INSERT OR REPLACE`），避免部分写入；导出/导入的 JSON 结构须保持向后兼容

## 发布版本

发布必须通过仓库脚本完成（更新 `pubspec.yaml` → 提交 → 构建 → 打 Tag → 推送 → 建 GitHub Release）：

```bash
powershell -ExecutionPolicy Bypass -File scripts/release.ps1 1.2.7 "本次发布说明"   # Windows
bash scripts/release.sh 1.2.7 "本次发布说明"                                        # 其他环境
```

- 用户仅要求「发布版本」而**未指定版本号时，只递增修订号**（`1.2.6` → `1.2.7`）；构建号由脚本自动递增
- **只有用户明确指定目标版本号时**，才允许变更主版本号或次版本号
- 前置条件：`gh auth login`、工作区无无关改动、Windows 安装包需 Inno Setup 6

## UI 规范与字体

调整任何视觉样式前必读 [`docs/UI.md`](docs/UI.md)。全局统一使用**系统默认字体**，不引入第三方字体、不在运行时下载；弹窗标题等装饰性效果通过字重/字号/字距实现。应用默认语言 `zh_CN`。

## 已知待办

- Android Application ID 仍为 `com.example.my_assistant`，正式发布前需替换
- Android Release 构建目前仍使用 debug signing，仅适合内部测试，正式分发前需配置独立 release keystore
