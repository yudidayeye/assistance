import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../module_system/module_registry.dart';
import '../module_system/tool_module.dart';
import 'settings_service.dart';
import '../storage/database_service.dart';
import '../theme/theme_extension.dart';
import '../theme/theme_provider.dart';
import 'import_export_service.dart';

/// 全局设置页面 — 深度层级风格
///
/// 通过递进式阴影深度、浮动标题叠加卡片、嵌入式内容区域，
/// 创造出丰富的空间层次感，而非简单的扁平列表。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsService _settings = SettingsService.instance;
  final SettingsController _controller = SettingsController.instance;
  final DatabaseService _db = DatabaseService.instance;
  final ImportExportService _importExport = ImportExportService.instance;

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

            // ── 模块管理（最深阴影 — 最重要） ──
            SliverToBoxAdapter(
              child: _DepthSection(
                appTheme: appTheme,
                title: '模块管理',
                icon: Icons.apps_rounded,
                accentColor: appTheme.primary,
                depth: _CardDepth.foreground,
                children: modules.asMap().entries.map((entry) {
                  final index = entry.key;
                  final module = entry.value;
                  final isLast = index == modules.length - 1;
                  return Column(children: [
                    _buildModuleItem(appTheme, module),
                    if (!isLast) _insetDivider(appTheme),
                  ]);
                }).toList(),
              ),
            ),

            // ── 主题设置（中等阴影） ──
            SliverToBoxAdapter(
              child: _DepthSection(
                appTheme: appTheme,
                title: '主题设置',
                icon: Icons.palette_rounded,
                accentColor: appTheme.primary,
                depth: _CardDepth.midground,
                child: _buildThemeSelector(appTheme),
              ),
            ),

            // ── 功能（较浅阴影） ──
            SliverToBoxAdapter(
              child: _DepthSection(
                appTheme: appTheme,
                title: '功能',
                icon: Icons.tune_rounded,
                accentColor: appTheme.primary,
                depth: _CardDepth.background,
                child: Column(children: [
                  _buildFunctionItem(appTheme,
                      icon: Icons.upload_file_rounded,
                      label: '导出数据',
                      onTap: _handleExport),
                  _insetDivider(appTheme),
                  _buildFunctionItem(appTheme,
                      icon: Icons.download_rounded,
                      label: '导入数据',
                      onTap: _handleImport),
                  _insetDivider(appTheme),
                  _buildFunctionItem(appTheme,
                      icon: Icons.notifications_outlined,
                      label: '通知管理',
                      onTap: () {}),
                  _insetDivider(appTheme),
                  _buildFunctionItem(appTheme,
                      icon: Icons.help_outline_rounded,
                      label: '帮助与反馈',
                      onTap: () {}),
                  _insetDivider(appTheme),
                  _buildFunctionItem(appTheme,
                      icon: Icons.delete_outline_rounded,
                      label: '清除业务数据',
                      onTap: _confirmClearBusinessData,
                      isDestructive: true),
                ]),
              ),
            ),

            // ── 关于（最浅阴影 — 纯信息） ──
            SliverToBoxAdapter(
              child: _DepthSection(
                appTheme: appTheme,
                title: '关于',
                icon: Icons.info_outline_rounded,
                accentColor: appTheme.primary,
                depth: _CardDepth.surface,
                child: Column(children: [
                  _buildAboutItem(appTheme, '版本', 'V1.0.0',
                      icon: Icons.info_outline_rounded),
                  _insetDivider(appTheme),
                  _buildAboutItem(appTheme, '隐私声明', '所有数据仅存储在本地',
                      icon: Icons.lock_outline_rounded),
                  _insetDivider(appTheme),
                  _buildAboutItem(appTheme, '免责声明', '生理期预测仅供参考',
                      icon: Icons.shield_outlined),
                ]),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 头部
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHeader(BuildContext context, AppThemeExtension appTheme) {
    final safeTop = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, safeTop + 16, 24, 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: appTheme.primary.withValues(alpha: 0.08),
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
              fontFamily: GoogleFonts.dmSans().fontFamily,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: appTheme.earth,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 模块管理 — 嵌入式行
  // ═══════════════════════════════════════════════════════════════
  Widget _buildModuleItem(AppThemeExtension appTheme, ToolModule module) {
    final enabled = _settings.isModuleEnabled(module.moduleId);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: Row(
        children: [
          // 模块图标 — 带模块主题色的柔和背景
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: module.themeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: module.icon.build(size: 20, color: module.themeColor),
            ),
          ),
          const SizedBox(width: 14),
          // 名称 + 状态
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                        fontSize: 12,
                        color: enabled
                            ? appTheme.sage.withValues(alpha: 0.85)
                            : appTheme.earthMedium.withValues(alpha: 0.55))),
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
              activeTrackColor: module.themeColor.withValues(alpha: 0.22),
              activeThumbColor: module.themeColor,
              inactiveThumbColor: appTheme.earthMedium.withValues(alpha: 0.4),
              inactiveTrackColor: appTheme.creamDark.withValues(alpha: 0.5),
              trackOutlineColor:
                  const WidgetStatePropertyAll(Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 主题选择器 — 水平排列的光泽药丸
  // ═══════════════════════════════════════════════════════════════
  Widget _buildThemeSelector(AppThemeExtension appTheme) {
    final currentTheme = ThemeProvider.instance.currentTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: AppThemeType.values.map((type) {
          final isSelected = currentTheme == type;
          return GestureDetector(
            onTap: () async {
              await ThemeProvider.instance.setTheme(type);
              setState(() {});
            },
            child: AnimatedScale(
              scale: isSelected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // 光泽药丸
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    // 模拟 3D 光泽：左上亮 → 右下暗
                    gradient: LinearGradient(
                      colors: [
                        type.color.withValues(alpha: 0.9),
                        type.color,
                        type.color.withValues(alpha: 0.65),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0.0, 0.45, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      // 外层柔光
                      BoxShadow(
                        color: type.color.withValues(alpha: isSelected ? 0.3 : 0.08),
                        blurRadius: isSelected ? 14 : 6,
                        offset: const Offset(0, 3),
                      ),
                      // 选中时内圈光环
                      if (isSelected)
                        BoxShadow(
                          color: type.color.withValues(alpha: 0.15),
                          blurRadius: 2,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 24)
                      : null,
                ),
                const SizedBox(height: 7),
                Text(type.label,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color:
                            isSelected ? appTheme.earth : appTheme.earthMedium)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 功能列表项
  // ═══════════════════════════════════════════════════════════════
  Widget _buildFunctionItem(
    AppThemeExtension appTheme, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final iconColor = isDestructive ? appTheme.rose : appTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDestructive ? appTheme.rose : appTheme.earth)),
          ),
          Icon(Icons.chevron_right_rounded,
              color: appTheme.earthMedium.withValues(alpha: 0.2), size: 20),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 关于信息项
  // ═══════════════════════════════════════════════════════════════
  Widget _buildAboutItem(
    AppThemeExtension appTheme,
    String title,
    String subtitle, {
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: appTheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon,
              color: appTheme.earthMedium.withValues(alpha: 0.5), size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: appTheme.earth)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12,
                      color: appTheme.earthMedium.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 内部柔和分割线
  // ═══════════════════════════════════════════════════════════════
  Widget _insetDivider(AppThemeExtension appTheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 74),
      child: Divider(
          height: 1, color: appTheme.earthMedium.withValues(alpha: 0.06)),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 数据导入导出（保持不变）
  // ═══════════════════════════════════════════════════════════════

  Future<void> _handleExport() async {
    _showSnackBar('正在导出数据...');
    final result = await _importExport.exportData();
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result.isSuccess) {
      _showSnackBar('已导出到：${result.filePath}');
    } else {
      _showErrorDialog('导出失败', result.error ?? '未知错误');
    }
  }

  Future<void> _handleImport() async {
    final filePath = await _showPathInputDialog();
    if (!mounted || filePath == null) return;

    final preview = _importExport.previewImportFromPath(filePath);
    if (!preview.isReady) {
      _showErrorDialog('导入失败', preview.error ?? '文件格式无效');
      return;
    }

    final confirmed = await _showImportConfirmDialog(
      settingsCount: preview.settingsCount,
      periodRecordsCount: preview.periodRecordsCount,
    );
    if (!mounted || confirmed != true) return;

    _showSnackBar('正在导入数据...');
    final result = await _importExport.executeImport(preview.filePath!);
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result.isSuccess) {
      _showSnackBar(
          '导入成功：${result.settingsCount}项设置、${result.periodRecordsCount}条生理期记录');
      setState(() {});
    } else {
      _showErrorDialog('导入失败', result.error ?? '未知错误');
    }
  }

  Future<String?> _showPathInputDialog() async {
    final appTheme = Theme.of(context).appTheme;
    final defaultDir = await _importExport.getDefaultImportDirectory();
    if (!mounted) return null;
    final ctrl =
        TextEditingController(text: '$defaultDir${Platform.pathSeparator}');

    return showDialog<String>(
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
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: appTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.download_rounded,
                    color: appTheme.primary, size: 28),
              ),
              const SizedBox(height: 18),
              Text('输入备份文件路径',
                  style: TextStyle(
                      fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: appTheme.earth)),
              const SizedBox(height: 18),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '/path/to/my_assistant_backup.json',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(appTheme.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(color: appTheme.earth, fontSize: 14),
              ),
              const SizedBox(height: 22),
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
                    onTap: () => Navigator.pop(ctx, ctrl.text.trim()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [appTheme.primary, appTheme.primaryDark],
                        ),
                        borderRadius: BorderRadius.circular(appTheme.radiusMd),
                      ),
                      child: const Center(
                          child: Text('确认',
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

  Future<bool?> _showImportConfirmDialog({
    required int settingsCount,
    required int periodRecordsCount,
  }) {
    final appTheme = Theme.of(context).appTheme;
    return showDialog<bool>(
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
                  color: appTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.download_rounded,
                    color: appTheme.primary, size: 30),
              ),
              const SizedBox(height: 20),
              Text('确认导入数据？',
                  style: TextStyle(
                      fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: appTheme.earth),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                '将导入 $settingsCount 项设置和 $periodRecordsCount 条生理期记录。\n'
                '已存在的设置和记录将被覆盖，不会影响记账数据。',
                style: TextStyle(
                    fontSize: 14, color: appTheme.earthMedium, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, false),
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
                    onTap: () => Navigator.pop(ctx, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [appTheme.primary, appTheme.primaryDark],
                        ),
                        borderRadius: BorderRadius.circular(appTheme.radiusMd),
                      ),
                      child: const Center(
                          child: Text('确认导入',
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

  void _showErrorDialog(String title, String message) {
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
                child: Icon(Icons.error_outline_rounded,
                    color: appTheme.rose, size: 30),
              ),
              const SizedBox(height: 20),
              Text(title,
                  style: TextStyle(
                      fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: appTheme.earth),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(message,
                  style: TextStyle(
                      fontSize: 14, color: appTheme.earthMedium, height: 1.5),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: appTheme.primary,
                    borderRadius: BorderRadius.circular(appTheme.radiusMd),
                  ),
                  child: const Center(
                      child: Text('确定',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white))),
                ),
              ),
            ],
          ),
        ),
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
          style: TextStyle(color: appTheme.earth, fontWeight: FontWeight.w500)),
      backgroundColor: appTheme.primaryLight,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }
}

// ═════════════════════════════════════════════════════════════════
// 核心组件：深度层级系统
// ═════════════════════════════════════════════════════════════════

/// 卡片深度等级 — 从前景到背景的递进式阴影
enum _CardDepth {
  /// 前景层 — 最强的阴影，视觉上距离用户最近
  foreground,

  /// 中景层 — 中等阴影深度
  midground,

  /// 背景层 — 较浅阴影
  background,

  /// 表面层 — 最轻的阴影，几乎融入背景
  surface,
}

/// 带浮动标题的深度卡片区块
///
/// 核心设计：标题悬浮在卡片上方边缘，产生物理叠加的层次感。
/// 每张卡片根据深度等级使用不同强度的阴影，形成递进式的空间深度。
class _DepthSection extends StatelessWidget {
  final AppThemeExtension appTheme;
  final String title;
  final IconData icon;
  final Color accentColor;
  final _CardDepth depth;
  final Widget? child;
  final List<Widget>? children;

  const _DepthSection({
    required this.appTheme,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.depth,
    this.child,
    this.children,
  });

  @override
  Widget build(BuildContext context) {
    final shadow = _shadowForDepth(appTheme);
    const headerOverlap = 18.0; // 标题下沉到卡片内的距离

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── 卡片主体（下沉，为浮动标题留空间） ──
          Padding(
            padding: const EdgeInsets.only(top: headerOverlap),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              padding: const EdgeInsets.only(top: 16, bottom: 6),
              decoration: BoxDecoration(
                color: appTheme.cardBackground,
                borderRadius: BorderRadius.circular(appTheme.radiusXl),
                boxShadow: shadow,
              ),
              child: child ?? Column(children: children!),
            ),
          ),

          // ── 浮动标题（悬浮在卡片上方） ──
          Positioned(
            top: 0,
            left: 40,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: appTheme.cardBackground,
                borderRadius: BorderRadius.circular(appTheme.radiusMd),
                boxShadow: [
                  BoxShadow(
                    color: appTheme.earth.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 左侧强调色条
                  Container(
                    width: 3,
                    height: 16,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, size: 14, color: accentColor),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: GoogleFonts.dmSans().fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: appTheme.earth,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 根据深度等级返回对应的阴影列表
  List<BoxShadow> _shadowForDepth(AppThemeExtension appTheme) {
    final baseColor = appTheme.earth;
    switch (depth) {
      case _CardDepth.foreground:
        return [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: baseColor.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ];
      case _CardDepth.midground:
        return [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ];
      case _CardDepth.background:
        return [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ];
      case _CardDepth.surface:
        return [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 1),
          ),
        ];
    }
  }
}
