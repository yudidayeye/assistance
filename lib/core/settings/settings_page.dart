import 'package:file_picker/file_picker.dart';
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

/// 全局设置页面 — 简洁扁平风格
///
/// 用形状和留白定义层级，而非阴影。
/// 大圆角卡片、柔和色彩、清晰的信息层级，
/// 强调信息存在感而非可点击感，营造安静舒适的浏览体验。
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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 头部 ──
              _buildHeader(context, appTheme),

              // ── 模块管理 ──
              _SectionLabel(
                appTheme: appTheme,
                title: '模块管理',
              ),
              _SectionCard(
                appTheme: appTheme,
                child: Column(
                  children: modules.asMap().entries.map((entry) {
                    final index = entry.key;
                    final module = entry.value;
                    final isLast = index == modules.length - 1;
                    return Column(children: [
                      _buildModuleItem(appTheme, module),
                      if (!isLast) _buildSeparator(appTheme),
                    ]);
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              // ── 主题设置 ──
              _SectionLabel(
                appTheme: appTheme,
                title: '主题设置',
              ),
              _SectionCard(
                appTheme: appTheme,
                child: _buildThemeSelector(appTheme),
              ),

              const SizedBox(height: 16),

              // ── 数据 ──
              _SectionLabel(
                appTheme: appTheme,
                title: '数据',
              ),
              _SectionCard(
                appTheme: appTheme,
                child: Column(children: [
                  _buildFunctionItem(appTheme,
                      icon: Icons.download_outlined,
                      label: '导入数据',
                      onTap: _handleImport),
                  _buildSeparator(appTheme),
                  _buildFunctionItem(appTheme,
                      icon: Icons.upload_outlined,
                      label: '导出数据',
                      onTap: _handleExport),
                  _buildSeparator(appTheme),
                  _buildFunctionItem(appTheme,
                      icon: Icons.delete_outline_rounded,
                      label: '清除业务数据',
                      onTap: _confirmClearBusinessData,
                      isDestructive: true),
                ]),
              ),

              const SizedBox(height: 16),

              // ── 功能 ──
              _SectionLabel(
                appTheme: appTheme,
                title: '功能',
              ),
              _SectionCard(
                appTheme: appTheme,
                child: Column(children: [
                  _buildFunctionItem(appTheme,
                      icon: Icons.notifications_outlined,
                      label: '通知管理',
                      onTap: () {}),
                  _buildSeparator(appTheme),
                  _buildFunctionItem(appTheme,
                      icon: Icons.help_outline_rounded,
                      label: '帮助与反馈',
                      onTap: () {}),
                ]),
              ),

              const SizedBox(height: 16),

              // ── 关于 ──
              _SectionLabel(
                appTheme: appTheme,
                title: '关于',
              ),
              _SectionCard(
                appTheme: appTheme,
                child: Column(children: [
                  _buildAboutItem(appTheme, '版本', 'V1.0.0',
                      icon: Icons.info_outline_rounded),
                  _buildSeparator(appTheme),
                  _buildAboutItem(appTheme, '隐私声明', '所有数据仅存储在本地',
                      icon: Icons.lock_outline_rounded),
                  _buildSeparator(appTheme),
                  _buildAboutItem(appTheme, '免责声明', '生理期预测仅供参考',
                      icon: Icons.shield_outlined),
                ]),
              ),

              const SizedBox(height: 80),
            ],
          ),
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
      padding: EdgeInsets.fromLTRB(24, safeTop + 16, 24, 24),
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
  // 模块管理 — 扁平行
  // ═══════════════════════════════════════════════════════════════
  Widget _buildModuleItem(AppThemeExtension appTheme, ToolModule module) {
    final enabled = _settings.isModuleEnabled(module.moduleId);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: module.themeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: module.icon.build(size: 22, color: module.themeColor),
            ),
          ),
          const SizedBox(width: 14),
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
                const SizedBox(height: 4),
                Text(enabled ? '已启用' : '已禁用',
                    style: TextStyle(
                        fontSize: 13,
                        color: enabled
                            ? appTheme.sage.withValues(alpha: 0.8)
                            : appTheme.earthMedium.withValues(alpha: 0.5))),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (val) async {
              await _controller.setModuleEnabled(module.moduleId, val);
              setState(() {});
            },
            activeTrackColor: module.themeColor.withValues(alpha: 0.12),
            activeThumbColor: module.themeColor,
            inactiveThumbColor:
                appTheme.earthMedium.withValues(alpha: 0.25),
            inactiveTrackColor:
                appTheme.creamDark.withValues(alpha: 0.35),
            trackOutlineColor:
                const WidgetStatePropertyAll(Colors.transparent),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 主题选择器 — 扁平纯色圆圈
  // ═══════════════════════════════════════════════════════════════
  Widget _buildThemeSelector(AppThemeExtension appTheme) {
    final currentTheme = ThemeProvider.instance.currentTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: AppThemeType.values.map((type) {
          final isSelected = currentTheme == type;
          return GestureDetector(
            onTap: () async {
              await ThemeProvider.instance.setTheme(type);
              setState(() {});
            },
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: type.color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 2.5)
                      : Border.all(color: type.color.withValues(alpha: 0), width: 0),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: type.color.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: type.color.withValues(alpha: 0.2),
                              width: 2,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 8),
              Text(type.label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
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
  // 功能列表项 — 无 chevron，柔和字重
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    fontWeight: FontWeight.w500,
                    color: isDestructive ? appTheme.rose : appTheme.earth)),
          ),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 关于信息项 — 柔和字重
  // ═══════════════════════════════════════════════════════════════
  Widget _buildAboutItem(
    AppThemeExtension appTheme,
    String title,
    String subtitle, {
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: appTheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon,
              color: appTheme.earthMedium.withValues(alpha: 0.45), size: 20),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: appTheme.earth)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 13,
                    color: appTheme.earthMedium.withValues(alpha: 0.6))),
          ],
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 内部柔和分割线
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSeparator(AppThemeExtension appTheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 78),
      child: Divider(
          height: 1,
          color: appTheme.earthMedium.withValues(alpha: 0.07)),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 数据导入导出
  // ═══════════════════════════════════════════════════════════════

  Future<void> _handleExport() async {
    // 生成默认文件名
    final now = DateTime.now();
    final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final defaultFileName = 'my_assistant_backup_$stamp.json';

    _showSnackBar('正在准备导出数据...');

    // 1. 先生成 JSON bytes
    final bytes = await _importExport.generateExportBytes();
    if (!mounted) return;

    // 2. 弹出文件保存对话框（使用 SAF，自动处理权限）
    final filePath = await FilePicker.saveFile(
      dialogTitle: '选择导出保存位置',
      fileName: defaultFileName,
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (filePath == null) return; // 用户取消

    _showSnackBar('已导出到：$filePath');
  }

  Future<void> _handleImport() async {
    // 1. 弹出文件选择器，限定 .json
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );
    if (picked == null || picked.files.isEmpty) return;

    final filePath = picked.files.single.path;
    if (filePath == null) {
      _showErrorDialog('导入失败', '无法获取文件路径');
      return;
    }

    // 2. 预览校验
    final preview = _importExport.previewImportFromPath(filePath);
    if (!preview.isReady) {
      _showErrorDialog('导入失败', preview.error ?? '文件格式无效');
      return;
    }

    // 3. 确认弹窗
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
            borderRadius: BorderRadius.circular(appTheme.radiusMd),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: appTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(appTheme.radiusMd),
                ),
                child: Icon(Icons.download_rounded,
                    color: appTheme.primary, size: 26),
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
                        borderRadius:
                            BorderRadius.circular(appTheme.radiusMd),
                      ),
                      child: Center(
                          child: Text('取消',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: appTheme.earthLight))),
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
                        color: appTheme.primary,
                        borderRadius:
                            BorderRadius.circular(appTheme.radiusMd),
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
            borderRadius: BorderRadius.circular(appTheme.radiusMd),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: appTheme.rose.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(appTheme.radiusMd),
                ),
                child: Icon(Icons.error_outline_rounded,
                    color: appTheme.rose, size: 26),
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
            borderRadius: BorderRadius.circular(appTheme.radiusMd),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: appTheme.rose.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(appTheme.radiusMd),
                ),
                child: Icon(Icons.warning_amber_rounded,
                    color: appTheme.rose, size: 26),
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
                        borderRadius:
                            BorderRadius.circular(appTheme.radiusMd),
                      ),
                      child: Center(
                          child: Text('取消',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: appTheme.earthLight))),
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
                        borderRadius:
                            BorderRadius.circular(appTheme.radiusMd),
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
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }
}

// ═════════════════════════════════════════════════════════════════
// 扁平组件：分区标签 + 卡片容器
// ═════════════════════════════════════════════════════════════════

/// 分区标签 — 强调色竖条 + 文字，置于卡片上方
class _SectionLabel extends StatelessWidget {
  final AppThemeExtension appTheme;
  final String title;

  const _SectionLabel({
    required this.appTheme,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: GoogleFonts.dmSans().fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: appTheme.earthMedium,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// 扁平卡片容器 — 统一的大圆角、极轻阴影、细微边框
class _SectionCard extends StatelessWidget {
  final AppThemeExtension appTheme;
  final Widget child;

  const _SectionCard({
    required this.appTheme,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: appTheme.cardShadow,
        border: Border.all(
          color: appTheme.cardBorder,
          width: 0.5,
        ),
      ),
      child: child,
    );
  }
}
