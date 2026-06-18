# 技术架构文档 — 工具集 App (Flutter)

---

## 1. 技术选型

| 领域 | 选型 | 理由 |
|------|------|------|
| 框架 | Flutter 3.x | 跨平台，一套代码支持 Android / iOS |
| 路由 | GoRouter | 声明式路由，支持深链接，模块路由可动态注册 |
| 状态管理 | Riverpod | 职责清晰，模块间无耦合，测试友好 |
| 本地存储 | sqflite | SQLite，每个模块独立表，查询灵活 |
| 图表 | fl_chart | 轻量 Flutter 图表库，饼图/折线图 |
| 国际化 | flutter_localizations + intl | 预留 i18n，首版仅中文 |
| 主题 | ThemeData + ThemeExtension | 仅浅色模式，模块级主题色扩展 |

---

## 2. 项目结构

```
lib/
├── main.dart                  # App入口，初始化CoreServices
├── core/
│   ├── module_system/
│   │   ├── tool_module.dart       # ToolModule 抽象接口
│   │   ├── module_registry.dart   # 模块注册中心
│   │   ├── module_context.dart    # 模块上下文（存储、路由等）
│   │   └── module_summary.dart    # 首页摘要数据结构
│   ├── storage/
│   │   └── database_service.dart  # SQLite 全局服务
│   ├── theme/
│   │   └── app_theme.dart         # 浅色主题定义
│   │   └── theme_extension.dart   # 模块主题色扩展
│   ├── routing/
│   │   ├── app_router.dart        # 全局路由（GoRouter）
│   │   └── module_route.dart      # 模块路由注册
│   └── settings/
│       ├── settings_service.dart
│       └── settings_page.dart
├── modules/
│   ├── accounting/
│   │   ├── accounting_module.dart      # ToolModule 实现
│   │   ├── models/
│   │   │   ├── transaction.dart
│   │   │   ├── category.dart
│   │   ├── pages/
│   │   │   ├── entry_page.dart         # 模块主页（列表）
│   │   │   ├── add_page.dart           # 快速记账页
│   │   │   ├── stats_page.dart         # 月度统计页
│   │   │   ├── category_settings.dart  # 分类管理
│   │   ├── services/
│   │   │   ├── transaction_service.dart
│   │   │   ├── category_service.dart
│   │   │   ├── stats_service.dart
│   │   ├── widgets/
│   │   │   ├── transaction_item.dart
│   │   │   ├── category_grid.dart
│   │   │   ├── amount_input.dart
│   │   │   ├── pie_chart.dart
│   ├── period_tracker/
│   │   ├── period_module.dart          # ToolModule 实现
│   │   ├── models/
│   │   │   ├── period_record.dart
│   │   ├── pages/
│   │   │   ├── calendar_page.dart      # 日历视图主页
│   │   │   ├── record_page.dart        # 记录经期页
│   │   │   ├── stats_page.dart         # 周期统计页
│   │   ├── services/
│   │   │   ├── period_service.dart
│   │   │   ├── prediction_service.dart # 周期预测算法
│   │   ├── widgets/
│   │   │   ├── period_calendar.dart
├── pages/
│   ├── home_page.dart             # 首页（模块卡片网格）
├── shared/
│   ├── widgets/
│   │   ├── module_card.dart       # 首页模块卡片
│   │   ├── month_selector.dart    # 月份选择器
│   │   ├── number_keyboard.dart   # 自定义数字键盘
│   ├── utils/
│   │   ├── date_utils.dart
│   │   ├── format_utils.dart      # 金额格式化等
```

---

## 3. ToolModule 抽象接口

```dart
abstract class ToolModule {
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
  await CoreServices.initialize();

  ModuleRegistry.instance.register(AccountingModule());
  ModuleRegistry.instance.register(PeriodTrackerModule());
  // 未来新模块只需在此注册一行

  runApp(ToolboxApp());
}

// ModuleRegistry
class ModuleRegistry {
  final Map<String, ToolModule> _modules = {};

  void register(ToolModule module) {
    _modules[module.moduleId] = module;
    module.onRegister(ModuleContext(moduleId: module.moduleId));
    // 注册路由
    AppRouter.instance.registerModuleRoute(module);
  }

  List<ToolModule> getEnabledModules(SettingsService settings) {
    return _modules.values
      .where((m) => settings.isModuleEnabled(m.moduleId))
      .toList();
  }
}
```

---

## 5. 路由设计

```dart
// 全局路由结构
final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => HomePage()),
    GoRoute(path: '/settings', builder: (_, __) => SettingsPage()),
    // 模块路由 — 动态注册
    GoRoute(
      path: '/accounting',
      builder: (_, __) => AccountingEntryPage(),
      routes: [
        GoRoute(path: 'add', builder: (_, __) => AddTransactionPage()),
        GoRoute(path: 'stats', builder: (_, __) => StatsPage()),
        GoRoute(path: 'categories', builder: (_, __) => CategorySettingsPage()),
      ],
    ),
    GoRoute(
      path: '/period_tracker',
      builder: (_, __) => CalendarPage(),
      routes: [
        GoRoute(path: 'record', builder: (_, __) => RecordPage()),
        GoRoute(path: 'stats', builder: (_, __) => PeriodStatsPage()),
      ],
    ),
  ],
);
```

---

## 6. 数据存储

### 6.1 存储引擎

SQLite（通过 `sqflite` 包），每个模块使用独立表前缀。

### 6.2 表命名规则

`mod_{moduleId}_{tableName}`

示例：
- `mod_accounting_transactions`
- `mod_accounting_categories`
- `mod_period_tracker_records`

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
  is_custom INTEGER NOT NULL DEFAULT 0,  -- 0=预设, 1=自定义
  sort_order INTEGER NOT NULL
);
```

### 6.5 生理期模块数据表

```sql
-- 经期记录表
CREATE TABLE mod_period_tracker_records (
  id TEXT PRIMARY KEY,
  start_date TEXT NOT NULL,    -- ISO 8601 日期字符串
  end_date TEXT,               -- 可空，表示进行中
  cycle_length INTEGER,       -- 周期天数，由相邻 startDate 差值计算
  created_at TEXT NOT NULL,
  updated_at TEXT
);
```

---

## 7. 主题配置

仅支持浅色模式，每个模块通过 `themeColor` 定义强调色：

```dart
// app_theme.dart
class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: Colors.blue,  // 全局种子色
  );
}

// theme_extension.dart
class ModuleThemeExtension extends ThemeExtension<ModuleThemeExtension> {
  final Color moduleColor;  // 各模块自己的强调色

  const ModuleThemeExtension({required this.moduleColor});

  @override
  ModuleThemeExtension copyWith({Color? moduleColor}) =>
    ModuleThemeExtension(moduleColor: moduleColor ?? this.moduleColor);

  @override
  ModuleThemeExtension lerp(ModuleThemeExtension other, double t) =>
    ModuleThemeExtension(moduleColor: Color.lerp(moduleColor, other.moduleColor, t)!);
}
```

**模块主题色定义：**

| 模块 | themeColor |
|------|-----------|
| 记账 | `Colors.green` (#4CAF50) |
| 生理期记录 | `Colors.pink` (#E91E63) |

---

## 8. 首页摘要接口

各模块通过 `ModuleSummaryProvider` 接口向首页卡片提供实时摘要：

```dart
abstract class ModuleSummaryProvider {
  /// 返回模块在首页卡片上显示的摘要信息（最多2行）
  Future<ModuleSummary> getSummary();
}

class ModuleSummary {
  final String line1;  // 摘要第一行
  final String? line2; // 摘要第二行（可选）
}
```

**记账模块摘要示例：** `line1: "今日支出 ¥128.50"`
**生理期模块摘要示例：** `line1: "下次预测 6月12日"`, `line2: "当前周期 第18天"`

---

## 9. 周期预测算法实现

```dart
class PredictionService {
  /// 计算加权平均周期长度
  int predictNextCycle(List<PeriodRecord> records) {
    if (records.length < 3) return 28; // 默认值

    // 取最近6个有效周期长度
    final cycleLengths = records
      .where((r) => r.cycleLength != null)
      .map((r) => r.cycleLength!)
      .toList()
      .reversed
      .take(6)
      .toList();

    if (cycleLengths.isEmpty) return 28;

    // 加权计算: 最近1个权重3, 最近2个权重2, 最近3-6个权重1
    final weights = [3, 2, 1, 1, 1, 1];
    double sum = 0;
    double weightSum = 0;

    for (int i = 0; i < cycleLengths.length; i++) {
      sum += cycleLengths[i] * weights[i];
      weightSum += weights[i];
    }

    return (sum / weightSum).round();
  }

  /// 预测下次经期开始日期
  DateTime predictNextStartDate(PeriodRecord lastRecord, int avgCycle) {
    return lastRecord.startDate.add(Duration(days: avgCycle));
  }

  /// 预测排卵日
  DateTime predictOvulationDay(DateTime nextStartDate) {
    return nextStartDate.subtract(Duration(days: 14));
  }

  /// 计算易孕期范围（排卵日前5天 ~ 排卵日后1天）
  DateRange getFertileWindow(DateTime ovulationDay) {
    return DateRange(
      start: ovulationDay.subtract(Duration(days: 5)),
      end: ovulationDay.add(Duration(days: 1)),
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
  go_router: ^14.0.0
  flutter_riverpod: ^2.5.0
  sqflite: ^2.3.0
  fl_chart: ^0.69.0
  intl: ^0.19.0
  uuid: ^4.4.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```