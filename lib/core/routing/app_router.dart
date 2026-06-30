import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../module_system/module_registry.dart';
import '../../pages/main_shell_page.dart';
import '../settings/settings_page.dart';

/// 全局路由管理 — 系统路由 + 设置页 + 动态收集模块路由
class AppRouter {
  static final AppRouter instance = AppRouter._();
  AppRouter._();

  late GoRouter _router;

  /// 构建带有自定义过渡动画的页面
  static Page<dynamic> _buildPageWithTransition({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.02, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            )),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 250),
    );
  }

  /// 构建所有模块路由（从 ModuleRegistry 获取已注册模块）
  List<GoRoute> _buildModuleRoutes() {
    final modules = ModuleRegistry.instance.allModules;
    return modules.map((module) {
      return GoRoute(
        path: '/${module.moduleId}',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: module.buildEntryPage(context),
        ),
        routes: module.buildSubRoutes(),
      );
    }).toList();
  }

  /// 初始化路由（在模块注册完成后调用）
  GoRouter initRouter() {
    _router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const MainShellPage(),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => _buildPageWithTransition(
            context: context,
            state: state,
            child: const SettingsPage(),
          ),
        ),
        ..._buildModuleRoutes(),
      ],
    );
    return _router;
  }

  GoRouter get router => _router;
}
