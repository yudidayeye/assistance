import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/theme_extension.dart';

/// 我的页面内容 — 仅展示用户卡片
class ProfilePageContent extends StatelessWidget {
  const ProfilePageContent({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;

    return Scaffold(
      backgroundColor: appTheme.cream,
      body: Column(
        children: [
          // 头部标题
          Container(
            padding: EdgeInsets.fromLTRB(
                24, MediaQuery.of(context).padding.top + 16, 24, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '我的',
                  style: TextStyle(
                    fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: appTheme.earth,
                    letterSpacing: -0.5,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/settings'),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: appTheme.creamDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: appTheme.earthMedium.withAlpha(30),
                      ),
                    ),
                    child: Icon(
                      Icons.settings_outlined,
                      color: appTheme.earthMedium,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 用户卡片
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: _buildUserCard(appTheme),
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
          Icon(
            Icons.chevron_right_rounded,
            color: appTheme.earthMedium.withAlpha(100),
            size: 20,
          ),
        ],
      ),
    );
  }
}
