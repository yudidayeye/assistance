import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'modules/info_query/info_query_module.dart';
import 'modules/vault/services/vault_shortcut_service.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final router = await _bootstrap(args);
    runApp(ToolboxApp(router: router));
  } catch (error, stackTrace) {
    debugPrint('[Boot] 启动失败: $error\n$stackTrace');
    runApp(BootErrorApp(error: error, stackTrace: stackTrace, args: args));
  }
}

Future<GoRouter> _bootstrap(List<String> args) async {
  debugPrint('[Boot] 1/6 数据库工厂...');
  await DatabaseService.initializeFactory();

  debugPrint('[Boot] 2/6 打开数据库...');
  await DatabaseService.instance.database;

  debugPrint('[Boot] 3/6 注册模块...');
  ModuleRegistry.instance.reset();
  await ModuleRegistry.instance.registerAll([
    InfoQueryModule(),
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
  final startupCategoryId = VaultShortcutService.categoryIdFromArguments(args);
  final router = AppRouter.instance.initRouter(
    initialLocation:
        startupCategoryId == null ? '/' : '/vault/category/$startupCategoryId',
  );

  debugPrint('[Boot] 启动完成');
  return router;
}

class BootErrorApp extends StatefulWidget {
  final Object error;
  final StackTrace stackTrace;
  final List<String> args;
  final Future<GoRouter> Function(List<String> args) bootloader;

  const BootErrorApp({
    super.key,
    required this.error,
    required this.stackTrace,
    required this.args,
    Future<GoRouter> Function(List<String> args)? bootloader,
  }) : bootloader = bootloader ?? _bootstrap;

  @override
  State<BootErrorApp> createState() => _BootErrorAppState();
}

class _BootErrorAppState extends State<BootErrorApp> {
  late Object _error;
  late StackTrace _stackTrace;
  GoRouter? _router;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _error = widget.error;
    _stackTrace = widget.stackTrace;
  }

  String get _details => '启动失败：$_error\n\n$_stackTrace';

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      final router = await widget.bootloader(widget.args);
      if (!mounted) return;
      setState(() {
        _router = router;
        _retrying = false;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _retrying = false;
        _error = error;
        _stackTrace = stackTrace;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = _router;
    if (router != null) {
      return ToolboxApp(router: router);
    }

    return MaterialApp(
      title: '理解 - 启动失败',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('应用启动失败')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  '应用未能完成启动。\n数据未被删除，请先保留此页面中的诊断信息。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(_details),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: _details),
                        ),
                        icon: const Icon(Icons.copy),
                        label: const Text('复制诊断信息'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _retrying ? null : _retry,
                        icon: _retrying
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh),
                        label: const Text('重试'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
