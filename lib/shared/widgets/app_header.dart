import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/theme_extension.dart';
import '../foundation/app_typography.dart';
import '../foundation/app_spacing.dart';
import 'pinned_header_delegate.dart';

/// 统一的应用头部组件
///
/// 支持 4 种变体：
/// - [AppHeader.root] — Tab 根页面（无返回按钮，可带右侧操作按钮）
/// - [AppHeader.simple] — 返回 + 标题
/// - [AppHeader.withActions] — 返回 + 标题 + 右侧操作按钮
/// - [AppHeader.withSubtitle] — 返回 + 标题 + 副标题
///
/// 内部使用 [PinnedHeaderDelegate] 实现固定头部。
class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  final List<Widget> actions;
  final double? heightOverride;

  const AppHeader._({
    required this.title,
    this.subtitle,
    required this.showBack,
    this.actions = const [],
    this.heightOverride,
  });

  /// Tab 根页面（无返回按钮，可带右侧操作按钮）
  factory AppHeader.root({
    required String title,
    List<Widget> actions = const [],
  }) =>
      AppHeader._(title: title, showBack: false, actions: actions);

  /// 返回 + 标题（最简单形式）
  factory AppHeader.simple({required String title}) =>
      AppHeader._(title: title, showBack: true);

  /// 返回 + 标题 + 右侧操作按钮
  factory AppHeader.withActions({
    required String title,
    List<Widget> actions = const [],
  }) =>
      AppHeader._(title: title, showBack: true, actions: actions);

  /// 返回 + 标题 + 副标题
  factory AppHeader.withSubtitle({
    required String title,
    required String subtitle,
  }) =>
      AppHeader._(title: title, showBack: true, subtitle: subtitle);

  /// 生成 34×34 圆形图标按钮（给 actions 用）
  static Widget iconButton(
    AppThemeExtension appTheme,
    IconData icon,
    VoidCallback onTap,
  ) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: appTheme.earthMedium.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: appTheme.earth, size: 20),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    final safeTop = MediaQuery.of(context).padding.top;
    final headerHeight = heightOverride ?? (safeTop + 58);

    return SliverPersistentHeader(
      pinned: true,
      delegate: PinnedHeaderDelegate(
        height: headerHeight,
        child: Container(
          color: appTheme.cream,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, safeTop + 12, 16, 6),
            child: Row(
              children: [
                if (showBack) ...[
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: SizedBox(
                      width: 28,
                      height: 40,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: appTheme.earth,
                        size: 20,
                      ),
                    ),
                  ),
                  AppSpacing.w2,
                ],
                if (subtitle != null) ...[
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.headerTitle.copyWith(
                            color: appTheme.earth,
                          ),
                        ),
                        AppSpacing.w8,
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: appTheme.earthMedium.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headerTitle.copyWith(
                        color: appTheme.earth,
                      ),
                    ),
                  ),
                ],
                ...actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
