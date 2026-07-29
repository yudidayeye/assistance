import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/module_system/module_registry.dart';
import '../core/module_system/tool_module.dart';
import '../core/settings/settings_service.dart';
import '../core/theme/theme_extension.dart';
import '../shared/widgets/featured_card.dart';
import '../shared/widgets/toolbox_bottom_nav.dart';
import '../shared/widgets/app_scaffold.dart';
import '../shared/foundation/app_typography.dart';
import 'profile_page.dart';

/// 主页面容器 — 管理工具箱和我的两个 tab
class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _currentIndex = 0;
  final SettingsController _settingsController = SettingsController.instance;

  @override
  void initState() {
    super.initState();
    _settingsController.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settingsController.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    setState(() {});
  }

  void _showModuleSearch(BuildContext context, AppThemeExtension appTheme) {
    final modules = ModuleRegistry.instance.allModules;
    showSearch(
      context: context,
      delegate: _ModuleSearchDelegate(appTheme, modules),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    return AppScaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildToolboxPage(appTheme),
          const ProfilePageContent(),
        ],
      ),
      bottomNavigationBar: ToolboxBottomNav(
        selectedIndex: _currentIndex,
        onTap: (index) {
          if (index == _currentIndex) return;
          setState(() => _currentIndex = index);
        },
      ),
    );
  }

  Widget _buildToolboxPage(AppThemeExtension appTheme) {
    final enabledModules = ModuleRegistry.instance.getEnabledModules();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: appTheme.cream,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 0,
          title: Text(
            '工具箱',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
          ),
          actions: [
            IconButton(
              onPressed: () => _showModuleSearch(context, appTheme),
              icon: Icon(Icons.search_rounded, color: appTheme.earth, size: 20),
            ),
            IconButton(
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
              color: appTheme.earth,
              iconSize: 20,
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio: 0.88,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final module = enabledModules[index];
                return FeaturedCard(module: module);
              },
              childCount: enabledModules.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

class _ModuleSearchDelegate extends SearchDelegate<ToolModule?> {
  final AppThemeExtension appTheme;
  final List<ToolModule> allModules;

  _ModuleSearchDelegate(this.appTheme, this.allModules);

  @override
  String get searchFieldLabel => '搜索模块';

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        onPressed: () => query = '',
        icon: Icon(Icons.clear_rounded, color: appTheme.earthMedium),
      ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, null),
    icon: Icon(Icons.arrow_back_ios_new_rounded, color: appTheme.earth),
  );

  @override
  Widget buildResults(BuildContext context) {
    final results = allModules
        .where((m) => m.displayName.contains(query))
        .toList();
    return _buildResultsList(results);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final results = query.isEmpty
        ? allModules
        : allModules
            .where((m) => m.displayName.contains(query))
            .toList();
    return _buildResultsList(results);
  }

  Widget _buildResultsList(List<ToolModule> modules) {
    if (modules.isEmpty) {
      return Center(
        child: Text(
          '未找到匹配的模块',
          style: TextStyle(color: appTheme.earthMedium.withValues(alpha: 0.5)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final module = modules[index];
        return ListTile(
          leading: module.icon.build(size: 24, color: appTheme.earth),
          title: Text(module.displayName, style: TextStyle(color: appTheme.earth)),
          onTap: () {
            close(context, module);
            // 跳转到对应模块
            final route = '/${module.moduleId}';
            if (module.moduleId == 'accounting') {
              context.push('/accounting');
            } else if (module.moduleId == 'period_tracker') {
              context.push('/period_tracker');
            }
          },
        );
      },
    );
  }
}

