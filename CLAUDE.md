# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

轻量级个人工具集 Flutter App — 记账模块 + 生理期记录模块，所有数据仅存储在本地 SQLite。

## 注意事项

1. 默认使用中文回答
2. 完成计划时，每完成一个小需求自动 git commit，提交信息用中文写。（注意:样式修改不主动git commit，只有新需求完成时才提交。）
3. 修改前端视觉、调颜色、调间距时 → 必读 `./docs/UI.md`
4. 生成的需求文档和开发计划默认保存到 `./.claude/plans` 目录下，命名规则分别为`requirement-<日期>-<标题>.md`和`plan-<日期>-<标题>.md`

## 常用命令

```bash
# 运行项目（默认连接已启用的移动设备/模拟器）
flutter run

# 指定 Android 设备运行
flutter run -d android

# 指定 iOS 设备运行（需要 macOS + Xcode）
flutter run -d ios

# 运行测试
flutter test

# 运行单个测试文件
flutter test test/path/to/test_file.dart

# 代码静态分析
flutter analyze

# 构建 Android 发布版（AAB）
flutter build appbundle

# 构建 Android APK
flutter build apk

# 构建 iOS 发布版（需要 macOS + Xcode）
flutter build ios
```

## 架构概览

### 模块系统（插件式架构）

核心抽象在 `lib/core/module_system/`：

- **`ToolModule`** — 模块抽象接口。每个模块实现：`moduleId`、`displayName`、`icon`、`themeColor`、`buildEntryPage()`、`onRegister()`、`onOpen()`、`onClose()`、`getSummary()`
- **`ModuleRegistry`** — 单例注册中心。在 `main()` 中注册所有模块，管理模块生命周期
- **`ModuleSummary`** — 首页卡片显示的摘要信息（`line1`、`line2`）
- **`ModuleContext`** — 模块上下文（当前仅含 `moduleId`）

所有已注册模块通过 `ModuleRegistry.instance.allModules` 获取，路由和首页卡片均由此动态生成。添加新模块只需：实现 `ToolModule` → 在 `main()` 中注册 → 在 `AppRouter._getModuleSubRoutes()` 中添加子路由。

### 初始化顺序（main.dart）

```
1. DatabaseService.initializeFactory()  — 平台 FFI 初始化（移动端无需额外处理，Windows 需 C++ 工作负载）
2. DatabaseService.instance.database    — 打开/创建 SQLite
3. ModuleRegistry.registerAll([...])    — 注册模块并 await onRegister
4. SettingsService.seedDefaultsForModules() — 首次启动写入模块启用状态
5. SettingsService.loadSettings()       — 加载设置到内存缓存
6. ThemeProvider.loadTheme()            — 加载主题偏好
7. AppRouter.initRouter()               — 此时模块路由已就绪，构建 GoRouter
```

### 主题系统

4 套配色通过 `AppThemeType` 枚举切换，中文名称与 legacy 映射：

| 枚举值      | 中文名 | 旧名称 |
| ----------- | ------ | ------ |
| softNight   | 柔夜   | gold   |
| morningMist | 晨雾   | blue   |
| leafWhisper | 叶语   | green  |
| flowerMist  | 花雾   | pink   |

每套颜色语义化为 12 个 token + 圆角/间距设计系统：

- `primary` / `primaryLight` / `primaryDark` — 主色调
- `earth` / `earthLight` / `earthMedium` — 文字色系
- `cream` / `creamDark` — 背景色系
- `sage` / `sageLight` — 辅助色（绿色调）
- `rose` / `roseLight` — 强调色（红色调）

通过 `Theme.of(context).appTheme` 获取 `AppThemeExtension`（含色彩、卡片、圆角、间距 token），通过 `Theme.of(context).moduleTheme` 获取模块主题色。

**UI 设计原则（详见 `docs/UI.md`）：**

- 安静科技感 + 温和健康陪伴
- 低对比、高柔和度、轻渐变过渡
- 大圆角（16-28px）、极轻阴影、无硬边框
- 信息密度低、单焦点中心结构
- 卡片风格为"状态容器"而非"按钮化"

### 服务单例模式

所有核心服务使用 `static final instance = ClassName._();` 单例模式：

- `DatabaseService.instance`
- `SettingsService.instance` / `SettingsController.instance`
- `ThemeProvider.instance`
- `ModuleRegistry.instance`
- `TransactionService.instance` / `CategoryService.instance`
- `PeriodService.instance` / `PredictionService.instance`
- `ImportExportService.instance`

### 数据库

- 全局设置：`app_settings` (key-value)
- 模块表前缀：`mod_{moduleId}_...`
  - `mod_accounting_transactions`
  - `mod_accounting_categories`
  - `mod_period_tracker_records`
- 当前版本：`3`，支持 `onUpgrade` 迁移（v2 加索引，v3 加 note 字段）
- `DatabaseService` 提供 CRUD helpers + `clearModuleData()` / `clearAllBusinessData()` / `factoryReset()`

### 数据导入导出

`ImportExportService` 负责 JSON 格式的备份与恢复：

- 导出：`app_settings` + 生理期记录，保存到下载目录
- 导入：先 preview 校验结构，再在事务中原子合并（INSERT OR REPLACE）
- 导入后自动重算周期长度

### 导航路由

| 路径                     | 页面                           |
| ------------------------ | ------------------------------ |
| `/`                      | MainShellPage（底部双 Tab）    |
| `/settings`              | SettingsPage                   |
| `/accounting`            | AccountingEntryPage            |
| `/accounting/add`        | AddTransactionPage             |
| `/accounting/edit/:id`   | AddTransactionPage（编辑模式） |
| `/accounting/stats`      | AccountingStatsPage            |
| `/accounting/categories` | CategorySettingsPage           |
| `/period_tracker`        | CalendarPage                   |
| `/period_tracker/record` | PeriodRecordPage               |
| `/period_tracker/stats`  | PeriodStatsPage                |

### 字体系统

- **DM Sans** — 正文、标题（通过 `GoogleFonts.dmSans()`）
- **Roboto Slab** — 项目中未直接使用（历史遗留）
- **Playfair Display** — 弹窗标题（如设置页确认框）

### 目录结构

```
lib/
├── main.dart                    # 入口：按序初始化 DB/模块/设置/主题/路由
├── core/
│   ├── module_system/           # 模块抽象层（接口、注册中心、上下文、摘要）
│   ├── routing/
│   │   └── app_router.dart      # GoRouter 路由定义，动态收集模块路由
│   ├── settings/
│   │   ├── settings_service.dart # 模块启停状态、隐私免责声明持久化
│   │   ├── settings_page.dart    # 设置页面 UI
│   │   └── import_export_service.dart # JSON 导入导出
│   ├── storage/
│   │   └── database_service.dart # SQLite 封装（自动处理 Windows FFI）
│   └── theme/
│       ├── app_theme.dart        # 4 套主题色构建 ThemeData
│       ├── theme_extension.dart  # AppThemeExtension + ModuleThemeExtension
│       └── theme_provider.dart   # 主题切换 + 持久化（ChangeNotifier 单例）
├── modules/
│   ├── accounting/               # 记账模块
│   │   ├── accounting_module.dart
│   │   ├── models/               # Transaction, Category
│   │   ├── services/             # TransactionService, CategoryService, StatsService
│   │   ├── pages/                # entry_page, add_page, stats_page, category_settings
│   │   └── widgets/              # amount_input, category_grid, pie_chart, transaction_item
│   └── period_tracker/           # 生理期模块
│       ├── period_module.dart
│       ├── models/               # PeriodRecord
│       ├── services/             # PeriodService, PredictionService
│       ├── pages/                # calendar_page, record_page, stats_page
│       └── widgets/              # period_calendar
├── pages/
│   ├── main_shell_page.dart      # 底部双 Tab（工具箱 / 我的），IndexedStack
│   └── profile_page.dart         # "我的"页面内容（ProfilePageContent）
└── shared/
    ├── utils/                    # AppDateUtils, FormatUtils
    └── widgets/                  # FeaturedCard, MonthSelector, NumberKeyboard, ToolboxBottomNav
```

### 注意事项

- 项目主要面向移动端（Android / iOS），开发时优先在真机或模拟器上测试
- 如需在 Windows 桌面运行，需安装 Visual Studio 2022 的 "Desktop development with C++" 工作负载，`main()` 中 `initializeFactory()` 会处理 Windows FFI 兼容
- 应用默认语言为中文 (`zh_CN`)
