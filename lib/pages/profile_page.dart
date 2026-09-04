import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/module_system/module_registry.dart';
import '../core/module_system/module_summary.dart';
import '../core/module_system/tool_module.dart';
import '../core/settings/settings_service.dart';
import '../core/storage/database_service.dart';
import '../core/theme/theme_extension.dart';
import '../core/theme/theme_provider.dart';
import '../modules/period_book/services/period_book_service.dart';
import '../modules/period_tracker/services/period_service.dart';
import '../modules/vault/services/vault_session.dart';
import '../modules/vault/services/vault_service.dart';
import '../shared/foundation/app_typography.dart';
import '../shared/widgets/app_scaffold.dart';
import '../shared/widgets/app_snack_bar.dart';
import '../shared/widgets/section_card.dart';
import '../shared/widgets/settings_list_item.dart';

/// 我的页面 — 个人数据概览 + 功能操作中心
class ProfilePageContent extends StatefulWidget {
  const ProfilePageContent({super.key});

  @override
  State<ProfilePageContent> createState() => _ProfilePageContentState();
}

class _ProfilePageContentState extends State<ProfilePageContent>
    with WidgetsBindingObserver {
  /// 我的工具固定展示顺序
  static const List<String> _toolModuleIds = [
    'period_book',
    'period_tracker',
    'vault',
  ];

  /// 头像最大尺寸（等比压缩到该范围后存储）
  static const int _avatarMaxDim = 320;
  static const int _avatarMaxBytes = 15 * 1024 * 1024;

  String _userName = '用户';
  String? _avatarB64;
  String _version = '';

  /// 各工具模块的动态摘要（key = moduleId）
  final Map<String, ModuleSummary> _summaries = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 订阅模块数据变更（新增/删除后刷新摘要）
    PeriodBookService.instance.addListener(_onModuleData);
    PeriodService.instance.addListener(_onModuleData);
    VaultService.instance.addListener(_onModuleData);
    // 订阅设置变更（导入 / 模块启停 / 主题重载后刷新身份与摘要）
    SettingsController.instance.addListener(_onSettingsChanged);
    _loadVersion();
    _loadAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PeriodBookService.instance.removeListener(_onModuleData);
    PeriodService.instance.removeListener(_onModuleData);
    VaultService.instance.removeListener(_onModuleData);
    SettingsController.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  /// 保险箱在切后台时自动锁定，回到前台后刷新按钮状态相关 UI
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  // ───────────────────────────────────────────────────────────
  // 数据加载
  // ───────────────────────────────────────────────────────────

  /// 参数化读取 app_settings 单键（收敛原裸 rawQuery 写法）
  Future<String?> _readSetting(String key) async {
    final rows = await DatabaseService.instance.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = rows.first['value'] as String?;
    return (value == null || value.isEmpty) ? null : value;
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } catch (_) {
      // 忽略：无法读取版本号时不展示
    }
  }

  Future<void> _loadAll() async {
    final name = await _readSetting('user_name');
    final avatar = await _readSetting('user_avatar');
    await _loadModuleSummaries();
    if (!mounted) return;
    setState(() {
      _userName = name ?? '用户';
      _avatarB64 = avatar;
    });
  }

  Future<void> _loadModuleSummaries() async {
    final results = <String, ModuleSummary>{};
    for (final moduleId in _toolModuleIds) {
      final module = ModuleRegistry.instance.getModule(moduleId);
      if (module == null) continue;
      results[moduleId] = await module.getSummary();
    }
    if (!mounted) return;
    setState(() => _summaries
      ..clear()
      ..addAll(results));
  }

  /// 模块数据变化 → 仅重读摘要（轻量）
  void _onModuleData() {
    _loadModuleSummaries();
  }

  /// 设置变化（模块启停 / 导入重载）→ 身份与摘要都可能有变
  void _onSettingsChanged() {
    _loadAll();
  }

  /// 当前启用的工具模块列表（禁用模块不显示），顺序固定
  List<ToolModule> _enabledTools() {
    final tools = <ToolModule>[];
    for (final moduleId in _toolModuleIds) {
      final module = ModuleRegistry.instance.getModule(moduleId);
      if (module != null && SettingsService.instance.isModuleEnabled(moduleId)) {
        tools.add(module);
      }
    }
    return tools;
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    return AppScrollScaffold(
      slivers: [
        // ── 头部 ──
        SliverAppBar(
          pinned: true,
          backgroundColor: appTheme.cream,
          elevation: 0,
          centerTitle: false,
          title: Text(
            '我的',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: () => context.push('/settings'),
                icon: const Icon(Icons.settings_outlined),
                color: appTheme.earth,
                iconSize: 20,
              ),
            ),
          ],
        ),

        // ── 页面内容 ──
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserCard(appTheme),

              const SizedBox(height: 6),
              if (_enabledTools().isNotEmpty) ...[
                const SectionLabel(title: '我的工具'),
                SectionCard(child: _buildToolsSection(appTheme)),
                const SizedBox(height: 16),
              ],

              const SectionLabel(title: '快捷操作'),
              SectionCard(child: _buildQuickActions(appTheme)),
              const SizedBox(height: 16),

              const SectionLabel(title: '功能'),
              SectionCard(child: _buildFeatureSection()),
              const SizedBox(height: 16),

              const SectionLabel(title: '设置'),
              SectionCard(child: _buildSettingsSection(appTheme)),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ① 用户卡片 — 头像（可换）+ 昵称（可编辑）
  // ═══════════════════════════════════════════════════════════
  Widget _buildUserCard(AppThemeExtension appTheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusXl),
        boxShadow: appTheme.cardShadow,
      ),
      child: Column(
        children: [
          // 头像 — 双层环形渐变；已设头像时内圆展示图片
          GestureDetector(
            onTap: _onAvatarTap,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    appTheme.primary.withValues(alpha: 0.18),
                    appTheme.primaryLight.withValues(alpha: 0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(child: _buildAvatarInner(appTheme)),
            ),
          ),
          const SizedBox(height: 18),
          // 昵称 + 编辑提示
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _editName,
            child: Column(
              children: [
                Text(
                  _userName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: appTheme.earth,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_rounded,
                        size: 14,
                        color: appTheme.earthMedium.withValues(alpha: 0.5)),
                    const SizedBox(width: 6),
                    Text(
                      '点击编辑昵称 · 点按头像可更换',
                      style: TextStyle(
                        fontSize: 13,
                        color: appTheme.earthMedium.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarInner(AppThemeExtension appTheme) {
    final avatar = _avatarB64;
    if (avatar != null) {
      try {
        final bytes = base64Decode(avatar);
        return ClipOval(
          child: SizedBox(
            width: 64,
            height: 64,
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildDefaultAvatar(appTheme),
            ),
          ),
        );
      } catch (_) {
        // base64 数据异常时回退默认头像
      }
    }
    return _buildDefaultAvatar(appTheme);
  }

  /// 默认人形头像（无自定义头像 / 头像数据异常时展示）
  Widget _buildDefaultAvatar(AppThemeExtension appTheme) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: appTheme.primary.withValues(alpha: 0.12),
      ),
      child: Icon(Icons.person_rounded, color: appTheme.primary, size: 34),
    );
  }

  /// 头像操作：从相册选择 / 移除
  Future<void> _onAvatarTap() async {
    final appTheme = Theme.of(context).appTheme;
    final hasAvatar = _avatarB64 != null;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: appTheme.surfaceOverlay,
      builder: (ctx) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: appTheme.cardBackground,
          borderRadius: BorderRadius.circular(appTheme.radiusLg),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  '更换头像',
                  style: AppTypography.bodyMd.copyWith(color: appTheme.earth),
                ),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined,
                    color: appTheme.primary),
                title: Text('从相册选择',
                    style: AppTypography.bodyMd
                        .copyWith(color: appTheme.earth)),
                onTap: () => Navigator.pop(ctx, 'pick'),
              ),
              if (hasAvatar)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: appTheme.rose),
                  title: Text('移除头像',
                      style: AppTypography.bodyMd
                          .copyWith(color: appTheme.rose)),
                  onTap: () => Navigator.pop(ctx, 'remove'),
                ),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'pick') {
      await _pickAvatar();
    } else if (action == 'remove') {
      await _removeAvatar();
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (file == null || bytes == null) return;
      if (!mounted) return;

      if (bytes.length > _avatarMaxBytes) {
        AppSnackBar.show(context, '图片过大，请选择 15MB 以内的图片',
            type: AppSnackBarType.error);
        return;
      }

      // 等比压缩到 ≤320px，避免超大 base64 进数据库
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: _avatarMaxDim,
        targetHeight: _avatarMaxDim,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      codec.dispose();
      frame.image.dispose();
      if (data == null) return;

      final b64 = base64Encode(data.buffer.asUint8List());
      await DatabaseService.instance.upsertSetting('user_avatar', b64);
      if (!mounted) return;
      setState(() => _avatarB64 = b64);
      AppSnackBar.show(context, '头像已更新', type: AppSnackBarType.success);
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(context, '无法读取该图片，请更换图片',
            type: AppSnackBarType.error);
      }
    }
  }

  Future<void> _removeAvatar() async {
    await DatabaseService.instance.upsertSetting('user_avatar', '');
    if (!mounted) return;
    setState(() => _avatarB64 = null);
    AppSnackBar.show(context, '已移除头像');
  }

  // ═══════════════════════════════════════════════════════════
  // ② 我的工具 — 三模块摘要行
  // ═══════════════════════════════════════════════════════════
  Widget _buildToolsSection(AppThemeExtension appTheme) {
    final tools = _enabledTools();
    final children = <Widget>[];
    for (var i = 0; i < tools.length; i++) {
      children.add(_buildToolTile(appTheme, tools[i]));
      if (i < tools.length - 1) children.add(_buildSeparator(appTheme, left: 70));
    }
    return Column(children: children);
  }

  Widget _buildToolTile(AppThemeExtension appTheme, ToolModule module) {
    final color = module.themeColor;
    final summary = _summaries[module.moduleId];

    return InkWell(
      onTap: () => context.push('/${module.moduleId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // 模块图标
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(appTheme.radiusSm),
              ),
              child: Center(
                child: module.icon.build(size: 20, color: color),
              ),
            ),
            const SizedBox(width: 12),
            // 名称 + 摘要
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.displayName,
                    style: AppTypography.bodyMd.copyWith(
                      color: appTheme.earth,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (summary?.line1 != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      summary!.line1,
                      style: AppTypography.caption.copyWith(
                        color: appTheme.earthMedium,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (summary?.line2 != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      summary!.line2!,
                      style: AppTypography.caption.copyWith(
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
            Icon(Icons.chevron_right_rounded,
                size: 18,
                color: appTheme.earthMedium.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ③ 快捷操作 — 高频动作按钮组
  // ═══════════════════════════════════════════════════════════
  Widget _buildQuickActions(AppThemeExtension appTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Row(
        children: [
          _buildQuickAction(
            appTheme,
            icon: Icons.favorite_outline_rounded,
            iconColor: appTheme.rose,
            label: '记录经期',
            onTap: () => context.push('/period_tracker'),
          ),
          _buildQuickAction(
            appTheme,
            icon: Icons.account_balance_wallet_outlined,
            iconColor: appTheme.sage,
            label: '记账',
            onTap: _goToBook,
          ),
          _buildQuickAction(
            appTheme,
            icon: Icons.shield_outlined,
            iconColor: appTheme.primary,
            label: '保险箱',
            onTap: _handleVaultAction,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    AppThemeExtension appTheme, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: appTheme.earth,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 记账：有进行中的周期进详情，否则引导新建周期
  Future<void> _goToBook() async {
    final period = await PeriodBookService.instance.getOngoingPeriod();
    if (!mounted) return;
    if (period == null) {
      context.push('/period_book/new');
    } else {
      context.push('/period_book');
    }
  }

  /// 保险箱动作：未设主密码→引导设置；已锁定→引导解锁；已解锁→立即锁定
  Future<void> _handleVaultAction() async {
    final hasMaster = await VaultService.instance.hasMasterPassword();
    if (!mounted) return;
    if (!hasMaster) {
      AppSnackBar.show(context, '保险箱尚未设置主密码');
      context.push('/vault');
      return;
    }
    if (VaultSession.instance.isLocked) {
      AppSnackBar.show(context, '保险箱已锁定，请先解锁');
      context.push('/vault');
      return;
    }
    VaultSession.instance.lock();
    AppSnackBar.show(context, '保险箱已锁定', type: AppSnackBarType.success);
  }

  // ═══════════════════════════════════════════════════════════
  // ④ 功能 — 统计与数据入口
  // ═══════════════════════════════════════════════════════════
  Widget _buildFeatureSection() {
    final items = <SettingsListItem>[
      SettingsListItem(
        icon: Icons.query_stats_rounded,
        title: '生理期统计',
        onTap: () => context.push('/period_tracker/stats'),
      ),
      SettingsListItem(
        icon: Icons.bar_chart_rounded,
        title: '记账历史',
        onTap: () => context.push('/period_book/history'),
      ),
      SettingsListItem(
        icon: Icons.sync_rounded,
        title: '数据同步',
        subtitle: '局域网设备间迁移数据',
        onTap: () => context.push('/sync'),
      ),
    ];
    return _toColumn(items);
  }

  // ═══════════════════════════════════════════════════════════
  // ⑤ 设置 — 轻量摘要入口（重型配置仍留在 /settings）
  // ═══════════════════════════════════════════════════════════
  Widget _buildSettingsSection(AppThemeExtension appTheme) {
    final theme = ThemeProvider.instance.currentTheme;
    final items = <SettingsListItem>[
      SettingsListItem(
        icon: Icons.palette_outlined,
        title: '主题外观',
        subtitle: theme.label,
        trailing: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: theme.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: appTheme.earthMedium.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
        onTap: () => context.push('/settings'),
      ),
      SettingsListItem(
        icon: Icons.privacy_tip_outlined,
        title: '隐私声明',
        subtitle: '所有数据仅存储在本地',
        onTap: () => context.push('/settings'),
      ),
      SettingsListItem(
        icon: Icons.info_outline_rounded,
        title: '关于',
        subtitle: _version.isEmpty ? null : '版本 $_version',
        onTap: () => context.push('/settings'),
      ),
    ];
    return _toColumn(items);
  }

  /// 把列表项拼成带分隔线的纵向列表
  Column _toColumn(List<SettingsListItem> items) {
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      children.add(items[i]);
      if (i < items.length - 1) children.add(_buildSeparator(Theme.of(context).appTheme));
    }
    return Column(children: children);
  }

  // ═══════════════════════════════════════════════════════════
  // 工具
  // ═══════════════════════════════════════════════════════════
  Widget _buildSeparator(AppThemeExtension appTheme, {double left = 66}) {
    return Padding(
      padding: EdgeInsets.only(left: left),
      child: Divider(
        height: 0,
        thickness: 0.5,
        color: appTheme.earthMedium.withValues(alpha: 0.07),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 编辑昵称弹窗
  // ═══════════════════════════════════════════════════════════
  Future<void> _editName() async {
    final appTheme = Theme.of(context).appTheme;
    final ctrl = TextEditingController(text: _userName);

    await showDialog(
      context: context,
      barrierColor: appTheme.surfaceOverlay,
      builder: (ctx) => AlertDialog(
        backgroundColor: appTheme.cream,
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: appTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(appTheme.radiusLg),
          ),
          child: Icon(Icons.person_rounded,
              color: appTheme.primary, size: 30),
        ),
        title: Text(
          '编辑昵称',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: appTheme.earth,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '输入昵称',
                filled: true,
                fillColor: appTheme.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(appTheme.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(color: appTheme.earth, fontSize: 15),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: appTheme.earthMedium)),
          ),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              await DatabaseService.instance
                  .upsertSetting('user_name', name);
              if (mounted) setState(() => _userName = name);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('保存', style: TextStyle(color: appTheme.primary)),
          ),
        ],
      ),
    );
  }
}
