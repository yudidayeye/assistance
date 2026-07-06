import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'core/module_system/module_registry.dart';
import 'core/storage/database_service.dart';
import 'core/theme/theme_provider.dart';
import 'core/routing/app_router.dart';
import 'core/settings/settings_service.dart';
import 'modules/accounting/accounting_module.dart';
import 'modules/period_tracker/period_module.dart';
import 'modules/period_book/period_book_module.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 初始化数据库工厂
  await DatabaseService.initializeFactory();

  // 2. 打开数据库
  await DatabaseService.instance.database;

  // 3. 注册并 await 所有模块（确保 onRegister 完成后再继续）
  await ModuleRegistry.instance.registerAll([
    AccountingModule(),
    PeriodTrackerModule(),
    PeriodBookModule(),
  ]);

  // 4. 初始化设置默认值（基于已注册模块动态 seed）
  await SettingsService.instance.seedDefaultsForModules();

  // 5. 加载设置和主题
  await SettingsService.instance.loadSettings();
  await ThemeProvider.instance.loadTheme();

  // 6. 初始化路由
  final router = AppRouter.instance.initRouter();

  runApp(ToolboxApp(router: router));
}

/// 工具集 App
class ToolboxApp extends StatelessWidget {
  final GoRouter router;

  const ToolboxApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeProvider.instance,
      builder: (context, child) {
        return MaterialApp.router(
          title: '我的工具箱',
          theme: ThemeProvider.instance.themeData,
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
      },
    );
  }
}
