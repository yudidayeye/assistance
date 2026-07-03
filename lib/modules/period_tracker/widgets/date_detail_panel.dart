import 'package:flutter/material.dart';
import '../models/period_record.dart';
import '../services/prediction_service.dart';
import '../services/period_service.dart';
import '../../../shared/utils/date_utils.dart';
import '../../../core/theme/theme_extension.dart';

/// 日期详情面板 — 选中日期后的操作区（紧凑版）
class DateDetailPanel extends StatefulWidget {
  final DateTime selectedDate;
  final List<PeriodRecord> records;
  final PredictionResult? prediction;
  final VoidCallback onChanged;

  const DateDetailPanel({
    super.key,
    required this.selectedDate,
    required this.records,
    this.prediction,
    required this.onChanged,
  });

  @override
  State<DateDetailPanel> createState() => _DateDetailPanelState();
}

class _DateDetailPanelState extends State<DateDetailPanel> {
  static const int _defaultPeriodDays = 4;
  late TextEditingController _noteController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    _loadNote();
  }

  @override
  void didUpdateWidget(DateDetailPanel old) {
    super.didUpdateWidget(old);
    if (old.selectedDate != widget.selectedDate) {
      _loadNote();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _loadNote() {
    final record = _findRecordForDate(widget.selectedDate);
    _noteController.text = record?.note ?? '';
  }

  PeriodRecord? _findRecordForDate(DateTime date) {
    for (final r in widget.records) {
      final start = AppDateUtils.dateOnly(r.startDate);
      final end = r.endDate != null
          ? AppDateUtils.dateOnly(r.endDate!)
          : AppDateUtils.dateOnly(DateTime.now());
      if (AppDateUtils.isDateInRangeInclusive(date, start, end)) {
        return r;
      }
    }
    return null;
  }

  bool get _isInActualPeriod => _findRecordForDate(widget.selectedDate) != null;

  Future<void> _togglePeriod(bool on) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (on) {
        final start = AppDateUtils.dateOnly(widget.selectedDate);
        final end = start.add(const Duration(days: _defaultPeriodDays - 1));
        final existing = _findRecordForDate(widget.selectedDate);
        if (existing == null) {
          await PeriodService.instance.insertPeriodRange(start, end);
        }
      } else {
        final record = _findRecordForDate(widget.selectedDate);
        if (record != null) {
          await PeriodService.instance.deleteRecord(record.id);
        }
      }
      widget.onChanged();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveNote(String text) async {
    final record = _findRecordForDate(widget.selectedDate);
    if (record != null) {
      await PeriodService.instance.updateRecord(
        record.copyWith(note: text.isEmpty ? null : text),
      );
    }
  }

  String _getDayTypeLabel() {
    final date = widget.selectedDate;

    for (final r in widget.records) {
      final start = AppDateUtils.dateOnly(r.startDate);
      final end = r.endDate != null
          ? AppDateUtils.dateOnly(r.endDate!)
          : AppDateUtils.dateOnly(DateTime.now());
      if (AppDateUtils.isDateInRangeInclusive(date, start, end)) {
        final day = date.difference(start).inDays + 1;
        return '经期第$day天';
      }
    }

    if (widget.prediction != null) {
      final nextStart = widget.prediction!.nextStartDate;
      final predictedEnd = nextStart.add(
          const Duration(days: PredictionConfig.defaultPeriodDuration - 1));
      if (AppDateUtils.isDateInRangeInclusive(date, nextStart, predictedEnd)) {
        final day = date.difference(nextStart).inDays + 1;
        return '预测经期第$day天';
      }

      final ovDay = widget.prediction!.ovulationDay;
      if (AppDateUtils.isSameDay(date, ovDay)) {
        return '排卵日';
      }

      final fertileStart = widget.prediction!.fertileWindow.start;
      final fertileEnd = widget.prediction!.fertileWindow.end;
      if (AppDateUtils.isDateInRangeInclusive(date, fertileStart, fertileEnd)) {
        final day = date.difference(fertileStart).inDays + 1;
        return '排卵期第$day天';
      }
    }

    return '非特殊日';
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusLg),
        boxShadow: appTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 日期类型标签 + 日期
          Row(
            children: [
              Text(
                _getDayTypeLabel(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: appTheme.earthMedium.withValues(alpha: 0.7),
                ),
              ),
              const Spacer(),
              Text(
                AppDateUtils.formatFullDate(widget.selectedDate),
                style: TextStyle(
                  fontSize: 12,
                  color: appTheme.earthMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 开关行
          Row(
            children: [
              Icon(Icons.local_fire_department_rounded,
                  size: 18, color: appTheme.rose.withAlpha(200)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '姨妈来了',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: appTheme.earth,
                  ),
                ),
              ),
              _saving
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: appTheme.primary,
                      ),
                    )
                  : Switch(
                      value: _isInActualPeriod,
                      onChanged: _togglePeriod,
                      activeTrackColor:
                          appTheme.rose.withValues(alpha: 0.2),
                      activeThumbColor: appTheme.rose,
                      inactiveThumbColor:
                          appTheme.earthMedium.withValues(alpha: 0.4),
                      inactiveTrackColor:
                          appTheme.earthMedium.withValues(alpha: 0.2),
                      trackOutlineColor:
                          const WidgetStatePropertyAll(Colors.transparent),
                    ),
            ],
          ),
          const SizedBox(height: 6),

          // 备注行
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.sticky_note_2_rounded,
                  size: 18, color: appTheme.primary.withAlpha(200)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    hintText: '备注…',
                    hintStyle: TextStyle(
                      color: appTheme.earthMedium.withAlpha(120),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: appTheme.creamDark.withAlpha(100),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  style: TextStyle(
                    color: appTheme.earth,
                    fontSize: 13,
                  ),
                  onChanged: _saveNote,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
