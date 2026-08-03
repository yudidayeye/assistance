import 'package:flutter/material.dart';
import '../../../core/theme/theme_extension.dart';

/// 通用内嵌添加表单（大额追加 / 个人支出 / 其他支出）
///
/// 三段结构：金额输入 → 描述/原因输入 → 操作按钮行（收起 + 确认添加）
class AddForm extends StatelessWidget {
  /// 第一个输入框的 label
  final String amountLabel;
  /// 第二个输入框的 label
  final String descLabel;
  /// 第一个输入框的 hint
  final String amountHint;
  /// 第二个输入框的 hint
  final String descHint;

  final TextEditingController amountController;
  final TextEditingController descController;
  final VoidCallback? onCollapse;
  final VoidCallback? onConfirm;

  /// 确认按钮文字
  final String confirmText;
  /// 确认按钮前景色
  final Color confirmForeground;
  /// 确认按钮背景色
  final Color confirmBackground;
  /// 确认按钮边框色
  final Color confirmBorder;

  /// 收起按钮文字
  final String collapseText;

  const AddForm({
    super.key,
    required this.amountLabel,
    required this.descLabel,
    required this.amountHint,
    required this.descHint,
    required this.amountController,
    required this.descController,
    this.onCollapse,
    this.onConfirm,
    this.confirmText = '确认添加',
    this.confirmForeground = const Color(0xFF8B7EC8),
    this.confirmBackground = const Color(0xFF8B7EC8),
    this.confirmBorder = const Color(0xFF8B7EC8),
    this.collapseText = '收起',
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appTheme.creamDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 金额输入
          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) {
              FocusScope.of(context).nextFocus();
            },
            decoration: InputDecoration(
              labelText: amountLabel,
              hintText: amountHint,
              hintStyle: TextStyle(
                fontSize: 13,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
              labelStyle: TextStyle(
                fontSize: 13,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: appTheme.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(appTheme.radiusSm),
                borderSide: BorderSide(
                  color: appTheme.earthMedium.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            style: TextStyle(fontSize: 14, color: appTheme.earth),
          ),
          const SizedBox(height: 10),
          // 描述/原因输入
          TextField(
            controller: descController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (onConfirm != null) onConfirm!();
            },
            decoration: InputDecoration(
              labelText: descLabel,
              hintText: descHint,
              hintStyle: TextStyle(
                fontSize: 13,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
              labelStyle: TextStyle(
                fontSize: 13,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: appTheme.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(appTheme.radiusSm),
                borderSide: BorderSide(
                  color: appTheme.earthMedium.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            style: TextStyle(fontSize: 14, color: appTheme.earth),
          ),
          const SizedBox(height: 10),
          // 操作按钮行
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onCollapse,
                  style: TextButton.styleFrom(
                    backgroundColor: appTheme.creamDark,
                    foregroundColor: appTheme.earthMedium,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    textStyle: const TextStyle(fontSize: 14),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 18),
                  label: Text(collapseText),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: Text(confirmText),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: confirmForeground,
                    backgroundColor: confirmBackground.withValues(alpha: 0.1),
                    side: BorderSide(color: confirmBorder.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 8 : 0),
        ],
      ),
    );
  }
}
