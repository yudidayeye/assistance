import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extension.dart';

/// 记一笔页面 — Phase 4 实现
class AddExpensePage extends StatefulWidget {
  final int periodId;
  final String defaultCategory;

  const AddExpensePage({
    super.key,
    required this.periodId,
    this.defaultCategory = 'shopping',
  });

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: appTheme.scaffoldGradient),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildHeader(appTheme),
            const SliverToBoxAdapter(
              child: Center(
                child: Text(
                  '记一笔（开发中）',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF8B9BAA),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppThemeExtension appTheme) {
    final safeTop = MediaQuery.of(context).padding.top;
    final headerHeight = safeTop + 58;

    return SliverPersistentHeader(
      pinned: true,
      delegate: _PinnedHeaderDelegate(
        height: headerHeight,
        child: Container(
          color: appTheme.cream,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, safeTop + 12, 16, 6),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: SizedBox(
                    width: 28,
                    height: 40,
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        color: appTheme.earth, size: 20),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    '记一笔',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: GoogleFonts.dmSans().fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: appTheme.earth,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  const _PinnedHeaderDelegate({
    required this.height,
    required this.child,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(height: height, child: child);
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}
