# 我的工具箱 (My Toolbox)

## 项目概述
轻量级个人工具集 Flutter App — 记账模块 + 生理期记录模块，所有数据仅存储在本地 SQLite。

## 注意事项
1. 默认使用中文回答
2. 涉及到文件查找使用codegraph
3. 完成计划时完成一个小功能自动git commit，git push

## 技术栈
- **Flutter / Dart** (SDK >=3.0.0 <4.0.0)
- **go_router** ^14.0.0 — 路由管理
- **sqflite** + **sqflite_common_ffi** — 本地 SQLite 数据库（Windows/Android/iOS）
- **fl_chart** — 图表（饼图、统计图）
- **google_fonts** — 字体：DM Sans（正文）、Roboto Slab（标题）、Playfair Display（"我的"页）
- **flutter_riverpod** — 已引入但当前未深度使用
- **uuid** — 记录 ID 生成
- **intl** — 国际化

## 常用命令

```bash
# 运行项目（Windows 桌面）
flutter run -d windows

# 运行测试
flutter test

# 代码静态分析
flutter analyze

# 构建 Windows 发布版
flutter build windows
```

## 架构概览

### 模块系统（插件式架构）

核心抽象在 `lib/core/module_system/`：
- **`ToolModule`** — 模块抽象接口。每个模块实现：`moduleId`、`displayName`、`icon`、`themeColor`、`buildEntryPage()`、`onRegister()`、`onOpen()`、`onClose()`、`getSummary()`
- **`ModuleRegistry`** — 单例注册中心。在 `main()` 中注册所有模块，管理模块生命周期
- **`ModuleSummary`** — 首页卡片显示的摘要信息（`line1`、`line2`）
- **`ModuleContext`** — 模块上下文（当前仅含 `moduleId`）

所有已注册模块通过 `ModuleRegistry.instance.allModules` 获取，路由和首页卡片均由此动态生成。添加新模块只需：实现 `ToolModule` → 在 `main()` 中注册 → 在 `AppRouter._getModuleSubRoutes()` 中添加子路由。

### 目录结构

```
lib/
├── main.dart                    # 入口：初始化 DB/Settings/Theme → 注册模块 → 启动路由
├── core/
│   ├── module_system/           # 模块抽象层（接口、注册中心、上下文、摘要）
│   ├── routing/
│   │   └── app_router.dart      # GoRouter 路由定义，动态收集模块路由
│   ├── settings/
│   │   ├── settings_service.dart # 模块启停状态、隐私免责声明持久化
│   │   └── settings_page.dart    # 设置页面 UI
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
│   ├── home_page.dart            # ⚠️ 旧首页（含底部导航），当前路由未使用
│   └── profile_page.dart         # "我的"页面内容（ProfilePageContent）
└── shared/
    ├── utils/                    # AppDateUtils, FormatUtils
    └── widgets/                  # FeaturedCard, MonthSelector, NumberKeyboard, ToolboxBottomNav
```

### 数据库表命名约定

- 全局设置：`app_settings` (key-value)
- 模块表前缀：`mod_{moduleId}_...`
  - `mod_accounting_transactions`
  - `mod_accounting_categories`
  - `mod_period_tracker_records`

### 导航路由

| 路径 | 页面 |
|------|------|
| `/` | MainShellPage（底部双 Tab） |
| `/settings` | SettingsPage |
| `/accounting` | AccountingEntryPage |
| `/accounting/add` | AddTransactionPage |
| `/accounting/edit/:id` | AddTransactionPage（编辑模式） |
| `/accounting/stats` | AccountingStatsPage |
| `/accounting/categories` | CategorySettingsPage |
| `/period_tracker` | CalendarPage |
| `/period_tracker/record` | PeriodRecordPage |
| `/period_tracker/stats` | PeriodStatsPage |

### 主题系统

4 套配色通过 `AppThemeType` 枚举切换：gold（默认）、blue、green、pink。每套颜色语义化为 12 个 token：
- `primary` / `primaryLight` / `primaryDark` — 主色调
- `earth` / `earthLight` / `earthMedium` — 文字色系
- `cream` / `creamDark` — 背景色系
- `sage` / `sageLight` — 辅助色（绿色调）
- `rose` / `roseLight` — 强调色（红色调）

通过 `Theme.of(context).appTheme` 获取 `AppThemeExtension`，通过 `Theme.of(context).moduleTheme` 获取模块主题色。

### 服务单例模式

所有核心服务使用 `static final instance = ClassName._();` 单例模式：
- `DatabaseService.instance`
- `SettingsService.instance`
- `ThemeProvider.instance`
- `ModuleRegistry.instance`
- `TransactionService.instance` / `CategoryService.instance`
- `PeriodService.instance` / `PredictionService.instance`

### 注意事项

- `home_page.dart` 是旧版首页，当前路由使用 `main_shell_page.dart`，旧文件可考虑清理
- `module_card.dart` 标记为 DEPRECATED，已被 `featured_card.dart` 替代
- Windows 桌面开发需要 Visual Studio 2022 的 "Desktop development with C++" 工作负载
- 数据库初始化在 `main()` 中 `initializeFactory()` 处理 Windows FFI 兼容
- 应用默认语言为中文 (`zh_CN`)
