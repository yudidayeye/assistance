import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'core/module_system/module_registry.dart';
import 'core/storage/database_service.dart';
import 'core/theme/theme_provider.dart';
import 'core/routing/app_router.dart';
import 'core/settings/settings_service.dart';
import 'modules/period_tracker/period_module.dart';
import 'modules/period_book/period_book_module.dart';
import 'modules/vault/vault_module.dart';
import 'modules/vault/services/vault_shortcut_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[Boot] 1/6 数据库工厂...');
  await DatabaseService.initializeFactory();

  debugPrint('[Boot] 2/6 打开数据库...');
  await DatabaseService.instance.database;

  debugPrint('[Boot] 3/6 注册模块...');
  await ModuleRegistry.instance.registerAll([
    PeriodTrackerModule(),
    PeriodBookModule(),
    VaultModule(),
  ]);

  debugPrint('[Boot] 4/6 初始化设置...');
  await SettingsService.instance.seedDefaultsForModules();

  debugPrint('[Boot] 5/6 加载主题...');
  await SettingsService.instance.loadSettings();
  await ThemeProvider.instance.loadTheme();

  debugPrint('[Boot] 6/6 初始化路由...');
  final startupCategoryId = VaultShortcutService.instance.startupCategoryId;
  final router = AppRouter.instance.initRouter(
    initialLocation:
        startupCategoryId == null ? '/' : '/vault/category/$startupCategoryId',
  );

  debugPrint('[Boot] 启动完成');
  runApp(ToolboxApp(router: router));
}

/// 工具箱 App
class ToolboxApp extends StatelessWidget {
  final GoRouter router;

  const ToolboxApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeProvider.instance,
      builder: (context, child) {
        return MaterialApp.router(
          title: '理解',
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
