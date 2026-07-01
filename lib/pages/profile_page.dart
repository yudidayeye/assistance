import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/module_system/module_registry.dart';
import '../core/module_system/module_summary.dart';
import '../core/module_system/tool_module.dart';
import '../core/storage/database_service.dart';
import '../core/theme/theme_extension.dart';
import '../core/settings/settings_service.dart';

/// 我的页面 — 用户中心 + 模块概览（简洁扁平风格）
class ProfilePageContent extends StatefulWidget {
  const ProfilePageContent({super.key});

  @override
  State<ProfilePageContent> createState() => _ProfilePageContentState();
}

class _ProfilePageContentState extends State<ProfilePageContent> {
  String _userName = '用户';
  List<_ModuleSnapshot> _moduleSnapshots = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // 加载用户名
    final rows = await DatabaseService.instance
        .rawQuery("SELECT value FROM app_settings WHERE key = 'user_name'");
    if (rows.isNotEmpty && mounted) {
      setState(() => _userName = rows.first['value'] as String);
    }

    // 加载已启用模块的摘要
    final snapshots = <_ModuleSnapshot>[];
    for (final mod in ModuleRegistry.instance.allModules) {
      if (SettingsService.instance.isModuleEnabled(mod.moduleId)) {
        try {
          final summary = await mod.getSummary();
          snapshots.add(_ModuleSnapshot(
            moduleId: mod.moduleId,
            displayName: mod.displayName,
            icon: mod.icon,
            themeColor: mod.themeColor,
            summary: summary,
          ));
        } catch (_) {}
      }
    }
    if (mounted) {
      setState(() => _moduleSnapshots = snapshots);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: appTheme.scaffoldGradient),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── 头部 ──
            SliverToBoxAdapter(
              child: _buildHeader(appTheme),
            ),

            // ── 用户卡片（页面焦点） ──
            SliverToBoxAdapter(
              child: _buildUserCard(appTheme),
            ),

            // ── 模块摘要卡片 ──
            ..._moduleSnapshots.map((snap) {
              return SliverToBoxAdapter(
                child: _buildModuleSnapshotCard(appTheme, snap),
              );
            }),

            // ── 底部信息 ──
            SliverToBoxAdapter(
              child: _buildFooter(appTheme),
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
  Widget _buildHeader(AppThemeExtension appTheme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.of(context).padding.top + 16, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '我的',
            style: TextStyle(
              fontFamily: GoogleFonts.dmSans().fontFamily,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: appTheme.earth,
              letterSpacing: -0.3,
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/settings'),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: appTheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(appTheme.radiusMd),
              ),
              child: Icon(Icons.settings_outlined,
                  color: appTheme.earthMedium, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 用户卡片 — 页面焦点，居中布局
  // ═══════════════════════════════════════════════════════════════
  Widget _buildUserCard(AppThemeExtension appTheme) {
    return GestureDetector(
      onTap: _editName,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              appTheme.cardBackground,
              appTheme.primaryLight.withValues(alpha: 0.15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(appTheme.radiusXl),
          boxShadow: [
            BoxShadow(
              color: appTheme.earth.withValues(alpha: 0.025),
              blurRadius: 20,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // 头像 — 双层环形渐变
            Container(
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
              child: Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: appTheme.primary.withValues(alpha: 0.12),
                  ),
                  child: Icon(Icons.person_rounded,
                      color: appTheme.primary, size: 34),
                ),
              ),
            ),
            const SizedBox(height: 18),
            // 用户名
            Text(
              _userName,
              style: TextStyle(
                fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: appTheme.earth,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            // 编辑提示
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_rounded,
                    size: 14,
                    color: appTheme.earthMedium.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Text(
                  '点击编辑个人信息',
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
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 模块摘要卡片 — 可点击跳转到模块入口
  // ═══════════════════════════════════════════════════════════════
  Widget _buildModuleSnapshotCard(
      AppThemeExtension appTheme, _ModuleSnapshot snap) {
    return GestureDetector(
      onTap: () => context.push('/${snap.moduleId}'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        padding: const EdgeInsets.all(20),
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
        child: Row(
          children: [
            // 模块图标
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: snap.themeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: snap.icon.build(size: 24, color: snap.themeColor),
              ),
            ),
            const SizedBox(width: 16),
            // 摘要文本
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snap.displayName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: appTheme.earth,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    snap.summary.line1,
                    style: TextStyle(
                      fontSize: 13,
                      color: appTheme.earthMedium,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (snap.summary.line2 != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      snap.summary.line2!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: appTheme.earthMedium.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.chevron_right_rounded,
                color: appTheme.earthMedium.withValues(alpha: 0.25), size: 20),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 底部信息
  // ═══════════════════════════════════════════════════════════════
  Widget _buildFooter(AppThemeExtension appTheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Center(
        child: Column(
          children: [
            Text(
              '我的工具箱',
              style: TextStyle(
                fontSize: 13,
                color: appTheme.earthMedium.withValues(alpha: 0.4),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'V1.0.0 · 数据仅存储在本地',
              style: TextStyle(
                fontSize: 12,
                color: appTheme.earthMedium.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 编辑用户名弹窗
  // ═══════════════════════════════════════════════════════════════
  Future<void> _editName() async {
    final appTheme = Theme.of(context).appTheme;
    final ctrl = TextEditingController(text: _userName);

    await showDialog(
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
                child: Icon(Icons.person_rounded,
                    color: appTheme.primary, size: 30),
              ),
              const SizedBox(height: 18),
              Text(
                '编辑用户名',
                style: TextStyle(
                  fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: appTheme.earth,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '输入用户名',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(appTheme.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(color: appTheme.earth, fontSize: 15),
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
                    onTap: () async {
                      final name = ctrl.text.trim();
                      if (name.isEmpty) return;
                      await DatabaseService.instance
                          .upsertSetting('user_name', name);
                      if (mounted) setState(() => _userName = name);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [appTheme.primary, appTheme.primaryDark],
                        ),
                        borderRadius: BorderRadius.circular(appTheme.radiusMd),
                      ),
                      child: const Center(
                          child: Text('保存',
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
}

// ═════════════════════════════════════════════════════════════════
// 内部数据类
// ═════════════════════════════════════════════════════════════════

class _ModuleSnapshot {
  final String moduleId;
  final String displayName;
  final ModuleIcon icon;
  final Color themeColor;
  final ModuleSummary summary;

  const _ModuleSnapshot({
    required this.moduleId,
    required this.displayName,
    required this.icon,
    required this.themeColor,
    required this.summary,
  });
}
