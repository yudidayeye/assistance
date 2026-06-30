import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../module_system/module_registry.dart';
import '../module_system/tool_module.dart';
import 'settings_service.dart';
import '../storage/database_service.dart';
import '../theme/theme_extension.dart';
import '../theme/theme_provider.dart';

/// 全局设置页面 — 奢华自然主义风格
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
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;
    final modules = ModuleRegistry.instance.allModules;

    return Scaffold(
      backgroundColor: appTheme.cream,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 头部区域
          SliverToBoxAdapter(
            child: _buildHeader(context, appTheme),
          ),

          // 模块管理
          SliverToBoxAdapter(
            child: _buildSectionHeader(appTheme, '模块管理', Icons.apps_rounded),
          ),
          SliverToBoxAdapter(
            child: _buildModuleSection(appTheme, modules),
          ),

          // 主题设置
          SliverToBoxAdapter(
            child: _buildSectionHeader(appTheme, '主题设置', Icons.palette_rounded),
          ),
          SliverToBoxAdapter(
            child: _buildThemeSection(appTheme),
          ),

          // 功能
          SliverToBoxAdapter(
            child: _buildSectionHeader(appTheme, '功能', Icons.apps_rounded),
          ),
          SliverToBoxAdapter(
            child: _buildFunctionSection(appTheme),
          ),

          // 关于
          SliverToBoxAdapter(
            child: _buildSectionHeader(
                appTheme, '关于', Icons.info_outline_rounded),
          ),
          SliverToBoxAdapter(
            child: _buildAboutSection(appTheme),
          ),

          // 底部间距
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppThemeExtension appTheme) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.of(context).padding.top + 16, 24, 24),
      child: Row(
        children: [
          // 返回按钮
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: appTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(appTheme.radiusMd),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: appTheme.earthMedium,
                size: 18,
              ),
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

  Widget _buildSectionHeader(
      AppThemeExtension appTheme, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: appTheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 18,
              color: appTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontFamily: GoogleFonts.playfairDisplay().fontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: appTheme.earth,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleSection(
      AppThemeExtension appTheme, List<ToolModule> modules) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusLg),
      ),
      child: Column(
        children: modules.asMap().entries.map((entry) {
          final index = entry.key;
          final module = entry.value;
          final isLast = index == modules.length - 1;

          return Column(
            children: [
              _buildModuleItem(appTheme, module),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 60,
                  color: appTheme.earthMedium.withAlpha(15),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildModuleItem(AppThemeExtension appTheme, ToolModule module) {
    final enabled = _settings.isModuleEnabled(module.moduleId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // 模块图标
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: module.themeColor.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: module.icon.build(size: 22, color: module.themeColor),
            ),
          ),
          const SizedBox(width: 16),

          // 模块信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.displayName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: appTheme.earth,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  enabled ? '已启用' : '已禁用',
                  style: TextStyle(
                    fontSize: 13,
                    color: enabled ? appTheme.sage : appTheme.earthMedium,
                  ),
                ),
              ],
            ),
          ),

          // 开关
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: enabled,
              onChanged: (val) async {
                await _controller.setModuleEnabled(module.moduleId, val);
                setState(() {});
              },
              activeThumbColor: module.themeColor,
              activeTrackColor: module.themeColor.withAlpha(60),
              inactiveThumbColor: appTheme.earthMedium,
              inactiveTrackColor: appTheme.creamDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSection(AppThemeExtension appTheme) {
    final currentTheme = ThemeProvider.instance.currentTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusLg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: AppThemeType.values.map((type) {
          final isSelected = currentTheme == type;
          return GestureDetector(
            onTap: () async {
              await ThemeProvider.instance.setTheme(type);
              setState(() {});
            },
            child: Column(
              children: [
                // 色块预览
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: type.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? appTheme.earth : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: type.color.withAlpha(60),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 28,
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                // 主题名称
                Text(
                  type.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? appTheme.earth : appTheme.earthMedium,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFunctionSection(AppThemeExtension appTheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusLg),
      ),
      child: Column(
        children: [
          _buildFunctionItem(
            appTheme,
            icon: Icons.notifications_outlined,
            label: '通知管理',
            onTap: () {},
          ),
          Divider(
            height: 1,
            indent: 56,
            color: appTheme.earthMedium.withAlpha(15),
          ),
          _buildFunctionItem(
            appTheme,
            icon: Icons.help_outline_rounded,
            label: '帮助与反馈',
            onTap: () {},
          ),
          Divider(
            height: 1,
            indent: 56,
            color: appTheme.earthMedium.withAlpha(15),
          ),
          _buildFunctionItem(
            appTheme,
            icon: Icons.delete_outline_rounded,
            label: '清除业务数据',
            onTap: _confirmClearBusinessData,
          ),
        ],
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: appTheme.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: appTheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: appTheme.earth,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: appTheme.earthMedium.withAlpha(100),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection(AppThemeExtension appTheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusLg),
      ),
      child: Column(
        children: [
          _buildAboutItem(appTheme, '版本', 'V1.0.0'),
          Divider(height: 1, indent: 60, color: appTheme.earthMedium.withAlpha(15)),
          _buildAboutItem(appTheme, '隐私声明', '所有数据仅存储在本地'),
          Divider(height: 1, indent: 60, color: appTheme.earthMedium.withAlpha(15)),
          _buildAboutItem(appTheme, '免责声明', '生理期预测仅供参考'),
        ],
      ),
    );
  }

  Widget _buildAboutItem(
      AppThemeExtension appTheme, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: appTheme.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              title == '版本'
                  ? Icons.info_outline_rounded
                  : title == '隐私声明'
                      ? Icons.lock_outline_rounded
                      : Icons.shield_outlined,
              color: appTheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: appTheme.earth,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: appTheme.earthMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearBusinessData() {
    final appTheme = Theme.of(context).appTheme;

    showDialog(
      context: context,
      barrierColor: appTheme.surfaceOverlay,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: appTheme.cream,
            borderRadius: BorderRadius.circular(appTheme.radiusXl),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: appTheme.rose.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: appTheme.rose,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '确认清除所有业务数据？',
                style: TextStyle(
                  fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: appTheme.earth,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '此操作将删除所有记账和生理期记录，但保留设置和主题偏好。',
                style: TextStyle(
                  fontSize: 14,
                  color: appTheme.earthMedium,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
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
                          child: Text(
                            '取消',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: appTheme.earthMedium,
                            ),
                          ),
                        ),
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
                          child: Text(
                            '确认清除',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    final appTheme = Theme.of(context).appTheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: appTheme.earth,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: appTheme.primaryLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
