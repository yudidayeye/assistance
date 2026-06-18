import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/theme_extension.dart';

/// 月份选择器 — 奢华自然主义风格
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
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;
    final monthStr = '${_current.year}年${_current.month}月';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: appTheme.earthMedium.withAlpha(20),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 上一月按钮
            GestureDetector(
              onTap: () => _goToMonth(-1),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: appTheme.creamDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: appTheme.earthMedium,
                  size: 20,
                ),
              ),
            ),

            // 月份显示
            GestureDetector(
              onTap: _showMonthPicker,
              child: Row(
                children: [
                  Text(
                    monthStr,
                    style: TextStyle(
                      fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: appTheme.earth,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: appTheme.earthMedium.withAlpha(150),
                  ),
                ],
              ),
            ),

            // 下一月按钮
            GestureDetector(
              onTap: () => _goToMonth(1),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: appTheme.creamDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: appTheme.earthMedium,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
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
