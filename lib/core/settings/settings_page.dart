import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../module_system/module_registry.dart';
import '../module_system/tool_module.dart';
import 'settings_service.dart';
import '../storage/database_service.dart';
import '../theme/theme_extension.dart';
import '../theme/theme_provider.dart';

/// 全局设置页面 — 简洁扁平风格
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsService _settings = SettingsService.instance;
  final SettingsController _controller = SettingsController.instance;
  final DatabaseService _db = DatabaseService.instance;

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    final modules = ModuleRegistry.instance.allModules;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: appTheme.scaffoldGradient),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── 头部 ──
            SliverToBoxAdapter(
              child: _buildHeader(context, appTheme),
            ),

            // ── 模块管理 ──
            SliverToBoxAdapter(
              child: Column(children: [
                _buildSectionHeader(appTheme, '模块管理', Icons.apps_rounded),
                _buildModuleSection(appTheme, modules),
              ]),
            ),

            // ── 主题设置 ──
            SliverToBoxAdapter(
              child: Column(children: [
                _buildSectionHeader(appTheme, '主题设置', Icons.palette_rounded),
                _buildThemeSection(appTheme),
              ]),
            ),

            // ── 功能 ──
            SliverToBoxAdapter(
              child: Column(children: [
                _buildSectionHeader(appTheme, '功能', Icons.tune_rounded),
                _buildFunctionSection(appTheme),
              ]),
            ),

            // ── 关于 ──
            SliverToBoxAdapter(
              child: Column(children: [
                _buildSectionHeader(appTheme, '关于', Icons.info_outline_rounded),
                _buildAboutSection(appTheme),
              ]),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 头部
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHeader(BuildContext context, AppThemeExtension appTheme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.of(context).padding.top + 16, 24, 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: appTheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(appTheme.radiusMd),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: appTheme.earthMedium, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '设置',
            style: TextStyle(
              fontFamily: GoogleFonts.playfairDisplay().fontFamily,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: appTheme.earth,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 区块标题
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSectionHeader(
      AppThemeExtension appTheme, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: appTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 15, color: appTheme.primary),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontFamily: GoogleFonts.playfairDisplay().fontFamily,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: appTheme.earth,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 模块管理卡片
  // ═══════════════════════════════════════════════════════════════
  Widget _buildModuleSection(
      AppThemeExtension appTheme, List<ToolModule> modules) {
    return _SoftCard(
      appTheme: appTheme,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: modules.asMap().entries.map((entry) {
        final index = entry.key;
        final module = entry.value;
        final isLast = index == modules.length - 1;
        return Column(children: [
          _buildModuleItem(appTheme, module),
          if (!isLast)
            Padding(
              padding: const EdgeInsets.only(left: 64),
              child: _softDivider(appTheme),
            ),
        ]);
      }).toList(),
    );
  }

  Widget _buildModuleItem(AppThemeExtension appTheme, ToolModule module) {
    final enabled = _settings.isModuleEnabled(module.moduleId);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: module.themeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: module.icon.build(size: 21, color: module.themeColor),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(module.displayName,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: appTheme.earth,
                        height: 1.2)),
                const SizedBox(height: 3),
                Text(enabled ? '已启用' : '已禁用',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: enabled
                            ? appTheme.sage.withValues(alpha: 0.85)
                            : appTheme.earthMedium.withValues(alpha: 0.6))),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.78,
            child: Switch(
              value: enabled,
              onChanged: (val) async {
                await _controller.setModuleEnabled(module.moduleId, val);
                setState(() {});
              },
              activeTrackColor: module.themeColor.withValues(alpha: 0.28),
              activeThumbColor: module.themeColor,
              inactiveThumbColor:
                  appTheme.earthMedium.withValues(alpha: 0.45),
              inactiveTrackColor:
                  appTheme.creamDark.withValues(alpha: 0.7),
              trackOutlineColor:
                  const WidgetStatePropertyAll(Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 主题选择
  // ═══════════════════════════════════════════════════════════════
  Widget _buildThemeSection(AppThemeExtension appTheme) {
    final currentTheme = ThemeProvider.instance.currentTheme;
    return _SoftCard(
      appTheme: appTheme,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: AppThemeType.values.map((type) {
          final isSelected = currentTheme == type;
          return GestureDetector(
            onTap: () async {
              await ThemeProvider.instance.setTheme(type);
              setState(() {});
            },
            child: Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [type.color, type.color.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: type.color.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 26)
                    : null,
              ),
              const SizedBox(height: 10),
              Text(type.label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? appTheme.earth
                          : appTheme.earthMedium)),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 功能列表
  // ═══════════════════════════════════════════════════════════════
  Widget _buildFunctionSection(AppThemeExtension appTheme) {
    return _SoftCard(
      appTheme: appTheme,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        _buildFunctionItem(appTheme,
            icon: Icons.notifications_outlined, label: '通知管理', onTap: () {}),
        Padding(
          padding: const EdgeInsets.only(left: 60),
          child: _softDivider(appTheme),
        ),
        _buildFunctionItem(appTheme,
            icon: Icons.help_outline_rounded, label: '帮助与反馈', onTap: () {}),
        Padding(
          padding: const EdgeInsets.only(left: 60),
          child: _softDivider(appTheme),
        ),
        _buildFunctionItem(appTheme,
            icon: Icons.delete_outline_rounded,
            label: '清除业务数据',
            onTap: _confirmClearBusinessData),
      ],
    );
  }

  Widget _buildFunctionItem(
    AppThemeExtension appTheme, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: appTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: appTheme.primary, size: 21),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: appTheme.earth)),
          ),
          Icon(Icons.chevron_right_rounded,
              color: appTheme.earthMedium.withValues(alpha: 0.25), size: 20),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 关于
  // ═══════════════════════════════════════════════════════════════
  Widget _buildAboutSection(AppThemeExtension appTheme) {
    return _SoftCard(
      appTheme: appTheme,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        _buildAboutItem(appTheme, '版本', 'V1.0.0'),
        Padding(
          padding: const EdgeInsets.only(left: 60),
          child: _softDivider(appTheme),
        ),
        _buildAboutItem(appTheme, '隐私声明', '所有数据仅存储在本地'),
        Padding(
          padding: const EdgeInsets.only(left: 60),
          child: _softDivider(appTheme),
        ),
        _buildAboutItem(appTheme, '免责声明', '生理期预测仅供参考'),
      ],
    );
  }

  Widget _buildAboutItem(
      AppThemeExtension appTheme, String title, String subtitle) {
    IconData icon;
    if (title == '版本') {
      icon = Icons.info_outline_rounded;
    } else if (title == '隐私声明') {
      icon = Icons.lock_outline_rounded;
    } else {
      icon = Icons.shield_outlined;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: appTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: appTheme.primary, size: 21),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: appTheme.earth)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12.5,
                      color: appTheme.earthMedium.withValues(alpha: 0.75))),
            ],
          ),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 确认清除弹窗
  // ═══════════════════════════════════════════════════════════════
  void _confirmClearBusinessData() {
    final appTheme = Theme.of(context).appTheme;
    showDialog(
      context: context,
      barrierColor: appTheme.surfaceOverlay,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: appTheme.cream,
            borderRadius: BorderRadius.circular(appTheme.radiusXl),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: appTheme.rose.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.warning_amber_rounded,
                    color: appTheme.rose, size: 30),
              ),
              const SizedBox(height: 20),
              Text('确认清除所有业务数据？',
                  style: TextStyle(
                      fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: appTheme.earth),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text('此操作将删除所有记账和生理期记录，但保留设置和主题偏好。',
                  style: TextStyle(
                      fontSize: 14, color: appTheme.earthMedium, height: 1.5),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: appTheme.creamDark,
                        borderRadius: BorderRadius.circular(appTheme.radiusMd),
                      ),
                      child: Center(
                          child: Text('取消',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: appTheme.earthMedium))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      await _db.clearAllBusinessData();
                      if (!context.mounted) return;
                      Navigator.pop(ctx);
                      _showSnackBar('业务数据已清除');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: appTheme.rose,
                        borderRadius: BorderRadius.circular(appTheme.radiusMd),
                      ),
                      child: const Center(
                          child: Text('确认清除',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white))),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    final appTheme = Theme.of(context).appTheme;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message,
          style: TextStyle(
              color: appTheme.earth, fontWeight: FontWeight.w500)),
      backgroundColor: appTheme.primaryLight,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }
}

// ═════════════════════════════════════════════════════════════════
// 复用组件
// ═════════════════════════════════════════════════════════════════

/// 柔和卡片容器 — 大圆角 + 近乎无阴影的漂浮感
class _SoftCard extends StatelessWidget {
  final AppThemeExtension appTheme;
  final Widget? child;
  final List<Widget>? children;
  final EdgeInsetsGeometry padding;

  const _SoftCard({
    required this.appTheme,
    this.child,
    this.children,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      padding: padding,
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: appTheme.earth.withValues(alpha: 0.025),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child ?? Column(children: children!),
    );
  }
}

/// 柔和分割线
Widget _softDivider(AppThemeExtension appTheme) {
  return Divider(
      height: 1, color: appTheme.earthMedium.withValues(alpha: 0.08));
}
