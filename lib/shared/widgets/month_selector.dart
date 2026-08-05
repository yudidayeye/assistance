import 'package:flutter/material.dart';
import '../../core/theme/theme_extension.dart';

/// 月份选择器 — 柔和风格
class MonthSelector extends StatefulWidget {
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthChanged;

  const MonthSelector({
    super.key,
    required this.selectedMonth,
    required this.onMonthChanged,
  });

  @override
  State<MonthSelector> createState() => _MonthSelectorState();
}

class _MonthSelectorState extends State<MonthSelector> {
  late DateTime _current;

  @override
  void initState() {
    super.initState();
    _current = widget.selectedMonth;
  }

  @override
  void didUpdateWidget(MonthSelector old) {
    super.didUpdateWidget(old);
    _current = widget.selectedMonth;
  }

  void _goToMonth(int offset) {
    final newMonth = DateTime(_current.year, _current.month + offset, 1);
    setState(() => _current = newMonth);
    widget.onMonthChanged(newMonth);
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    final monthStr = '${_current.year}年${_current.month}月';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 上一月按钮
          _ArrowButton(
            icon: Icons.chevron_left_rounded,
            onTap: () => _goToMonth(-1),
            appTheme: appTheme,
          ),

          // 月份显示
          GestureDetector(
            onTap: _showMonthPicker,
            child: Row(
              children: [
                Text(
                  monthStr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: appTheme.earth,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: appTheme.earthMedium,
                ),
              ],
            ),
          ),

          // 下一月按钮
          _ArrowButton(
            icon: Icons.chevron_right_rounded,
            onTap: () => _goToMonth(1),
            appTheme: appTheme,
          ),
        ],
      ),
    );
  }

  void _showMonthPicker() {
    final appTheme = Theme.of(context).appTheme;

    showDatePicker(
      context: context,
      initialDate: _current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: appTheme.primary,
                ),
          ),
          child: child!,
        );
      },
    ).then((date) {
      if (date != null) {
        final newMonth = DateTime(date.year, date.month, 1);
        setState(() => _current = newMonth);
        widget.onMonthChanged(newMonth);
      }
    });
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final AppThemeExtension appTheme;

  const _ArrowButton({
    required this.icon,
    required this.onTap,
    required this.appTheme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: appTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(appTheme.radiusMd),
        ),
        child: Icon(
          icon,
          color: appTheme.earthMedium,
          size: 20,
        ),
      ),
    );
  }
}
