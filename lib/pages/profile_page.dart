import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/settings/settings_service.dart';
import '../core/theme/theme_extension.dart';
import '../shared/foundation/app_typography.dart';
import '../shared/widgets/app_scaffold.dart';
import '../shared/widgets/app_snack_bar.dart';
import '../shared/widgets/section_card.dart';
import '../shared/widgets/settings_list_item.dart';
import '../shared/widgets/user_avatar.dart';

/// 我的页面 — 个人数据概览 + 功能操作中心
class ProfilePageContent extends StatefulWidget {
  const ProfilePageContent({super.key});

  @override
  State<ProfilePageContent> createState() => _ProfilePageContentState();
}

class _ProfilePageContentState extends State<ProfilePageContent> {
  /// 头像最大尺寸（等比压缩到该范围后存储）
  static const int _avatarMaxDim = 320;
  static const int _avatarMaxBytes = 15 * 1024 * 1024;

  String _userName = SettingsService.defaultUserName;
  String? _avatarB64;

  @override
  void initState() {
    super.initState();
    SettingsController.instance.addListener(_onSettingsChanged);
    _applyIdentity();
  }

  @override
  void dispose() {
    SettingsController.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  /// 从 SettingsController 缓存同步用户身份（app 启动经 loadSettings 已载入；
  /// 昵称/头像保存也走同一 controller，故本页与工具箱顶栏共享单一数据源）
  void _applyIdentity() {
    final c = SettingsController.instance;
    _userName = c.userName;
    _avatarB64 = c.avatarB64;
  }

  void _onSettingsChanged() {
    if (mounted) setState(_applyIdentity);
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildUserCard(appTheme),
              const SizedBox(height: 6),
              const SectionLabel(title: '快捷入口'),
              SectionCard(child: _buildFeatureSection()),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ① 用户卡 — 紧凑横排：左头像（可换）＋右昵称（可编辑），占满整行
  // ═══════════════════════════════════════════════════════════
  Widget _buildUserCard(AppThemeExtension appTheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusLg),
        boxShadow: appTheme.cardShadow,
      ),
      child: Row(
        children: [
          // 头像（点击更换）
          UserAvatar(avatarB64: _avatarB64, size: 60, onTap: _onAvatarTap),
          const SizedBox(width: 14),
          // 昵称（点击编辑）
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _editName,
              child: Text(
                _userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: appTheme.earth,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
          // 编辑昵称小按钮
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _editName,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.edit_rounded,
                size: 16,
                color: appTheme.earthMedium.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
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
                leading:
                    Icon(Icons.photo_library_outlined, color: appTheme.primary),
                title: Text('从相册选择',
                    style:
                        AppTypography.bodyMd.copyWith(color: appTheme.earth)),
                onTap: () => Navigator.pop(ctx, 'pick'),
              ),
              if (hasAvatar)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: appTheme.rose),
                  title: Text('移除头像',
                      style:
                          AppTypography.bodyMd.copyWith(color: appTheme.rose)),
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
      await SettingsController.instance.setUserAvatar(b64);
      if (!mounted) return;
      setState(() => _avatarB64 = b64);
      AppSnackBar.show(context, '头像已更新', type: AppSnackBarType.success);
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(context, '无法读取该图片，请更换图片', type: AppSnackBarType.error);
      }
    }
  }

  Future<void> _removeAvatar() async {
    await SettingsController.instance.setUserAvatar('');
    if (!mounted) return;
    setState(() => _avatarB64 = null);
    AppSnackBar.show(context, '已移除头像');
  }

  // ═══════════════════════════════════════════════════════════
  // ④ 快捷入口 — 各模块功能入口
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

  /// 把列表项拼成带分隔线的纵向列表
  Column _toColumn(List<SettingsListItem> items) {
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      children.add(items[i]);
      if (i < items.length - 1) {
        children.add(_buildSeparator(Theme.of(context).appTheme));
      }
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
          child: Icon(Icons.person_rounded, color: appTheme.primary, size: 30),
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
              await SettingsController.instance.setUserName(name);
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
