import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../module_system/module_registry.dart';
import '../../pages/main_shell_page.dart';
import '../../pages/module_manage_page.dart';
import '../settings/settings_page.dart';
import '../sync/sync_page.dart';

/// 全局路由管理 — 系统路由 + 设置页 + 动态收集模块路由
class AppRouter {
  static final AppRouter instance = AppRouter._();
  AppRouter._();

  late GoRouter _router;

  /// 构建标准页面（无过渡动画 — 简洁扁平）
  static Page<dynamic> _buildPage({
    required GoRouterState state,
    required Widget child,
  }) {
    return MaterialPage<dynamic>(
      key: state.pageKey,
      child: child,
    );
  }

  /// 构建所有模块路由（从 ModuleRegistry 获取已注册模块）
  List<GoRoute> _buildModuleRoutes() {
    final modules = ModuleRegistry.instance.allModules;
    return modules.map((module) {
      return GoRoute(
        path: '/${module.moduleId}',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: module.buildEntryPage(context),
        ),
        routes: module.buildSubRoutes(),
      );
    }).toList();
  }

  /// 初始化路由（在模块注册完成后调用）
  GoRouter initRouter({String initialLocation = '/'}) {
    _router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const MainShellPage(),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => _buildPage(
            state: state,
            child: const SettingsPage(),
          ),
        ),
        GoRoute(
          path: '/sync',
          pageBuilder: (context, state) => _buildPage(
            state: state,
            child: const SyncPage(),
          ),
        ),
        GoRoute(
          path: '/module_manage',
          pageBuilder: (context, state) => _buildPage(
            state: state,
            child: const ModuleManagePage(),
          ),
        ),
        ..._buildModuleRoutes(),
      ],
    );
    return _router;
  }

  GoRouter get router => _router;
}
