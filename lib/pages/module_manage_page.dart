import 'package:flutter/material.dart';
import '../core/module_system/module_registry.dart';
import '../core/module_system/tool_module.dart';
import '../core/settings/settings_service.dart';
import '../core/theme/theme_extension.dart';
import '../shared/foundation/app_spacing.dart';
import '../shared/foundation/app_typography.dart';
import '../shared/widgets/app_scaffold.dart';
import '../shared/widgets/section_card.dart';

/// 模块管理页面 — 从设置页独立出来：启用 / 固定 / 拖拽排序
///
/// 由工具箱顶部「设置」下拉菜单的「模块管理」进入。
/// 能力与原先设置页顶部的模块管理区块一致。
class ModuleManagePage extends StatefulWidget {
  const ModuleManagePage({super.key});

  @override
  State<ModuleManagePage> createState() => _ModuleManagePageState();
}

class _ModuleManagePageState extends State<ModuleManagePage> {
  final SettingsService _settings = SettingsService.instance;
  final SettingsController _controller = SettingsController.instance;

  // ── 模块行几何（px），供行内排版与分隔线对齐使用 ──
  static const double _moduleRowPadH = 20;
  static const double _moduleHandleSize = 18;
  static const double _moduleHandleGap = 8;
  static const double _moduleIconSize = 34;
  // 分隔线左缘对齐到文字列起点 = 行内左边距 + 手柄 + 手柄右距 + 图标 + 图标与文字间距
  static const double _moduleTextIndent = _moduleRowPadH +
      _moduleHandleSize +
      _moduleHandleGap +
      _moduleIconSize +
      12;
  // 右侧「启用/固定」开关列列宽（px）：与标准 Material Switch 实际布局宽一致，
  // 标题行表头与行内开关均以该宽度居中，保证两列表心在水平方向精确对齐。
  // 卡片外边距 17 + 行内右边距 20 = 37，即标题行右缩进。
  static const double _moduleSwitchCol = 60;

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    final modules = ModuleRegistry.instance.orderedModules;

    return AppScrollScaffold(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: appTheme.cream,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 0,
          automaticallyImplyLeading: true,
          title: Text(
            '模块管理',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 标题行（左侧说明 + 右侧一次「启用/固定」列表头） ──
              _buildModuleHeader(appTheme),
              SectionCard(
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorderItem: _onModuleReorder,
                  proxyDecorator: (child, index, animation) =>
                      _buildModuleDragProxy(appTheme, child),
                  itemCount: modules.length,
                  itemBuilder: (context, index) {
                    final module = modules[index];
                    final isLast = index == modules.length - 1;
                    return Column(
                      key: ValueKey(module.moduleId),
                      children: [
                        _buildModuleItem(appTheme, module, index),
                        if (!isLast) _buildModuleSeparator(appTheme),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 模块管理 — 扁平行（支持拖动排序）
  // ═══════════════════════════════════════════════════════════════
  Widget _buildModuleItem(
      AppThemeExtension appTheme, ToolModule module, int index) {
    final enabled = _settings.isModuleEnabled(module.moduleId);
    final pinned = _settings.isModulePinned(module.moduleId);
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: _moduleRowPadH, vertical: 8),
      child: Row(
        children: [
          // ① 拖拽手柄（最左）：按下即拖，无需长按
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(right: _moduleHandleGap),
              child: Icon(Icons.drag_indicator_rounded,
                  size: _moduleHandleSize,
                  color: appTheme.earthMedium.withValues(alpha: 0.35)),
            ),
          ),
          // ② 内容区：图标 + 名称，长按即可拖动（不干扰开关点按）
          Expanded(
            child: ReorderableDelayedDragStartListener(
              index: index,
              child: Row(
                children: [
                  Container(
                    width: _moduleIconSize,
                    height: _moduleIconSize,
                    decoration: BoxDecoration(
                      color: module.themeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(appTheme.radiusMd),
                    ),
                    child: Center(
                      child: module.icon.build(
                          size: 18, color: module.themeColor),
                    ),
                  ),
                  AppSpacing.w12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(module.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySm
                                .copyWith(color: appTheme.earth)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          // ③ 启用开关（关闭启用会联动清除固定）
          _buildModuleSwitch(
            value: enabled,
            accentColor: module.themeColor,
            onChanged: (val) async {
              await _controller.setModuleEnabled(module.moduleId, val);
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(width: 12),
          // ④ 固定开关（模块禁用时呈禁用态、不可点）
          _buildModuleSwitch(
            value: pinned,
            accentColor: module.themeColor,
            onChanged: enabled
                ? (val) async {
                    await _controller.setModulePinned(module.moduleId, val);
                    if (mounted) setState(() {});
                  }
                : null,
          ),
        ],
      ),
    );
  }

  /// 模块列表标题行 — 左侧「拖动排序」说明，右侧同行标注一次「启用/固定」列表头。
  ///
  /// 行内每枚开关已不再重复文字，两列含义只在标题行说明。
  /// 右缘与卡片内容对齐：标题行右缩进 = 卡片外边距(17) + 行内右边距(20) = 37，
  /// 两列表头按 [_moduleSwitchCol] 定宽、间距 12 → 与每行开关列心精确对齐。
  Widget _buildModuleHeader(AppThemeExtension appTheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 37, bottom: 8),
      child: Row(
        children: [
          Text(
            '拖动排序',
            style: AppTypography.label.copyWith(
              color: appTheme.earthMedium,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Spacer(),
          _buildModuleHeaderWord(appTheme, '启用'),
          const SizedBox(width: 12),
          _buildModuleHeaderWord(appTheme, '固定'),
        ],
      ),
    );
  }

  /// 标题行右侧的一个列表头文字 — 与下方对应开关列同宽并居中。
  Widget _buildModuleHeaderWord(
      AppThemeExtension appTheme, String word) {
    return SizedBox(
      width: _moduleSwitchCol,
      child: Text(
        word,
        textAlign: TextAlign.center,
        style: AppTypography.caption.copyWith(
          fontSize: 10.5,
          height: 1,
          fontWeight: FontWeight.w600,
          color: appTheme.earthMedium.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  /// 模块行的「启用/固定」开关 — 标准 Material Switch，外观与改动前一致。
  ///
  /// Switch 配色：模块主题色圆头、淡主题色轨道，关闭态灰白轨道 + 灰圆头。
  /// 固定宽为 [_moduleSwitchCol]，与标题行列表头同宽，保证文字列心对齐。
  Widget _buildModuleSwitch({
    required bool value,
    required Color accentColor,
    required ValueChanged<bool>? onChanged,
  }) {
    final appTheme = Theme.of(context).appTheme;
    return SizedBox(
      width: _moduleSwitchCol,
      child: Center(
        child: Transform.scale(
          scale: 0.8,
          alignment: Alignment.center,
          child: Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeTrackColor: accentColor.withValues(alpha: 0.12),
            activeThumbColor: accentColor,
            inactiveThumbColor: appTheme.earthMedium.withValues(alpha: 0.45),
            inactiveTrackColor: appTheme.earthMedium.withValues(alpha: 0.12),
            trackOutlineColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.transparent;
              }
              return appTheme.earthMedium.withValues(alpha: 0.25);
            }),
          ),
        ),
      ),
    );
  }

  /// 拖拽排序回调 — 更新模块展示顺序并持久化
  ///
  /// onReorderItem 传入的 newIndex 已由框架修正（无需再减一）。
  /// 缓存同步更新后立即重建，保证落下动画与新顺序一致；
  /// 数据库写入在后台完成，首页卡片顺序通过 SettingsController 通知刷新。
  void _onModuleReorder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final ids = ModuleRegistry.instance.orderedModules
        .map((m) => m.moduleId)
        .toList();
    final movedId = ids.removeAt(oldIndex);
    ids.insert(newIndex, movedId);
    setState(() {
      _controller.setModuleOrder(ids);
    });
  }

  /// 拖拽中的浮动代理样式 — 卡片底色 + 极轻阴影，保持安静的视觉语言
  ///
  /// 代理子树挂载在 Overlay 中（脱离原页面的 Material 祖先），
  /// 必须包一层透明 Material 以提供文字样式等继承环境。
  Widget _buildModuleDragProxy(AppThemeExtension appTheme, Widget child) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: appTheme.cardBackground,
          borderRadius: BorderRadius.circular(appTheme.radiusMd),
          border: Border.all(
            color: appTheme.earthMedium.withValues(alpha: 0.15),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: appTheme.earthMedium.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  /// 模块行分割线 — 左缘对齐到文字列（考虑左侧拖拽手柄）
  Widget _buildModuleSeparator(AppThemeExtension appTheme) {
    return Padding(
      padding: const EdgeInsets.only(left: _moduleTextIndent),
      child: Divider(
          height: 0,
          thickness: 0.5,
          color: appTheme.earthMedium.withValues(alpha: 0.07)),
    );
  }
}
