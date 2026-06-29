import 'package:flutter/material.dart';
import '../services/prediction_service.dart';
import '../models/period_record.dart';
import '../../../shared/utils/date_utils.dart';
import '../../../core/theme/theme_extension.dart';

/// 日历中的日期类型（按业务优先级排列）
enum CalendarDayType {
  normal,
  periodPredicted,
  fertileWindow,
  ovulationDay,
  periodActual,
}

/// 经期日历 Widget — 月份切换 + 星期标题 + 日期网格 + 图例，整体为一个 card
class PeriodCalendar extends StatelessWidget {
  final DateTime displayedMonth;
  final List<PeriodRecord> records;
  final PredictionResult? prediction;
  final ValueChanged<DateTime>? onMonthChanged;
  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onDateSelected;

  const PeriodCalendar({
    super.key,
    required this.displayedMonth,
    required this.records,
    this.prediction,
    this.onMonthChanged,
    this.selectedDate,
    this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;

    final firstDay = DateTime(displayedMonth.year, displayedMonth.month, 1);
    final startWeekday = firstDay.weekday % 7; // Sunday = 0
    final daysInMonth =
        DateTime(displayedMonth.year, displayedMonth.month + 1, 0).day;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: appTheme.earthMedium.withAlpha(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 月份切换 header
          _buildMonthHeader(appTheme),
          const SizedBox(height: 12),

          // 星期标题
          Row(
            children: ['日', '一', '二', '三', '四', '五', '六']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 12,
                            color: appTheme.earthMedium,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),

          // 日历网格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startWeekday) {
                return const SizedBox();
              }
              final day = index - startWeekday + 1;
              final date =
                  DateTime(displayedMonth.year, displayedMonth.month, day);
              final type = _getDayType(date);
              final isToday = AppDateUtils.isSameDay(date, DateTime.now());
              final isSelected = selectedDate != null &&
                  AppDateUtils.isSameDay(date, selectedDate!);
              return _buildDayCell(appTheme, date, type,
                  isToday: isToday, isSelected: isSelected);
            },
          ),

          // 图例
          const SizedBox(height: 12),
          _buildLegendSection(appTheme),
        ],
      ),
    );
  }

  CalendarDayType _getDayType(DateTime date) {
    // 实际经期 — 最高业务优先级
    for (final record in records) {
      final start = record.startDate;
      final end = record.endDate ?? DateTime.now();
      if (AppDateUtils.isDateInRangeInclusive(date, start, end)) {
        return CalendarDayType.periodActual;
      }
    }

    // 预测经期
    if (prediction != null) {
      final nextStart = prediction!.nextStartDate;
      final predictedEnd = nextStart.add(const Duration(
          days: PredictionConfig.defaultPeriodDuration - 1));
      if (AppDateUtils.isDateInRangeInclusive(date, nextStart, predictedEnd)) {
        return CalendarDayType.periodPredicted;
      }
    }

    // 易孕期 / 排卵日
    if (prediction != null) {
      final fertileStart = prediction!.fertileWindow.start;
      final fertileEnd = prediction!.fertileWindow.end;
      if (AppDateUtils.isDateInRangeInclusive(date, fertileStart, fertileEnd)) {
        if (AppDateUtils.isSameDay(date, prediction!.ovulationDay)) {
          return CalendarDayType.ovulationDay;
        }
        return CalendarDayType.fertileWindow;
      }
    }

    return CalendarDayType.normal;
  }

  Widget _buildDayCell(
      AppThemeExtension appTheme, DateTime date, CalendarDayType type,
      {bool isToday = false, bool isSelected = false}) {
    Color? bgColor;
    Color textColor = appTheme.earth;
    double borderWidth = 0;
    Color borderColor = Colors.transparent;
    FontWeight fontWeight = FontWeight.w500;

    switch (type) {
      case CalendarDayType.periodActual:
        bgColor = appTheme.rose;
        textColor = Colors.white;
        fontWeight = FontWeight.w600;
        break;
      case CalendarDayType.periodPredicted:
        bgColor = appTheme.rose.withAlpha(40);
        borderWidth = 1.5;
        borderColor = appTheme.rose;
        break;
      case CalendarDayType.fertileWindow:
        bgColor = appTheme.primary.withAlpha(30);
        break;
      case CalendarDayType.ovulationDay:
        bgColor = appTheme.primary;
        textColor = Colors.white;
        fontWeight = FontWeight.w600;
        break;
      case CalendarDayType.normal:
        bgColor = null;
        break;
    }

    // 今日 overlay
    if (isToday) {
      borderWidth = borderWidth > 0 ? borderWidth : 2;
      borderColor = borderColor == Colors.transparent
          ? appTheme.sage
          : borderColor;
      fontWeight = FontWeight.w700;
    }

    // 选中 overlay
    if (isSelected) {
      borderWidth = 2;
      borderColor = appTheme.earth;
      fontWeight = FontWeight.w700;
    }

    return GestureDetector(
      onTap: onDateSelected != null ? () => onDateSelected!(date) : null,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: borderWidth > 0
              ? Border.all(color: borderColor, width: borderWidth)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '${date.day}',
          style: TextStyle(
            fontSize: 13,
            color: textColor,
            fontWeight: fontWeight,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthHeader(AppThemeExtension appTheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => onMonthChanged?.call(
            DateTime(displayedMonth.year, displayedMonth.month - 1, 1),
          ),
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
        Text(
          '${displayedMonth.year}年${displayedMonth.month}月',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: appTheme.earth,
          ),
        ),
        GestureDetector(
          onTap: () => onMonthChanged?.call(
            DateTime(displayedMonth.year, displayedMonth.month + 1, 1),
          ),
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
    );
  }

  Widget _buildLegendSection(AppThemeExtension appTheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.creamDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegend(appTheme, appTheme.rose, '经期'),
          _buildLegend(appTheme, appTheme.rose.withAlpha(80), '预测经期'),
          _buildLegend(appTheme, appTheme.primary, '排卵期'),
          _buildLegend(appTheme, appTheme.sage, '今日'),
        ],
      ),
    );
  }

  Widget _buildLegend(
      AppThemeExtension appTheme, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: appTheme.earthMedium,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
