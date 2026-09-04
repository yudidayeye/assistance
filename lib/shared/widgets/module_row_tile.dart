import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/module_system/tool_module.dart';
import '../../core/module_system/module_summary.dart';
import '../../core/theme/theme_extension.dart';
import '../../modules/period_book/services/period_book_service.dart';
import '../../modules/period_tracker/services/period_service.dart';
import '../../modules/vault/services/vault_service.dart';

/// 工具箱单列展示的横版模块卡片 — 一张圆角卡片内：图标色块 + 主题色标题 + 摘要 + 箭头
///
/// 自带卡片容器（底色/圆角/描边），供单列模式下多个模块卡独立堆叠、
/// 卡间由父级留出间距。
class ModuleRowTile extends StatefulWidget {
  final ToolModule module;
  final VoidCallback? onTap;

  const ModuleRowTile({
    super.key,
    required this.module,
    this.onTap,
  });

  @override
  State<ModuleRowTile> createState() => _ModuleRowTileState();
}

class _ModuleRowTileState extends State<ModuleRowTile> {
  ModuleSummary? _summary;
  bool _refreshing = false;
  String? _boundModuleId;

  @override
  void initState() {
    super.initState();
    _bindModuleListeners();
    _loadSummary();
  }

  @override
  void didUpdateWidget(ModuleRowTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 模块变化（如顺序调整导致 State 复用）时，重绑监听并加载新摘要
    if (oldWidget.module.moduleId != widget.module.moduleId) {
      _unbindModuleListeners();
      _bindModuleListeners();
      _summary = null;
      _loadSummary();
    }
  }

  @override
  void dispose() {
    _unbindModuleListeners();
    super.dispose();
  }

  /// 绑定当前模块的数据变更监听
  void _bindModuleListeners() {
    _boundModuleId = widget.module.moduleId;
    if (_boundModuleId == 'period_book') {
      PeriodBookService.instance.addListener(_onDataChanged);
    }
    if (_boundModuleId == 'period_tracker') {
      PeriodService.instance.addListener(_onDataChanged);
    }
    if (_boundModuleId == 'vault') {
      VaultService.instance.addListener(_onDataChanged);
    }
  }

  /// 解绑当前模块的数据变更监听
  void _unbindModuleListeners() {
    if (_boundModuleId == null) return;
    if (_boundModuleId == 'period_book') {
      PeriodBookService.instance.removeListener(_onDataChanged);
    }
    if (_boundModuleId == 'period_tracker') {
      PeriodService.instance.removeListener(_onDataChanged);
    }
    if (_boundModuleId == 'vault') {
      VaultService.instance.removeListener(_onDataChanged);
    }
    _boundModuleId = null;
  }

  void _onDataChanged() {
    if (mounted) refresh();
  }

  Future<void> _loadSummary() async {
    final moduleId = widget.module.moduleId;
    final s = await widget.module.getSummary();
    // 防止异步期间模块已切换，旧摘要串到新行上
    if (mounted && widget.module.moduleId == moduleId) {
      setState(() => _summary = s);
    }
  }

  /// 外部触发刷新（如从子页面返回后）
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    await _loadSummary();
    _refreshing = false;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.module.themeColor;
    final appTheme = Theme.of(context).appTheme;

    return Container(
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        // 与周期记账「阶段卡片」一致的中等圆角
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
        border: Border.all(
          color: appTheme.earthMedium.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap:
            widget.onTap ?? () => context.push('/${widget.module.moduleId}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // 模块图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(appTheme.radiusMd),
                ),
                child: Center(
                  child: widget.module.icon.build(size: 20, color: color),
                ),
              ),
              const SizedBox(width: 12),
              // 标题 + 摘要
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.module.displayName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: color,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_summary?.line1 != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        _summary!.line1,
                        style: TextStyle(
                          fontSize: 11,
                          color: appTheme.earthMedium,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (_summary?.line2 != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        _summary!.line2!,
                        style: TextStyle(
                          fontSize: 10,
                          color: appTheme.earthMedium.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: appTheme.earthMedium.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
