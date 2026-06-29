import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: appTheme.earthMedium.withAlpha(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 日期类型标签（缩小版）
          Row(
            children: [
              Icon(Icons.calendar_month_rounded,
                  size: 16, color: appTheme.rose),
              const SizedBox(width: 8),
              Text(
                _getDayTypeLabel(),
                style: TextStyle(
                  fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: appTheme.earth,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 开关行
          Row(
            children: [
              Icon(Icons.wb_sunny_rounded,
                  size: 18, color: appTheme.rose.withAlpha(180)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '姨妈来了/姨妈走了',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              _saving
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: appTheme.rose,
                      ),
                    )
                  : Switch(
                      value: _isInActualPeriod,
                      onChanged: _togglePeriod,
                      activeTrackColor: appTheme.rose.withAlpha(60),
                    ),
            ],
          ),
          const SizedBox(height: 4),

          // 备注行
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.sticky_note_2_rounded,
                  size: 18, color: appTheme.rose.withAlpha(180)),
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
                    fillColor: appTheme.creamDark.withAlpha(120),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
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
