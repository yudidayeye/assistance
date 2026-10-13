import 'package:flutter/material.dart';
import '../../../core/theme/theme_extension.dart';
import '../services/entry_ordering.dart';

/// 新增表单里的「时间（可选）」行。
///
/// 由 [AddForm] 与阶段详情页手写的「追加」表单共用——6 个新增表单里只有那一个
/// 不是 [AddForm]，抽成组件后 6 处的日期控件外观与交互完全一致，
/// 不必把同一段布局抄两遍。
///
/// ## 为什么默认不预填今天
///
/// 「不填」是合法且有意义的取值（条目按创建顺序落位，见 `specs/002-entry-time-sort`
/// 的 FR-002）。预填今天会让用户在不知情的情况下得到一条带日期的记录，
/// 破坏「不填时间的行为与改动前完全一致」这一承诺（SC-001）。
class EntryDateField extends StatelessWidget {
  /// 当前已选日期；`null` 表示未填写，此时右侧显示「选择日期」。
  final DateTime? selectedDate;

  /// 变更回调；以 `null` 调用表示用户清除了已选日期。
  ///
  /// 这里**不持有状态**：日期由父级保管，因为提交后父级需要重置它
  /// （与同页面其他表单字段的处理方式一致）。
  final ValueChanged<DateTime?>? onDateChanged;

  /// 左侧标签文案。
  final String label;

  const EntryDateField({
    super.key,
    this.selectedDate,
    this.onDateChanged,
    this.label = '时间（可选）',
  });

  /// 打开系统日期选择器并回传结果。
  ///
  /// `firstDate` / `lastDate` 与记账模块既有页面（`new_period_page` /
  /// `edit_period_page`）保持一致，避免同一 App 内出现两套可选范围。
  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      onDateChanged?.call(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    final selected = selectedDate;
    final accent = selected != null ? appTheme.primary : appTheme.earthMedium;
    // 走一遍「格式化 → 展示」往返：这里显示的与最终入库的是同一个值
    final displayText = selected == null
        ? '不填'
        : formatEntryDateForDisplay(formatEntryDate(selected)) ?? '不填';

    return Row(
      children: [
        Expanded(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: appTheme.earthMedium)),
        ),
        TextButton(
          onPressed: onDateChanged == null
              ? null
              : () {
                  final now = DateTime.now();
                  onDateChanged?.call(DateTime(now.year, now.month, now.day));
                },
          child: const Text('今天'),
        ),
        Container(
          key: const ValueKey('entry-date-box'),
          decoration: BoxDecoration(
            color: selected != null
                ? appTheme.primary.withValues(alpha: 0.08)
                : appTheme.creamDark,
            borderRadius: BorderRadius.circular(appTheme.radiusSm),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            TextButton.icon(
              onPressed:
                  onDateChanged == null ? null : () => _pickDate(context),
              style: TextButton.styleFrom(foregroundColor: accent),
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(selected == null ? '选择日期' : displayText),
            ),
            if (selected != null)
              IconButton(
                tooltip: '清除日期',
                onPressed: onDateChanged == null
                    ? null
                    : () => onDateChanged?.call(null),
                color: accent,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
          ]),
        ),
      ],
    );
  }
}
