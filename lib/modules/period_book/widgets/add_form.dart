import 'package:flutter/material.dart';
import '../../../core/theme/theme_extension.dart';
import 'entry_date_field.dart';
import 'expense_category_helper.dart';

/// 通用内嵌添加表单（大额追加 / 个人支出 / 其他支出）
///
/// 四段结构：时间（可选） → 金额输入 → 描述/原因输入 → 操作按钮行（收起 + 确认添加）
///
/// 键盘行为：
/// - 金额输入框按"下一步" → 自动聚焦到描述输入框
/// - 描述输入框按"完成" → 直接触发确认添加
class AddForm extends StatefulWidget {
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
  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String>? onCategoryChanged;

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

  /// 发生时间（可选）。`null` 表示用户不填，条目按创建顺序落位。
  /// 有值时该条目会被插入到同组中最后一个「不晚于该日期」的条目之后。
  final DateTime? selectedDate;

  /// 时间变更回调；传 `null` 表示用户清除了已选时间。
  final ValueChanged<DateTime?>? onDateChanged;

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
    this.categories = const [],
    this.selectedCategory,
    this.onCategoryChanged,
    this.confirmText = '确认添加',
    this.confirmForeground = const Color(0xFF8B7EC8),
    this.confirmBackground = const Color(0xFF8B7EC8),
    this.confirmBorder = const Color(0xFF8B7EC8),
    this.collapseText = '收起',
    this.selectedDate,
    this.onDateChanged,
  });

  @override
  State<AddForm> createState() => _AddFormState();
}

class _AddFormState extends State<AddForm> {
  late final FocusNode _amountFocusNode;
  late final FocusNode _descFocusNode;

  @override
  void initState() {
    super.initState();
    _amountFocusNode = FocusNode();
    _descFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _amountFocusNode.dispose();
    _descFocusNode.dispose();
    super.dispose();
  }

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
          if (widget.categories.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: widget.categories.map((category) {
                  final selected = widget.selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Tooltip(
                      message: category,
                      child: ChoiceChip(
                        label: Icon(
                            ExpenseCategoryHelper.categoryIcon(category),
                            size: 20,
                            color: selected
                                ? appTheme.primary
                                : appTheme.earthMedium),
                        selected: selected,
                        onSelected: (_) =>
                            widget.onCategoryChanged?.call(category),
                        showCheckmark: false,
                        backgroundColor: appTheme.cardBackground,
                        selectedColor: appTheme.primary.withValues(alpha: 0.12),
                        side: BorderSide(
                            color: selected
                                ? appTheme.primary
                                : appTheme.earthMedium.withValues(alpha: 0.15)),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(appTheme.radiusSm)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
          ],
          // 时间（可选）
          EntryDateField(
            selectedDate: widget.selectedDate,
            onDateChanged: widget.onDateChanged,
          ),
          const SizedBox(height: 10),
          // 金额输入
          TextField(
            controller: widget.amountController,
            focusNode: _amountFocusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) {
              _descFocusNode.requestFocus();
            },
            decoration: InputDecoration(
              labelText: widget.amountLabel,
              hintText: widget.amountHint,
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
            controller: widget.descController,
            focusNode: _descFocusNode,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (widget.onConfirm != null) widget.onConfirm!();
            },
            decoration: InputDecoration(
              labelText: widget.descLabel,
              hintText: widget.descHint,
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
                  onPressed: widget.onCollapse,
                  style: TextButton.styleFrom(
                    backgroundColor: appTheme.creamDark,
                    foregroundColor: appTheme.earthMedium,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(fontSize: 14),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 18),
                  label: Text(widget.collapseText),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: widget.onConfirm,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: Text(widget.confirmText),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.confirmForeground,
                    backgroundColor:
                        widget.confirmBackground.withValues(alpha: 0.1),
                    side: BorderSide(
                        color: widget.confirmBorder.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
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
