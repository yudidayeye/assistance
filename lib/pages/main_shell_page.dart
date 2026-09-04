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

/// 主页面容器 — 工具箱、被固定的模块、我的 组成的动态底部 Tab
class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  /// 当前选中 Tab 标识：'toolbox' | 模块 moduleId | 'profile'
  String _selectedId = 'toolbox';
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

  /// 有效 Tab 标识列表（同步读取内存缓存，可在监听回调中安全使用）
  List<String> _tabIds(List<ToolModule> pinnedModules) {
    return <String>[
      'toolbox',
      for (final m in pinnedModules) m.moduleId,
      'profile',
    ];
  }

  void _onSettingsChanged() {
    final pinned = ModuleRegistry.instance.getPinnedModules();
    final ids = _tabIds(pinned);
    setState(() {
      // 当前选中的 Tab 被取消固定/禁用时，安全回落到工具箱
      if (!ids.contains(_selectedId)) _selectedId = 'toolbox';
    });
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    final pinnedModules = ModuleRegistry.instance.getPinnedModules();
    final tabIds = _tabIds(pinnedModules);

    var index = tabIds.indexOf(_selectedId);
    if (index < 0) index = 0; // 防御：首个 Build 前未收到通知时兜底，避免越界

    // 全部包一层稳定 Key，保证增删/重排固定模块时各页状态不丢
    final children = <Widget>[
      KeyedSubtree(
          key: const ValueKey('toolbox'),
          child: _buildToolboxPage(appTheme)),
      for (final m in pinnedModules)
        KeyedSubtree(
            key: ValueKey(m.moduleId), child: m.buildEntryPage(context)),
      const KeyedSubtree(
          key: ValueKey('profile'), child: ProfilePageContent()),
    ];

    return AppScaffold(
      body: IndexedStack(index: index, children: children),
      bottomNavigationBar: ToolboxBottomNav(
        selectedIndex: index,
        items: [
          const ToolboxBottomNavItem(
            label: '工具箱',
            iconBuilder: _toolboxIcon,
          ),
          for (final m in pinnedModules)
            ToolboxBottomNavItem(
              label: m.displayName,
              selectedColor: m.themeColor,
              iconBuilder: (color) => m.icon.build(size: 22, color: color),
            ),
          const ToolboxBottomNavItem(
            label: '我的',
            iconBuilder: _profileIcon,
          ),
        ],
        onTap: (i) {
          if (i == index) return;
          setState(() => _selectedId = tabIds[i]);
        },
      ),
    );
  }

  static Widget _toolboxIcon(Color color) =>
      Icon(Icons.handyman_rounded, size: 22, color: color);

  static Widget _profileIcon(Color color) =>
      Icon(Icons.person_rounded, size: 22, color: color);

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
          title: Text(
            '工具箱',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: () => context.push('/settings'),
                icon: const Icon(Icons.settings_outlined),
                color: appTheme.earth,
                iconSize: 20,
              ),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
                return FeaturedCard(
                  key: ValueKey(module.moduleId),
                  module: module,
                );
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
