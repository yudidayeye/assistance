import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/period_record.dart';
import '../services/period_service.dart';
import '../services/prediction_service.dart';
import '../../../shared/utils/date_utils.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../core/theme/theme_extension.dart';

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
    setState(() => _loading = true);

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

    return Scaffold(
      backgroundColor: appTheme.cream,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(context, appTheme),
          ),
          SliverToBoxAdapter(
            child: _buildStatsCard(appTheme, avgCycle, avgDuration, regularity),
          ),
          SliverToBoxAdapter(
            child: _buildSectionHeader(appTheme, '历史记录'),
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
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppThemeExtension appTheme) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.of(context).padding.top + 16, 24, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: appTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(appTheme.radiusMd),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: appTheme.earthMedium,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '周期统计',
            style: TextStyle(
              fontFamily: GoogleFonts.dmSans().fontFamily,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: appTheme.earth,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(AppThemeExtension appTheme, int avgCycle,
      int avgDuration, String regularity) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusLg),
        boxShadow: appTheme.cardShadow,
      ),
      child: Column(
        children: [
          Text(
            '周期概况',
            style: TextStyle(
                fontSize: 14,
                color: appTheme.earthMedium,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(appTheme,
                    icon: Icons.repeat_rounded,
                    label: '平均周期',
                    value: '$avgCycle天'),
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
                    icon: Icons.insights_rounded,
                    label: '规律性',
                    value: regularity),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(AppThemeExtension appTheme) {
    return Container(
      width: 1,
      height: 60,
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: appTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(appTheme.radiusSm),
          ),
          child: Icon(icon, color: appTheme.primary, size: 20),
        ),
        const SizedBox(height: 12),
        Text(label,
            style: TextStyle(fontSize: 12, color: appTheme.earthMedium)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: GoogleFonts.dmSans().fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: appTheme.earth,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(AppThemeExtension appTheme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: GoogleFonts.playfairDisplay().fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: appTheme.earth,
        ),
      ),
    );
  }

  Widget _buildRecordsList(AppThemeExtension appTheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusLg),
        boxShadow: appTheme.cardShadow,
      ),
      child: Column(
        children: _records.asMap().entries.map((entry) {
          final index = entry.key;
          final record = entry.value;
          final isLast = index == _records.length - 1;
          return Column(
            children: [
              _buildRecordItem(appTheme, record),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 60,
                  color: appTheme.earthMedium.withValues(alpha: 0.1),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecordItem(AppThemeExtension appTheme, PeriodRecord record) {
    final isActive = record.endDate == null;
    final statusColor = isActive ? appTheme.rose : appTheme.earthMedium;

    return GestureDetector(
      onLongPress: () => _confirmDelete(record.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(appTheme.radiusSm),
              ),
              child: Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppDateUtils.formatFullDate(record.startDate),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: appTheme.earth),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.endDate != null
                        ? '结束 ${AppDateUtils.formatFullDate(record.endDate!)} · 持续${record.durationDays ?? "?"}天'
                        : '进行中',
                    style: TextStyle(
                      fontSize: 13,
                      color: isActive ? appTheme.rose : appTheme.earthMedium,
                    ),
                  ),
                ],
              ),
            ),
            if (record.cycleLength != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: appTheme.creamDark,
                  borderRadius: BorderRadius.circular(appTheme.radiusSm),
                ),
                child: Text(
                  '${record.cycleLength}天',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: appTheme.earthMedium),
                ),
              ),
          ],
        ),
      ),
    );
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
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: appTheme.cream,
            borderRadius: BorderRadius.circular(appTheme.radiusXl),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: appTheme.rose.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.delete_outline_rounded,
                    color: appTheme.rose, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                '确认删除？',
                style: TextStyle(
                  fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: appTheme.earth,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '删除后该记录将无法恢复。',
                style: TextStyle(fontSize: 14, color: appTheme.earthMedium),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: appTheme.creamDark,
                          borderRadius:
                              BorderRadius.circular(appTheme.radiusMd),
                        ),
                        child: Center(
                          child: Text('取消',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: appTheme.earthMedium)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        await PeriodService.instance.deleteRecord(id);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadData();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: appTheme.rose,
                          borderRadius:
                              BorderRadius.circular(appTheme.radiusMd),
                        ),
                        child: const Center(
                          child: Text('删除',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
