import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'core/module_system/module_registry.dart';
import 'core/storage/database_service.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'core/settings/settings_service.dart';
import 'modules/accounting/accounting_module.dart';
import 'modules/period_tracker/period_module.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化数据库工厂（Web 需要特殊处理）
  await DatabaseService.initializeFactory();

  // 初始化核心服务
  await DatabaseService.instance.database;
  await SettingsService.instance.loadSettings();
  await SettingsService.instance.initializeDefaults();

  // 注册模块
  ModuleRegistry.instance.register(AccountingModule());
  ModuleRegistry.instance.register(PeriodTrackerModule());

  // 初始化路由
  final router = AppRouter.instance.initRouter();

  runApp(ToolboxApp(router: router));
}

/// 工具集 App
class ToolboxApp extends StatelessWidget {
  final GoRouter router;

  const ToolboxApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '我的工具箱',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      locale: const Locale('zh', 'CN'),
    );
  }
}