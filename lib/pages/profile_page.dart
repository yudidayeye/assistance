import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/theme_extension.dart';

/// 我的页面内容 — 无底部导航和返回按钮，作为 MainShellPage 的子页
class ProfilePageContent extends StatelessWidget {
  const ProfilePageContent({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;

    return Scaffold(
      backgroundColor: appTheme.cream,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 头部 — 仅标题，无返回按钮
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  24, MediaQuery.of(context).padding.top + 16, 24, 24),
              child: Text(
                '我的',
                style: TextStyle(
                  fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: appTheme.earth,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),

          // 用户信息卡片
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: _buildUserCard(appTheme),
            ),
          ),

          // 功能列表
          SliverToBoxAdapter(
            child: _buildSectionHeader(appTheme, '功能'),
          ),
          SliverToBoxAdapter(
            child: _buildMenuSection(appTheme),
          ),

          // 关于
          SliverToBoxAdapter(
            child: _buildSectionHeader(appTheme, '关于'),
          ),
          SliverToBoxAdapter(
            child: _buildAboutSection(appTheme),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(AppThemeExtension appTheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: appTheme.earth.withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 头像 — 浅色渐变 + 人物图标
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: appTheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.person_rounded,
              color: appTheme.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),

          // 用户信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '用户',
                  style: TextStyle(
                    fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: appTheme.earth,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '点击编辑个人信息',
                  style: TextStyle(
                    fontSize: 13,
                    color: appTheme.earthMedium,
                  ),
                ),
              ],
            ),
          ),

          // 箭头
          Icon(
            Icons.chevron_right_rounded,
            color: appTheme.earthMedium.withAlpha(100),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(AppThemeExtension appTheme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: appTheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.apps_rounded,
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

  Widget _buildMenuSection(AppThemeExtension appTheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: appTheme.earthMedium.withAlpha(20),
        ),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            appTheme,
            icon: Icons.settings_outlined,
            label: '设置',
            onTap: () {},
          ),
          Divider(
            height: 1,
            indent: 56,
            color: appTheme.earthMedium.withAlpha(15),
          ),
          _buildMenuItem(
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
          _buildMenuItem(
            appTheme,
            icon: Icons.help_outline_rounded,
            label: '帮助与反馈',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(AppThemeExtension appTheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: appTheme.earthMedium.withAlpha(20),
        ),
      ),
      child: Column(
        children: [
          _buildAboutItem(appTheme, '版本', 'V1.0.0'),
          Divider(
            height: 1,
            indent: 56,
            color: appTheme.earthMedium.withAlpha(15),
          ),
          _buildAboutItem(appTheme, '隐私声明', '所有数据仅存储在本地'),
          Divider(
            height: 1,
            indent: 56,
            color: appTheme.earthMedium.withAlpha(15),
          ),
          _buildAboutItem(appTheme, '免责声明', '生理期预测仅供参考'),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
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
}
