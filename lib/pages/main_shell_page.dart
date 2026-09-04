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
  final MenuController _toolboxMenuController = MenuController();

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

  /// 工具箱右上「设置」更多菜单 — 面板首行「展示样式」分段按钮 + 模块管理入口
  ///
  /// 用 MenuAnchor 承载可交互内容（PopupMenuButton 无法在面板内放分段按钮）。
  /// 面板宽度定宽，锚点为 AppBar actions 末位的 ⋮ 按钮，弹出位置自动贴合屏幕右缘。
  Widget _buildMoreMenu(AppThemeExtension appTheme) {
    final controller = _toolboxMenuController;
    return MenuAnchor(
      controller: controller,
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(appTheme.cardBackground),
        side: WidgetStatePropertyAll(
          BorderSide(
            color: appTheme.earthMedium.withValues(alpha: 0.12),
            width: 0.5,
          ),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(appTheme.radiusMd),
          ),
        ),
        elevation: const WidgetStatePropertyAll(6),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      menuChildren: [
        SizedBox(
          width: 240,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 展示样式：名称 + 右侧分段选择
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    Text(
                      '展示样式',
                      style: AppTypography.bodyMd
                          .copyWith(color: appTheme.earth),
                    ),
                    const Spacer(),
                    _buildViewStyleSegmented(appTheme),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                indent: 16,
                endIndent: 16,
                color: appTheme.earthMedium.withValues(alpha: 0.08),
              ),
              // 模块管理入口
              InkWell(
                onTap: () {
                  controller.close();
                  context.push('/module_manage');
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.apps_rounded,
                          size: 18, color: appTheme.earth),
                      const SizedBox(width: 8),
                      Text(
                        '模块管理',
                        style: AppTypography.bodyMd
                            .copyWith(color: appTheme.earth),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      builder: (context, menuController, _) => IconButton(
        tooltip: '工具箱设置',
        onPressed: () {
          menuController.isOpen
              ? menuController.close()
              : menuController.open();
        },
        icon: Icon(Icons.more_vert_rounded,
            size: 20, color: appTheme.earth),
      ),
    );
  }

  /// 工具箱展示样式分段按钮 — 双列/单列
  ///
  /// 照历史记录页标题右侧 SegmentedButton 风格：选中主色高亮 + 白字。
  /// 切换经 SettingsController 持久化并通知即时重排模块网格。
  Widget _buildViewStyleSegmented(AppThemeExtension appTheme) {
    final columns = _settingsController.toolboxColumns;
    return SegmentedButton<String>(
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: WidgetStateProperty.resolveWith<Color>(
          (states) => states.contains(WidgetState.selected)
              ? appTheme.primary
              : appTheme.cardBackground,
        ),
        foregroundColor: WidgetStateProperty.resolveWith<Color>(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : appTheme.earth,
        ),
        side: WidgetStateProperty.all(
          BorderSide(color: appTheme.earthMedium.withValues(alpha: 0.2)),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(appTheme.radiusSm),
          ),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),
      segments: const [
        ButtonSegment<String>(
          value: '2',
          label: Text('双列', style: TextStyle(fontSize: 12)),
        ),
        ButtonSegment<String>(
          value: '1',
          label: Text('单列', style: TextStyle(fontSize: 12)),
        ),
      ],
      selected: {columns},
      onSelectionChanged: (selection) {
        _settingsController.setToolboxColumns(selection.first);
        // 切换后关闭菜单，让用户立即看到整屏布局效果
        _toolboxMenuController.close();
      },
    );
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
            // 更多菜单（展示样式 + 模块管理，右上角展开）
            _buildMoreMenu(appTheme),
          ],
        ),
        if (isSingleColumn)
          // ── 单列：独立横版模块卡（图标 + 标题 + 摘要 + 箭头），卡间留间距 ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            sliver: SliverToBoxAdapter(
              child: _buildModuleCards(enabledModules),
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

  /// 单列模式的模块横版卡片列表 — 每模块一张独立圆角卡（由 ModuleRowTile 自带），
  /// 卡间留 10px 间距。
  Widget _buildModuleCards(List<ToolModule> modules) {
    if (modules.isEmpty) return const SizedBox.shrink();
    final tiles = <Widget>[];
    for (var i = 0; i < modules.length; i++) {
      tiles.add(ModuleRowTile(module: modules[i]));
      if (i < modules.length - 1) tiles.add(const SizedBox(height: 10));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: tiles);
  }
}
