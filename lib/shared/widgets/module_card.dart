import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/module_system/tool_module.dart';
import '../../core/module_system/module_summary.dart';
import '../../core/theme/theme_extension.dart';

/// 首页模块卡片 — 奢华自然主义风格
class ModuleCard extends StatefulWidget {
  final ToolModule module;
  final int index;

  const ModuleCard({super.key, required this.module, this.index = 0});

  @override
  State<ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<ModuleCard>
    with SingleTickerProviderStateMixin {
  ModuleSummary? _summary;
  bool _loading = true;
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // 错开动画
    Future.delayed(Duration(milliseconds: 100 * widget.index), () {
      if (mounted) _controller.forward();
    });

    _loadSummary();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await widget.module.getSummary();
      if (mounted) {
        setState(() {
          _summary = summary;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;
    final color = widget.module.themeColor;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Card(
          child: InkWell(
            onTap: () => context.push('/${widget.module.moduleId}'),
            onLongPress: () => _showQuickMenu(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withAlpha(30),
                    color.withAlpha(10),
                  ],
                ),
                border: Border.all(
                  color: color.withAlpha(40),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 图标容器
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withAlpha(50),
                          color.withAlpha(20),
                        ],
                      ),
                    ),
                    child: Center(
                      child: widget.module.icon.build(size: 26, color: color),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 模块名称
                  Text(
                    widget.module.displayName,
                    style: TextStyle(
                      fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: appTheme.earth,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 摘要信息
                  if (_loading)
                    SizedBox(
                      height: 32,
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: color,
                          ),
                        ),
                      ),
                    )
                  else if (_summary != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _summary!.line1,
                          style: TextStyle(
                            fontSize: 13,
                            color: appTheme.earthMedium,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_summary!.line2 != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _summary!.line2!,
                            style: TextStyle(
                              fontSize: 12,
                              color: appTheme.earthMedium.withAlpha(150),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),

                  const Spacer(),

                  // 进入指示
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '探索',
                        style: TextStyle(
                          fontSize: 13,
                          color: color,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: color,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showQuickMenu(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: appTheme.cream,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽指示器
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: appTheme.earthMedium.withAlpha(60),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // 菜单项
            _buildMenuItem(
              ctx,
              icon: Icons.visibility_off_outlined,
              label: '禁用模块',
              color: appTheme.earthMedium,
              onTap: () {
                Navigator.pop(ctx);
                // TODO: 禁用模块逻辑
              },
            ),
            _buildMenuItem(
              ctx,
              icon: Icons.delete_outline_rounded,
              label: '重置数据',
              color: appTheme.rose,
              onTap: () {
                Navigator.pop(ctx);
                // TODO: 重置数据逻辑
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}
