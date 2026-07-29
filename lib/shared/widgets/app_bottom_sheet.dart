import 'package:flutter/material.dart';
import '../../core/theme/theme_extension.dart';
import '../foundation/app_typography.dart';
import '../foundation/app_spacing.dart';

/// 统一的应用底部弹出层
///
/// 替换 6 处 `showModalBottomSheet` 重复结构。
class AppBottomSheet {
  /// 显示底部弹出层
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget content,
    double maxHeightFactor = 0.7,
    List<Widget>? actions,
  }) {
    final appTheme = Theme.of(context).appTheme;

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * maxHeightFactor,
          ),
          decoration: BoxDecoration(
            color: appTheme.cream,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题行
              Padding(
                padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTypography.bodyLg.copyWith(
                          color: appTheme.earth,
                        ),
                      ),
                    ),
                    if (actions != null) ...actions,
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: appTheme.earthMedium,
                      ),
                    ),
                  ],
                ),
              ),
              // 内容
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: content,
                ),
              ),
              // 底部安全区域
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        );
      },
    );
  }

  /// 显示详情底部弹出层（用于查看构成）
  static Future<T?> showDetail<T>(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final appTheme = Theme.of(context).appTheme;

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: appTheme.cream,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(appTheme.radiusXl),
              topRight: Radius.circular(appTheme.radiusXl),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 16),
                child: Text(
                  title,
                  style: AppTypography.displayMd.copyWith(
                    color: appTheme.earth,
                  ),
                ),
              ),
              // 内容
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  children: [
                    ...children,
                    SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
