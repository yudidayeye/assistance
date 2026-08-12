import 'dart:math';
import 'package:flutter/material.dart';
import '../models/period_record.dart';
import '../services/period_service.dart';
import '../services/prediction_service.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../shared/foundation/app_spacing.dart';

/// 周期统计页 — 柔和风格
class PeriodStatsPage extends StatefulWidget {
  const PeriodStatsPage({super.key});

  @override
  State<PeriodStatsPage> createState() => _PeriodStatsPageState();
}

class _PeriodStatsPageState extends State<PeriodStatsPage> {
  List<PeriodRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // ?????? _loading ??? true???????? loading?????
    final records = await PeriodService.instance.getAllRecords();
    PredictionService.instance.predict(records);

    if (mounted) {
      setState(() {
        _records = records;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    if (_loading) {
      return Scaffold(
        backgroundColor: appTheme.cream,
        body: Center(
          child: CircularProgressIndicator(color: appTheme.primary),
        ),
      );
    }

    final completedRecords = _records.where((r) => r.endDate != null).toList();
    final cycleLengths = _records
        .where((r) => r.cycleLength != null)
        .map((r) => r.cycleLength!)
        .toList();
    final avgCycle = cycleLengths.isEmpty
        ? 28
        : (cycleLengths.reduce((a, b) => a + b) / cycleLengths.length).round();
    final avgDuration = completedRecords.isEmpty
        ? 5
        : (completedRecords
                    .map((r) => r.durationDays ?? 5)
                    .reduce((a, b) => a + b) /
                completedRecords.length)
            .round();

    String regularity = '数据不足';
    if (cycleLengths.length >= 3) {
      final stdDev = _calculateStdDev(cycleLengths);
      if (stdDev < 3) {
        regularity = '规律';
      } else if (stdDev < 7) {
        regularity = '一般';
      } else {
        regularity = '不规律';
      }
    }

    return AppScrollScaffold(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: appTheme.cream,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 0,
          automaticallyImplyLeading: true,
          title: Text(
            '周期统计',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
          ),
        ),
        const SliverToBoxAdapter(
          child: SectionLabel(title: '周期概况'),
        ),
        SliverToBoxAdapter(
          child: _buildStatsCard(appTheme, avgCycle, avgDuration, regularity),
        ),
        const SliverToBoxAdapter(
          child: SectionLabel(title: '历史记录'),
        ),
        if (_records.isEmpty)
          SliverFillRemaining(
            child: EmptyStateWidget(
              icon: Icons.calendar_today_rounded,
              title: '暂无历史记录',
              subtitle: '记录经期后会在这里显示',
              iconColor: appTheme.primary,
            ),
          )
        else
          SliverToBoxAdapter(
            child: _buildRecordsList(appTheme),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildStatsCard(AppThemeExtension appTheme, int avgCycle,
      int avgDuration, String regularity) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, AppSpacing.xs),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
        border: Border.all(
          color: appTheme.earthMedium.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(appTheme,
                icon: Icons.repeat_rounded, label: '平均周期', value: '$avgCycle天'),
          ),
          _buildDivider(appTheme),
          Expanded(
            child: _buildStatItem(appTheme,
                icon: Icons.calendar_today_rounded,
                label: '经期天数',
                value: '$avgDuration天'),
          ),
          _buildDivider(appTheme),
          Expanded(
            child: _buildStatItem(appTheme,
                icon: Icons.insights_rounded, label: '规律性', value: regularity),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(AppThemeExtension appTheme) {
    return Container(
      width: 1,
      height: 34,
      color: appTheme.earthMedium.withValues(alpha: 0.12),
    );
  }

  Widget _buildStatItem(
    AppThemeExtension appTheme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: appTheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(appTheme.radiusMd),
          ),
          child: Icon(icon, color: appTheme.primary, size: 18),
        ),
        AppSpacing.h8,
        Text(
          label,
          style: AppTypography.caption.copyWith(color: appTheme.earthMedium),
        ),
        AppSpacing.h2,
        Text(
          value,
          style: AppTypography.bodyMd.copyWith(color: appTheme.earth),
        ),
      ],
    );
  }

  Widget _buildRecordsList(AppThemeExtension appTheme) {
    final headerStyle = AppTypography.bodySm.copyWith(
      color: appTheme.earthMedium.withValues(alpha: 0.7),
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
        border: Border.all(
          color: appTheme.earthMedium.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        children: [
          // 表头
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text('经期开始时间', style: headerStyle),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text('经期天数', style: headerStyle),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text('周期天数', style: headerStyle),
                ),
              ),
            ],
          ),
          AppSpacing.h16,
          // 数据行
          ..._records.asMap().entries.map((entry) {
            final index = entry.key;
            final record = entry.value;
            final isLast = index == _records.length - 1;

            return Column(
              children: [
                GestureDetector(
                  onLongPress: () => _confirmDelete(record.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            _formatShortDate(record.startDate),
                            style: AppTypography.bodyMd.copyWith(
                              color: appTheme.earth,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              record.durationDays?.toString() ?? '-',
                              style: AppTypography.bodyMd.copyWith(
                                color: appTheme.earth,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              record.cycleLength?.toString() ?? '-',
                              style: AppTypography.bodyMd.copyWith(
                                color: appTheme.earth,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    color: appTheme.earthMedium.withValues(alpha: 0.08),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  /// 短日期格式：YYYY/MM/DD
  String _formatShortDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  double _calculateStdDev(List<int> values) {
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            values.length;
    return sqrt(variance);
  }

  void _confirmDelete(String id) {
    final appTheme = Theme.of(context).appTheme;

    showDialog(
      context: context,
      barrierColor: appTheme.surfaceOverlay,
      builder: (ctx) => AlertDialog(
        backgroundColor: appTheme.cream,
        icon: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: appTheme.rose.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(appTheme.radiusXl),
          ),
          child: Icon(Icons.delete_outline_rounded,
              color: appTheme.rose, size: 32),
        ),
        title: Text(
          '确认删除？',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: appTheme.earth,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          '删除后该记录将无法恢复。',
          style: TextStyle(fontSize: 14, color: appTheme.earthMedium),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: appTheme.earthMedium)),
          ),
          TextButton(
            onPressed: () async {
              await PeriodService.instance.deleteRecord(id);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            child: Text('删除', style: TextStyle(color: appTheme.rose)),
          ),
        ],
      ),
    );
  }
}
