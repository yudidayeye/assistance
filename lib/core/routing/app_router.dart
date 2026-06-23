import 'package:go_router/go_router.dart';
import '../module_system/tool_module.dart';
import '../module_system/module_registry.dart';
import '../../pages/home_page.dart';
import '../settings/settings_page.dart';
import '../../modules/accounting/pages/add_page.dart';
import '../../modules/accounting/pages/stats_page.dart';
import '../../modules/accounting/pages/category_settings.dart';
import '../../modules/period_tracker/pages/record_page.dart';
import '../../modules/period_tracker/pages/stats_page.dart';
import '../../pages/profile_page.dart';

/// 全局路由管理
class AppRouter {
  static final AppRouter instance = AppRouter._();
  AppRouter._();

  late GoRouter _router;

  /// 构建所有模块路由（从 ModuleRegistry 获取已注册模块）
  List<GoRoute> _buildModuleRoutes() {
    final modules = ModuleRegistry.instance.allModules;
    return modules.map((module) {
      return GoRoute(
        path: '/${module.moduleId}',
        builder: (context, state) => module.buildEntryPage(context),
        routes: _getModuleSubRoutes(module),
      );
    }).toList();
  }

  /// 获取模块子路由
  List<GoRoute> _getModuleSubRoutes(ToolModule module) {
    switch (module.moduleId) {
      case 'accounting':
        return [
          GoRoute(
            path: 'add',
            builder: (context, state) => const AddTransactionPage(),
          ),
          GoRoute(
            path: 'stats',
            builder: (context, state) => const AccountingStatsPage(),
          ),
          GoRoute(
            path: 'categories',
            builder: (context, state) => const CategorySettingsPage(),
          ),
          GoRoute(
            path: 'edit/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return AddTransactionPage(editId: id);
            },
          ),
        ];
      case 'period_tracker':
        return [
          GoRoute(
            path: 'record',
            builder: (context, state) => const PeriodRecordPage(),
          ),
          GoRoute(
            path: 'stats',
            builder: (context, state) => const PeriodStatsPage(),
          ),
        ];
      default:
        return [];
    }
  }

  /// 初始化路由（在模块注册完成后调用）
  GoRouter initRouter() {
    _router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfilePage(),
        ),
        ..._buildModuleRoutes(),
      ],
    );
    return _router;
  }

  GoRouter get router => _router;
}