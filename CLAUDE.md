# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**my\_assistant** — 轻量级个人工具集 App（记账 + 生理期记录）。Flutter 3.x，Dart ≥3.0.0，目标平台 Android + Windows。所有 UI 文本为中文，locale 硬编码 `zh_CN`。

## Commands

```bash
# 安装/刷新依赖
dart pub get

# 运行
flutter run                    # 默认设备
flutter run -d windows         # Windows 桌面
flutter run -d android         # Android

# 构建
flutter build apk              # Android APK
flutter build windows          # Windows 桌面

# 静态分析（lint）
flutter analyze

# 测试
flutter test                           # 全部
flutter test test/widget_test.dart     # 单个文件
```

## Architecture

### Module System（插件架构）

每个功能模块实现 `ToolModule` 抽象接口（`lib/core/module_system/tool_module.dart`），提供 `moduleId`、`displayName`、`buildEntryPage`、`onRegister` 等。新模块只需：

1. 在 `lib/modules/` 下创建目录，实现 `ToolModule`
2. 在 `lib/main.dart` 中注册一行：`ModuleRegistry.instance.register(XxxModule())`

### Data Isolation（数据隔离）

每个模块的 SQLite 表使用命名前缀 `mod_{moduleId}_`（如 `mod_accounting_transactions`）。模块间不直接访问彼此数据。全局设置使用独立的 `app_settings` 表。

### Key Directories

- **`lib/core/`** — 框架基础设施：模块系统、路由（GoRouter）、SQLite 存储、主题、设置
- **`lib/modules/accounting/`** — 记账模块（models / pages / services / widgets）
- **`lib/modules/period_tracker/`** — 生理期模块（models / pages / services / widgets）
- **`lib/shared/`** — 跨模块共享的 widgets 和 utils
- **`specs/`** — PRD（`PRD.md`）和技术架构文档（`SPEC.md`），中文

### State Management

使用 `setState` + 单例 Services（`DatabaseService`、`TransactionService`、`CategoryService`、`PeriodService`、`PredictionService`、`SettingsService`、`ThemeProvider`）。`flutter_riverpod` 已声明为依赖但**未使用**。

### Routing

`GoRouter` 声明式路由（`lib/core/routing/app_router.dart`）。模块路由通过注册中心动态构建，但子路由目前使用 `switch` 语句分发。

### Theme System

4 套完整浅色主题（gold / blue / green / pink），每套 12 个语义色彩 token，通过 `ThemeExtension`（`AppThemeExtension` + `ModuleThemeExtension`）实现，持久化到 SQLite。

### Database

SQLite via `sqflite`（移动端）+ `sqflite_common_ffi`（桌面端 FFI）。初始化顺序见 `main.dart`：`initializeFactory()` → `database` → `loadSettings()` → `initializeDefaults()` → `loadTheme()`。数据库版本 1，无迁移策略。

### Period Prediction Algorithm

加权平均周期预测（`lib/modules/period_tracker/services/prediction_service.dart`）：取最近 6 个周期长度，权重 `[3,2,1,1,1,1]`；不足 3 条记录时默认 28 天。排卵日 = 下次经期 - 14 天。易孕期 = 排卵日前 5 天 ~ 后 1 天。
