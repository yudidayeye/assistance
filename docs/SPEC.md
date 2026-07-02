# 技术架构文档 — 工具集 App (Flutter)

---

## 1. 技术选型

| 领域 | 选型 | 理由 |
|------|------|------|
| 框架 | Flutter 3.x | 跨平台，一套代码支持 Android / iOS / Windows |
| 路由 | GoRouter ^14.0.0 | 声明式路由，支持深链接，模块路由可动态注册 |
| 状态管理 | ChangeNotifier（少量使用） | 主题切换、设置变更等全局状态，轻量可控 |
| 本地存储 | sqflite + sqflite_common_ffi | SQLite，每个模块独立表，查询灵活，Windows FFI 兼容 |
| 图表 | fl_chart | 轻量 Flutter 图表库，饼图/折线图 |
| 国际化 | flutter_localizations + intl | 首版仅中文，预留 i18n |
| 主题 | ThemeData + ThemeExtension | 4 套柔和配色，模块级主题色扩展 |
| 字体 | google_fonts | DM Sans（正文/标题）、Playfair Display（弹窗标题） |
| 工具 | path_provider, path, uuid | 文件路径、ID 生成 |

---

## 2. 项目结构

```
lib/
├── main.dart                        # App 入口，按序初始化 Core Services
├── core/
│   ├── module_system/
│   │   ├── tool_module.dart         # ToolModule 抽象接口
│   │   ├── module_registry.dart     # 模块注册中心
│   │   ├── module_context.dart      # 模块上下文（moduleId）
│   │   └── module_summary.dart      # 首页摘要数据结构
│   ├── storage/
│   │   └── database_service.dart    # SQLite 全局服务（含 FFI 初始化、版本迁移）
│   ├── theme/
│   │   ├── app_theme.dart           # 4 套柔和配色 ThemeData 构建
│   │   ├── theme_extension.dart     # AppThemeExtension + ModuleThemeExtension
│   │   └── theme_provider.dart      # 主题切换 + 持久化（ChangeNotifier 单例）
│   ├── routing/
│   │   └── app_router.dart          # GoRouter 路由定义，动态收集模块路由
│   └── settings/
│       ├── settings_service.dart    # 模块启停状态、隐私免责声明持久化
│       ├── settings_controller.dart # 设置状态 ChangeNotifier，供 UI 监听
│       ├── settings_page.dart       # 设置页面 UI
│       └── import_export_service.dart # JSON 格式数据导入导出
├── modules/
│   ├── accounting/
│   │   ├── accounting_module.dart   # ToolModule 实现
│   │   ├── models/
│   │   │   ├── transaction.dart
│   │   │   └── category.dart
│   │   ├── pages/
│   │   │   ├── entry_page.dart      # 模块主页（列表）
│   │   │   ├── add_page.dart        # 快速记账页（支持编辑模式）
│   │   │   ├── stats_page.dart      # 月度统计页
│   │   │   └── category_settings.dart # 分类管理
│   │   └── widgets/
│   │       ├── transaction_item.dart
│   │       ├── category_grid.dart
│   │       ├── amount_input.dart
│   │       └── pie_chart.dart
│   └── period_tracker/
│       ├── period_module.dart       # ToolModule 实现
│       ├── models/
│       │   └── period_record.dart
│       ├── pages/
│       │   ├── calendar_page.dart   # 日历视图主页
│       │   ├── record_page.dart     # 记录经期页
│       │   └── stats_page.dart      # 周期统计页
│       ├── services/
│       │   ├── period_service.dart
│       │   └── prediction_service.dart # 周期预测算法
│       └── widgets/
│           ├── period_calendar.dart
│           └── date_detail_panel.dart
├── pages/
│   ├── main_shell_page.dart         # 底部双 Tab 容器（工具箱 / 我的），IndexedStack
│   ├── home_page.dart               # ⚠️ 旧首页，当前路由未使用，可清理
│   └── profile_page.dart            # "我的"页面内容
└── shared/
    ├── utils/
    │   ├── format_utils.dart         # 金额格式化
    │   └── date_utils.dart           # 日期工具
    └── widgets/
        ├── featured_card.dart        # 首页模块卡片
        ├── month_selector.dart       # 月份选择器
        ├── number_keyboard.dart      # 自定义数字键盘
        ├── toolbox_bottom_nav.dart   # 底部导航栏
        └── empty_state_widget.dart   # 空状态占位
```

---

## 3. ToolModule 抽象接口

```dart
abstract class ToolModule implements ModuleSummaryProvider {
  /// 模块唯一标识，如 'accounting', 'period_tracker'
  String get moduleId;

  /// 显示名称
  String get displayName;

  /// 模块描述（一两句话）
  String get description;

  /// 模块图标（IconData 或 asset path）
  ModuleIcon get icon;

  /// 模块主题色（用于首页卡片背景渐变）
  Color get themeColor;

  /// 模块入口页面 Widget
  Widget buildEntryPage(BuildContext context);

  /// 模块设置页面（可选，返回 null 表示无设置页）
  Widget? buildSettingsPage(BuildContext context);

  /// 模块子路由（模块自行声明，默认返回空列表）
  List<RouteBase> buildSubRoutes() => [];

  /// 模块注册时的初始化逻辑（如建表、迁移）
  Future<void> onRegister(ModuleContext context);

  /// 模块被打开时的逻辑
  Future<void> onOpen(ModuleContext context);

  /// 模块被关闭/切换时的清理逻辑
  Future<void> onClose(ModuleContext context);
}
```

---

## 4. 模块注册机制

```dart
// main.dart
void main() async {
  // 1. 初始化数据库工厂（Windows FFI 兼容）
  await DatabaseService.initializeFactory();

  // 2. 打开数据库
  await DatabaseService.instance.database;

  // 3. 注册并 await 所有模块（确保 onRegister 完成后再继续）
  await ModuleRegistry.instance.registerAll([
    AccountingModule(),
    PeriodTrackerModule(),
  ]);

  // 4. 初始化设置默认值（基于已注册模块动态 seed）
  await SettingsService.instance.seedDefaultsForModules();

  // 5. 加载设置和主题
  await SettingsService.instance.loadSettings();
  await ThemeProvider.instance.loadTheme();

  // 6. 初始化路由（在模块注册完成后调用）
  final router = AppRouter.instance.initRouter();

  runApp(ToolboxApp(router: router));
}

// ModuleRegistry
class ModuleRegistry {
  static final ModuleRegistry instance = ModuleRegistry._();

  Future<void> register(ToolModule module) async {
    _modules[module.moduleId] = module;
    await module.onRegister(ModuleContext(moduleId: module.moduleId));
  }

  Future<void> registerAll(List<ToolModule> modules) async {
    for (final module in modules) {
      await register(module);
    }
  }

  List<ToolModule> get allModules => _modules.values.toList();

  List<ToolModule> getEnabledModules() {
    return _modules.values
        .where((m) => SettingsService.instance.isModuleEnabled(m.moduleId))
        .toList();
  }
}
```

---

## 5. 路由设计

```dart
// 全局路由结构（模块路由从 ModuleRegistry 动态收集）
final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const MainShellPage()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
    // 模块路由 — 动态注册
    GoRoute(
      path: '/accounting',
      builder: (_, __) => const AccountingEntryPage(),
      routes: [
        GoRoute(path: 'add', builder: (_, __) => const AddTransactionPage()),
        GoRoute(path: 'stats', builder: (_, __) => const AccountingStatsPage()),
        GoRoute(path: 'categories', builder: (_, __) => const CategorySettingsPage()),
        GoRoute(path: 'edit/:id', builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AddTransactionPage(editId: id);
        }),
      ],
    ),
    GoRoute(
      path: '/period_tracker',
      builder: (_, __) => const CalendarPage(),
      routes: [
        GoRoute(path: 'record', builder: (_, __) => const PeriodRecordPage()),
        GoRoute(path: 'stats', builder: (_, __) => const PeriodStatsPage()),
      ],
    ),
  ],
);
```

---

## 6. 数据存储

### 6.1 存储引擎

SQLite（通过 `sqflite` + `sqflite_common_ffi`），当前版本 `3`，支持 `onUpgrade` 迁移。

- Windows 平台：`DatabaseService.initializeFactory()` 初始化 FFI
- Android / iOS：原生 SQLite

### 6.2 表命名规则

`mod_{moduleId}_{tableName}`

示例：
- `mod_accounting_transactions`
- `mod_accounting_categories`
- `mod_period_tracker_records`

全局设置使用独立表：
- `app_settings` (key-value)

### 6.3 数据隔离

- 每个模块只能读写自己的表
- 模块间不直接访问彼此数据
- 全局设置使用独立的 `app_settings` 表

### 6.4 记账模块数据表

```sql
-- 交易记录表
CREATE TABLE mod_accounting_transactions (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,          -- 'income' / 'expense'
  category_id TEXT NOT NULL,
  amount REAL NOT NULL,
  note TEXT,
  date TEXT NOT NULL,          -- ISO 8601 日期字符串
  created_at TEXT NOT NULL,
  updated_at TEXT
);

-- 分类表
CREATE TABLE mod_accounting_categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL,          -- 'income' / 'expense'
  icon_code_point INTEGER NOT NULL,  -- IconData codePoint
  icon_font_family TEXT NOT NULL DEFAULT 'MaterialIcons',
  is_custom INTEGER NOT NULL DEFAULT 0,  -- 0=预设, 1=自定义
  sort_order INTEGER NOT NULL
);

-- 索引（v2 迁移添加）
CREATE INDEX idx_txns_type_date ON mod_accounting_transactions(type, date);
CREATE INDEX idx_txns_category_id ON mod_accounting_transactions(category_id);
CREATE INDEX idx_categories_type_sort ON mod_accounting_categories(type, sort_order);
```

### 6.5 生理期模块数据表

```sql
-- 经期记录表
CREATE TABLE mod_period_tracker_records (
  id TEXT PRIMARY KEY,
  start_date TEXT NOT NULL,    -- ISO 8601 日期字符串
  end_date TEXT,               -- 可空，表示进行中
  cycle_length INTEGER,       -- 周期天数，由相邻 startDate 差值计算
  note TEXT,                  -- v3 新增
  created_at TEXT NOT NULL,
  updated_at TEXT
);

-- 索引（v2 迁移添加）
CREATE INDEX idx_period_start_date ON mod_period_tracker_records(start_date);
```

### 6.6 版本迁移

| 版本 | 变更 |
|------|------|
| v1 | 初始表结构（app_settings + 3 张业务表） |
| v2 | 添加性能索引 |
| v3 | 经期记录表添加 `note` 字段 |

---

## 7. 主题配置

### 7.1 配色方案

4 套柔和配色，通过 `AppThemeType` 枚举切换：

| 枚举值 | 中文名 | 旧名称 | 主色 |
|--------|--------|--------|------|
| softNight | 柔夜 | gold | `#7B8BAA` |
| morningMist | 晨雾 | blue | `#8AADB8` |
| leafWhisper | 叶语 | green | `#9CAD8A` |
| flowerMist | 花雾 | pink | `#C9A0AA` |

### 7.2 主题 Token

每套配色语义化为 12 个色彩 token + 圆角/间距设计系统：

```dart
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  // 色彩
  final Color primary / primaryLight / primaryDark;
  final Color earth / earthLight / earthMedium;
  final Color cream / creamDark;
  final Color sage / sageLight;
  final Color rose / roseLight;
  final Gradient gradientPrimary / gradientEarth;

  // 卡片
  final Color cardBackground / cardBorder;
  final List<BoxShadow> cardShadow;

  // 背景
  final Gradient scaffoldGradient;
  final Color surfaceOverlay;

  // 圆角
  final double radiusSm / radiusMd / radiusLg / radiusXl;

  // 间距
  final double spaceXs / spaceSm / spaceMd / spaceLg / spaceXl;
}
```

通过扩展方法获取：
- `Theme.of(context).appTheme` → `AppThemeExtension`
- `Theme.of(context).moduleTheme` → `ModuleThemeExtension(moduleColor)`

### 7.3 模块主题色

| 模块 | themeColor |
|------|-----------|
| 记账 | `#9CAD8A`（叶语绿） |
| 生理期记录 | `#D4879A`（柔粉） |

---

## 8. 首页摘要接口

各模块通过 `ModuleSummaryProvider` 接口向首页卡片提供实时摘要：

```dart
abstract class ModuleSummaryProvider {
  Future<ModuleSummary> getSummary();
}

class ModuleSummary {
  final String line1;  // 摘要第一行
  final String? line2; // 摘要第二行（可选）
}
```

**记账模块摘要示例：** `line1: "本月支出 ¥1,280"`
**生理期模块摘要示例：** `line1: "下次预测 7月9日"`, `line2: "当前周期 第18天"`

---

## 9. 周期预测算法实现

```dart
class PredictionService {
  /// 基于加权平均法预测下次经期
  PredictionResult predict(List<PeriodRecord> records) {
    if (records.length < 2) return null; // 数据不足，不预测

    // 取最近 6 个有效周期长度
    final cycleLengths = records
        .where((r) => r.cycleLength != null)
        .map((r) => r.cycleLength!)
        .toList()
        .reversed
        .take(6)
        .toList();

    if (cycleLengths.isEmpty) return null;

    // 加权计算：最近 1 个权重 3，最近 2 个权重 2，最近 3-6 个权重 1
    final weights = [3, 2, 1, 1, 1, 1];
    double sum = 0;
    double weightSum = 0;

    for (int i = 0; i < cycleLengths.length; i++) {
      sum += cycleLengths[i] * weights[i];
      weightSum += weights[i];
    }

    final avgCycle = (sum / weightSum).round();
    final lastRecord = records.last;
    final nextStartDate = lastRecord.startDate.add(Duration(days: avgCycle));

    return PredictionResult(
      nextStartDate: nextStartDate,
      avgCycle: avgCycle,
      currentDayInCycle: _calculateCurrentDay(lastRecord.startDate),
    );
  }
}
```

---

## 10. 关键依赖版本（pubspec.yaml 参考）

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  go_router: ^14.0.0
  flutter_riverpod: ^2.5.0  # 已引入但未深度使用
  sqflite: ^2.3.0
  sqflite_common_ffi: ^2.4.1
  fl_chart: ^0.69.0
  intl: ^0.20.2
  uuid: ^4.4.0
  path_provider: ^2.1.0
  path: ^1.9.0
  google_fonts: ^6.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

---

## 11. 注意事项

- `home_page.dart` 是旧版首页，当前路由使用 `main_shell_page.dart`，旧文件可考虑清理
- `module_card.dart` 已移除，被 `featured_card.dart` 替代
- Windows 桌面开发需要 Visual Studio 2022 的 "Desktop development with C++" 工作负载
- 数据库初始化在 `main()` 中 `initializeFactory()` 处理 Windows FFI 兼容
- 应用默认语言为中文 (`zh_CN`)
- `flutter_riverpod` 已引入但当前未深度使用，全局状态主要依赖 `ChangeNotifier` 单例
