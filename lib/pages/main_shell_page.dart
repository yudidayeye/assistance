import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/module_system/module_registry.dart';
import '../core/module_system/tool_module.dart';
import '../core/settings/settings_service.dart';
import '../core/theme/theme_extension.dart';
import '../shared/widgets/featured_card.dart';
import '../shared/widgets/module_row_tile.dart';
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

  /// 工具箱右上「设置」下拉菜单选中处理
  ///
  /// 'cols_1'/'cols_2' → 切换展示样式（经 SettingsController 通知即时重排并持久化）；
  /// 'manage' → 进入模块管理独立页。
  void _onToolboxMenuSelected(String value) {
    if (value == 'cols_1' || value == 'cols_2') {
      _settingsController.setToolboxColumns(value == 'cols_1' ? '1' : '2');
    } else if (value == 'manage') {
      context.push('/module_manage');
    }
  }

  /// 工具箱展示样式下拉菜单项 — 当前列数前带 ✓（leading 占位保证切选时不错位）
  List<PopupMenuEntry<String>> _toolboxMenuItems(String columns) {
    final appTheme = Theme.of(context).appTheme;
    Widget item(IconData? check, String text) => Row(
          children: [
            SizedBox(
              width: 22,
              child: check == null
                  ? null
                  : Icon(Icons.check_rounded, size: 18, color: appTheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 14, color: appTheme.earth),
              ),
            ),
          ],
        );
    return [
      PopupMenuItem(
        value: 'cols_2',
        child: item(columns == '2' ? Icons.check_rounded : null, '双列展示'),
      ),
      PopupMenuItem(
        value: 'cols_1',
        child: item(columns == '1' ? Icons.check_rounded : null, '单列展示'),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'manage',
        child: item(null, '模块管理'),
      ),
    ];
  }

  Widget _buildToolboxPage(AppThemeExtension appTheme) {
    final enabledModules = ModuleRegistry.instance.getEnabledModules();
    final isSingleColumn = _settingsController.toolboxColumns == '1';

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
              child: PopupMenuButton<String>(
                tooltip: '工具箱设置',
                onSelected: _onToolboxMenuSelected,
                itemBuilder: (_) =>
                    _toolboxMenuItems(_settingsController.toolboxColumns),
                icon: Icon(Icons.settings_outlined,
                    size: 20, color: appTheme.earth),
              ),
            ),
          ],
        ),
        if (isSingleColumn)
          // ── 单列：整卡横版行（图标 + 标题 + 摘要 + 箭头，行间细分隔线）──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            sliver: SliverToBoxAdapter(
              child: _buildModuleRowCard(appTheme, enabledModules),
            ),
          )
        else
          // ── 双列：独立方块大卡网格 ──
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

  /// 单列模式的模块横版行整卡 — 与 FeaturedCard 同款底色/圆角/描边，
  /// 内部逐模块一行，行间由 ModuleRowTile.showDivider 绘制分隔线。
  Widget _buildModuleRowCard(
      AppThemeExtension appTheme, List<ToolModule> modules) {
    if (modules.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusLg),
        border: Border.all(
          color: appTheme.earthMedium.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < modules.length; i++)
            ModuleRowTile(
              module: modules[i],
              showDivider: i < modules.length - 1,
            ),
        ],
      ),
    );
  }
}
