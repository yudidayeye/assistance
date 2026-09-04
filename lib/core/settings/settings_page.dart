import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../module_system/module_registry.dart';
import '../module_system/tool_module.dart';
import 'settings_service.dart';
import '../storage/database_service.dart';
import '../theme/theme_extension.dart';
import '../theme/theme_provider.dart';
import 'import_export_service.dart';
import 'update_dialog.dart';
import 'update_service.dart';
import '../../shared/widgets/app_snack_bar.dart';
import '../../modules/period_book/services/period_book_service.dart';
import '../../modules/period_tracker/services/period_service.dart';
import '../../modules/vault/services/vault_service.dart';
import '../../modules/vault/services/vault_session.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/settings_list_item.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/foundation/app_typography.dart';
import '../../shared/foundation/app_spacing.dart';

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
  final DatabaseService _db = DatabaseService.instance;
  final ImportExportService _importExport = ImportExportService.instance;
  final UpdateService _updateService = UpdateService.instance;

  String _currentVersion = '';
  bool _isCheckingUpdate = false;
  UpdateInfo? _updateInfo;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _checkUpdate();
  }

  /// 加载当前版本号（本地读取，不请求网络）
  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _currentVersion = packageInfo.version;
        });
      }
    } catch (e) {
      // 忽略，版本号将在检查更新时填充
    }
  }

  /// 检查更新
  Future<void> _checkUpdate() async {
    if (mounted) {
      setState(() => _isCheckingUpdate = true);
    }

    final info = await _updateService.checkForUpdate();

    if (mounted) {
      setState(() {
        _isCheckingUpdate = false;
        _updateInfo = info;
        _currentVersion = info.currentVersion;
      });
    }
  }

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
            '设置',
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
              // ── 模块管理（拖动排序，顺序同步到首页卡片） ──
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

              const SizedBox(height: 10),

              // ── 主题设置 ──
              const SectionLabel(title: '主题设置'),
              SectionCard(child: _buildThemeSelector(appTheme)),

              const SizedBox(height: 10),

              // ── 数据 ──
              const SectionLabel(title: '数据'),
              SectionCard(
                child: Column(children: [
                  SettingsListItem(
                    icon: Icons.download_outlined,
                    title: '导入数据',
                    onTap: _handleImport,
                  ),
                  _buildSeparator(appTheme),
                  SettingsListItem(
                    icon: Icons.upload_outlined,
                    title: '导出数据',
                    onTap: _handleExport,
                  ),
                  _buildSeparator(appTheme),
                  SettingsListItem(
                    icon: Icons.sync_rounded,
                    title: '数据同步',
                    onTap: () => context.push('/sync'),
                  ),
                  _buildSeparator(appTheme),
                  SettingsListItem(
                    icon: Icons.delete_outline_rounded,
                    title: '清除业务数据',
                    onTap: _confirmClearBusinessData,
                    isDestructive: true,
                  ),
                ]),
              ),

              const SizedBox(height: 10),

              // ── 功能 ──
              const SectionLabel(title: '功能'),
              SectionCard(
                child: Column(children: [
                  SettingsListItem(
                    icon: Icons.notifications_outlined,
                    title: '通知管理',
                    onTap: () {},
                  ),
                  _buildSeparator(appTheme),
                  SettingsListItem(
                    icon: Icons.help_outline_rounded,
                    title: '帮助与反馈',
                    onTap: () {},
                  ),
                ]),
              ),

              const SizedBox(height: 10),

              // ── 关于 ──
              const SectionLabel(title: '关于'),
              SectionCard(
                child: Column(children: [
                  _buildVersionItem(appTheme),
                  _buildSeparator(appTheme),
                  SettingsListItem(
                    icon: Icons.lock_outline_rounded,
                    title: '隐私声明',
                    subtitle: '所有数据仅存储在本地',
                  ),
                  _buildSeparator(appTheme),
                  SettingsListItem(
                    icon: Icons.shield_outlined,
                    title: '免责声明',
                    subtitle: '生理期预测仅供参考',
                  ),
                ]),
              ),

              const SizedBox(height: 60),
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
              setState(() {});
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
                    setState(() {});
                  }
                : null,
          ),
        ],
      ),
    );
  }

  /// 模块管理分区标题行 — 左侧「模块管理」，右侧同行标注一次「启用/固定」列表头。
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
            '模块管理',
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

  // ═══════════════════════════════════════════════════════════════
  // 主题选择器 — 扁平纯色圆圈
  // ═══════════════════════════════════════════════════════════════
  Widget _buildThemeSelector(AppThemeExtension appTheme) {
    final currentTheme = ThemeProvider.instance.currentTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: type.color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 2)
                      : Border.all(
                          color: type.color.withValues(alpha: 0), width: 0),
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
                          width: 12,
                          height: 12,
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
              const SizedBox(height: 6),
              Text(type.label,
                  style: AppTypography.caption.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color:
                          isSelected ? appTheme.earth : appTheme.earthMedium)),
            ]),
          );
        }).toList(),
      ),
    );
  }


  // ═══════════════════════════════════════════════════════════════
  // 版本信息项 — 带检查更新功能
  // ═══════════════════════════════════════════════════════════════
  Widget _buildVersionItem(AppThemeExtension appTheme) {
    final hasUpdate = _updateInfo?.hasUpdate ?? false;
    final latestVersion = _updateInfo?.latestVersion;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: appTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(appTheme.radiusMd),
          ),
          child: Icon(Icons.info_outline_rounded,
              color: appTheme.primary, size: 18),
        ),
        AppSpacing.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('版本',
                  style: AppTypography.bodyMd.copyWith(color: appTheme.earth)),
              const SizedBox(height: 2),
              Text('V$_currentVersion',
                  style: AppTypography.caption.copyWith(
                      color: appTheme.earthMedium.withValues(alpha: 0.6))),
            ],
          ),
        ),
        // 更新按钮或状态
        if (_isCheckingUpdate)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: appTheme.earthMedium.withValues(alpha: 0.4),
            ),
          )
        else if (hasUpdate)
          GestureDetector(
            onTap: () => _showUpdateDialog(appTheme),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: appTheme.sage.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(appTheme.radiusXl),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.system_update_rounded,
                      color: appTheme.sage, size: 14),
                  AppSpacing.w4,
                  Text(
                    '更新 V$latestVersion',
                    style: AppTypography.label.copyWith(
                      color: appTheme.sage,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          GestureDetector(
            onTap: _checkUpdate,
            child: Text(
              '检查更新',
              style: AppTypography.caption.copyWith(
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
            ),
          ),
      ]),
    );
  }

  /// 显示更新弹窗
  ///
  /// Android 且能匹配到本机架构的 APK 时，走应用内下载 + 安装的 [UpdateDialog]；
  /// 否则（iOS / 无匹配产物）降级为原有外链跳转 Release 页面的弹窗。
  Future<void> _showUpdateDialog(AppThemeExtension appTheme) async {
    final info = _updateInfo;
    if (info == null || !info.hasUpdate) return;

    // 尝试匹配本机架构对应的 APK
    ReleaseAsset? asset;
    if (Platform.isAndroid) {
      final abis = await _updateService.getSupportedAbis();
      asset = UpdateService.selectAsset(info.assets, abis);
    } else if (Platform.isWindows) {
      // Windows 桌面版：匹配 .exe 安装包
      asset = UpdateService.selectWindowsAsset(info.assets);
    }

    if (!mounted) return;
    if (asset != null) {
      // 应用内更新：展示更新内容 + 下载进度 + 自动安装
      await UpdateDialog.show(context, info: info, asset: asset);
    } else {
      // 降级：跳转 GitHub Release 页面手动下载
      _showFallbackUpdateDialog(appTheme, info);
    }
  }

  /// 降级更新弹窗：跳转外部浏览器打开 Release 页面（iOS 或无匹配 APK）
  void _showFallbackUpdateDialog(AppThemeExtension appTheme, UpdateInfo info) {
    showDialog(
      context: context,
      barrierColor: appTheme.surfaceOverlay,
      builder: (ctx) => AlertDialog(
        backgroundColor: appTheme.cream,
        icon: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: appTheme.sage.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(appTheme.radiusMd),
          ),
          child: Icon(Icons.system_update_rounded,
              color: appTheme.sage, size: 26),
        ),
        title: Text(
          '发现新版本',
          style: AppTypography.displayMd.copyWith(color: appTheme.earth),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'V${info.currentVersion} → V${info.latestVersion}',
              style: AppTypography.bodyMd.copyWith(
                fontWeight: FontWeight.w600,
                color: appTheme.sage,
              ),
              textAlign: TextAlign.center,
            ),
            if (info.releaseNotes != null &&
                info.releaseNotes!.isNotEmpty) ...[
              AppSpacing.h16,
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: appTheme.cardBackground,
                  borderRadius: BorderRadius.circular(appTheme.radiusMd),
                ),
                child: Text(
                  info.releaseNotes!.length > 200
                      ? '${info.releaseNotes!.substring(0, 200)}...'
                      : info.releaseNotes!,
                  style: AppTypography.caption.copyWith(
                    color: appTheme.earthMedium,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('稍后再说', style: TextStyle(color: appTheme.earthMedium)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (info.releaseUrl != null) {
                await _updateService.openReleasePage(info.releaseUrl!);
              }
            },
            child: Text('前往更新', style: TextStyle(color: appTheme.sage)),
          ),
        ],
      ),
    );
  }


  // ═══════════════════════════════════════════════════════════════
  // 内部柔和分割线
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSeparator(AppThemeExtension appTheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 66),
      child: Divider(
          height: 0, thickness: 0.5, color: appTheme.earthMedium.withValues(alpha: 0.07)),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 数据导入导出
  // ═══════════════════════════════════════════════════════════════

  Future<void> _handleExport() async {
    // 生成默认文件名
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
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
      bookPeriodsCount: preview.bookPeriodsCount,
      bookStagesCount: preview.bookStagesCount,
      bookAdditionsCount: preview.bookAdditionsCount,
      bookExpensesCount: preview.bookExpensesCount,
      bookLargeAdditionsCount: preview.bookLargeAdditionsCount,
      bookLargeExpensesCount: preview.bookLargeExpensesCount,
    );
    if (!mounted || confirmed != true) return;

    _showSnackBar('正在导入数据...');
    final result = await _importExport.executeImport(preview.filePath!);
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result.isSuccess) {
      _showSnackBar(
          '导入成功：${result.settingsCount}项设置、${result.periodRecordsCount}条生理期记录、'
          '${result.bookPeriodsCount}个周期、${result.bookStagesCount}个阶段、'
          '${result.bookAdditionsCount}条追加、${result.bookExpensesCount}条支出、'
          '${result.bookLargeAdditionsCount}条大额追加、${result.bookLargeExpensesCount}条大额支出');
      if (result.vaultImportSkipped) {
        _showErrorDialog(
          '密码保险箱数据未导入',
          '该备份的加密密钥与当前保险箱不一致（可能来自另一个主密码，或保险箱被重新初始化过）。\n\n'
              '为避免密码无法解密，本次未导入保险箱数据，其余数据已正常导入。\n'
              '如需恢复该备份的保险箱数据，请先在设置中「清除业务数据」，再重新导入。',
        );
      }
      // 导入可能改变模块启用/固定状态，重载并通知，让底部导航/工具箱立即反映
      await SettingsController.instance.reload();
      setState(() {});
    } else {
      _showErrorDialog('导入失败', result.error ?? '未知错误');
    }
  }

  Future<bool?> _showImportConfirmDialog({
    required int settingsCount,
    required int periodRecordsCount,
    required int bookPeriodsCount,
    required int bookStagesCount,
    required int bookAdditionsCount,
    required int bookExpensesCount,
    required int bookLargeAdditionsCount,
    required int bookLargeExpensesCount,
  }) {
    final appTheme = Theme.of(context).appTheme;
    return showDialog<bool>(
      context: context,
      barrierColor: appTheme.surfaceOverlay,
      builder: (ctx) => AlertDialog(
        backgroundColor: appTheme.cream,
        icon: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: appTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(appTheme.radiusMd),
          ),
          child: Icon(Icons.download_rounded,
              color: appTheme.primary, size: 26),
        ),
        title: Text(
          '确认导入数据？',
          style: AppTypography.displayMd.copyWith(
            color: appTheme.earth,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          '将导入 $settingsCount 项设置、$periodRecordsCount 条生理期记录'
          '、$bookPeriodsCount 个周期、$bookStagesCount 个阶段'
          '、$bookAdditionsCount 条追加、$bookExpensesCount 条支出'
          '、$bookLargeAdditionsCount 条大额追加、$bookLargeExpensesCount 条大额支出。\n'
          '已存在的设置和记录将被覆盖。',
          style: AppTypography.bodyMd.copyWith(
              color: appTheme.earthMedium, height: 1.5),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: appTheme.earthMedium)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('确认导入', style: TextStyle(color: appTheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    final appTheme = Theme.of(context).appTheme;
    showDialog(
      context: context,
      barrierColor: appTheme.surfaceOverlay,
      builder: (ctx) => AlertDialog(
        backgroundColor: appTheme.cream,
        icon: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: appTheme.rose.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(appTheme.radiusMd),
          ),
          child: Icon(Icons.error_outline_rounded,
              color: appTheme.rose, size: 26),
        ),
        title: Text(title,
            style: AppTypography.displayMd.copyWith(color: appTheme.earth),
            textAlign: TextAlign.center),
        content: Text(message,
            style: AppTypography.bodyMd.copyWith(
                color: appTheme.earthMedium, height: 1.5),
            textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('确定', style: TextStyle(color: appTheme.primary)),
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
      builder: (ctx) => AlertDialog(
        backgroundColor: appTheme.cream,
        icon: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: appTheme.rose.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(appTheme.radiusMd),
          ),
          child: Icon(Icons.warning_amber_rounded,
              color: appTheme.rose, size: 26),
        ),
        title: Text(
          '确认清除所有业务数据？',
          style: AppTypography.displayMd.copyWith(color: appTheme.earth),
          textAlign: TextAlign.center,
        ),
        content: Text(
          '此操作将删除所有周期记账和生理期记录，但保留设置和主题偏好。',
          style: AppTypography.bodyMd.copyWith(
              color: appTheme.earthMedium, height: 1.5),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: appTheme.earthMedium)),
          ),
          TextButton(
            onPressed: () async {
              await _db.clearAllBusinessData();
              if (!context.mounted) return;
              Navigator.pop(ctx);
              // 通知各模块刷新首页卡片
              PeriodBookService.instance.notifyChanged();
              PeriodService.instance.notifyChanged();
              VaultService.instance.notifyChanged();
              // 清除保险箱会话密钥
              VaultSession.instance.lock();
              _showSnackBar('业务数据已清除');
            },
            child: Text('确认清除', style: TextStyle(color: appTheme.rose)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    AppSnackBar.show(context, message);
  }
}

