import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/prediction_service.dart';
import '../models/period_record.dart';
import '../../../shared/utils/date_utils.dart';
import '../../../core/theme/theme_extension.dart';

/// 日历中的日期类型
enum CalendarDayType {
  normal,
  today,
  periodActual,
  periodPredicted,
  fertileWindow,
  ovulationDay,
}

/// 经期日历 Widget — 奢华自然主义风格
class PeriodCalendar extends StatelessWidget {
  final DateTime displayedMonth;
  final List<PeriodRecord> records;
  final PredictionResult? prediction;

  const PeriodCalendar({
    super.key,
    required this.displayedMonth,
    required this.records,
    this.prediction,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: appTheme.earthMedium.withAlpha(20),
        ),
      ),
      child: Column(
        children: [
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
              return _buildDayCell(appTheme, date, type);
            },
          ),

          // 图例
          const SizedBox(height: 20),
          _buildLegendSection(appTheme),
        ],
      ),
    );
  }

  CalendarDayType _getDayType(DateTime date) {
    final today = DateTime.now();

    // 今日
    if (AppDateUtils.isSameDay(date, today)) {
      return CalendarDayType.today;
    }

    // 实际经期
    for (final record in records) {
      final start = record.startDate;
      final end = record.endDate ?? today; // 进行中则用今日作为结束

      if (date.year >= start.year &&
          date.month >= start.month &&
          date.day >= start.day &&
          date.year <= end.year &&
          date.month <= end.month &&
          date.day <= end.day) {
        return CalendarDayType.periodActual;
      }
    }

    // 预测经期
    if (prediction != null) {
      final nextStart = prediction!.nextStartDate;
      final predictedEnd = nextStart.add(const Duration(days: 4));
      if (date.compareTo(nextStart) >= 0 &&
          date.compareTo(predictedEnd) <= 0) {
        return CalendarDayType.periodPredicted;
      }
    }

    // 易孕期 / 排卵日
    if (prediction != null) {
      final fertileStart = prediction!.fertileWindow.start;
      final fertileEnd = prediction!.fertileWindow.end;
      if (date.compareTo(fertileStart) >= 0 &&
          date.compareTo(fertileEnd) <= 0) {
        if (AppDateUtils.isSameDay(date, prediction!.ovulationDay)) {
          return CalendarDayType.ovulationDay;
        }
        return CalendarDayType.fertileWindow;
      }
    }

    return CalendarDayType.normal;
  }

  Widget _buildDayCell(
      AppThemeExtension appTheme, DateTime date, CalendarDayType type) {
    Color? bgColor;
    Color textColor = appTheme.earth;
    double borderWidth = 0;
    Color borderColor = Colors.transparent;

    switch (type) {
      case CalendarDayType.periodActual:
        bgColor = appTheme.rose;
        textColor = Colors.white;
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
        break;
      case CalendarDayType.today:
        borderWidth = 2;
        borderColor = appTheme.sage;
        break;
      case CalendarDayType.normal:
        bgColor = null;
        break;
    }

    return Container(
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
          fontWeight:
              type == CalendarDayType.today ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
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
          _buildLegend(appTheme, appTheme.primary, '易孕期'),
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
