import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/storage/database_service.dart';
import '../core/theme/theme_extension.dart';
import '../shared/widgets/app_scaffold.dart';
import '../shared/widgets/app_dialog.dart';
import '../shared/foundation/app_typography.dart';
import '../shared/foundation/app_spacing.dart';

/// 我的页面 — 用户中心
class ProfilePageContent extends StatefulWidget {
  const ProfilePageContent({super.key});

  @override
  State<ProfilePageContent> createState() => _ProfilePageContentState();
}

class _ProfilePageContentState extends State<ProfilePageContent> {
  String _userName = '用户';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final rows = await DatabaseService.instance
        .rawQuery("SELECT value FROM app_settings WHERE key = 'user_name'");
    if (rows.isNotEmpty && mounted) {
      setState(() => _userName = rows.first['value'] as String);
    }
  }

  void _showProfileSearch(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    showSearch(
      context: context,
      delegate: _ProfileSearchDelegate(appTheme),
    );
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
          titleSpacing: 0,
          title: Text(
            '我的',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
          ),
          actions: [
            IconButton(
              onPressed: () => _showProfileSearch(context),
              icon: Icon(Icons.search_rounded, color: appTheme.earth, size: 20),
            ),
            IconButton(
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
              color: appTheme.earth,
              iconSize: 20,
            ),
          ],
        ),

        // ── 用户卡片（页面焦点） ──
        SliverToBoxAdapter(
          child: _buildUserCard(appTheme),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
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
          color: appTheme.cardBackground,
          borderRadius: BorderRadius.circular(appTheme.radiusXl),
          boxShadow: appTheme.cardShadow,
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
                  borderRadius: BorderRadius.circular(appTheme.radiusLg),
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
              ...AppDialog.confirmCancelPair(
                context: ctx,
                cancelLabel: '取消',
                confirmLabel: '保存',
                onConfirm: () async {
                  final name = ctrl.text.trim();
                  if (name.isEmpty) return;
                  await DatabaseService.instance
                      .upsertSetting('user_name', name);
                  if (mounted) setState(() => _userName = name);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSearchDelegate extends SearchDelegate<String> {
  final AppThemeExtension appTheme;

  _ProfileSearchDelegate(this.appTheme);

  @override
  String get searchFieldLabel => '搜索设置';

  static const _allItems = [
    {'icon': Icons.settings_outlined, 'label': '设置', 'route': '/settings'},
    {'icon': Icons.sync_rounded, 'label': '数据同步', 'route': '/sync'},
    {'icon': Icons.palette_outlined, 'label': '主题设置', 'route': '/settings'},
    {'icon': Icons.info_outlined, 'label': '关于', 'route': '/settings'},
  ];

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        onPressed: () => query = '',
        icon: Icon(Icons.clear_rounded, color: appTheme.earthMedium),
      ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, ''),
    icon: Icon(Icons.arrow_back_ios_new_rounded, color: appTheme.earth),
  );

  @override
  Widget buildResults(BuildContext context) {
    final results = _allItems
        .where((item) => (item['label'] as String).contains(query))
        .toList();
    return _buildResultsList(results);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final results = query.isEmpty
        ? _allItems
        : _allItems
            .where((item) => (item['label'] as String).contains(query))
            .toList();
    return _buildResultsList(results);
  }

  Widget _buildResultsList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          '未找到匹配项',
          style: TextStyle(color: appTheme.earthMedium.withValues(alpha: 0.5)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: Icon(item['icon'] as IconData, color: appTheme.earth),
          title: Text(item['label'] as String, style: TextStyle(color: appTheme.earth)),
          onTap: () {
            close(context, '');
            final route = item['route'] as String;
            context.push(route);
          },
        );
      },
    );
  }
}

