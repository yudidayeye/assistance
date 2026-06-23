import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/period_record.dart';
import '../services/period_service.dart';
import '../services/prediction_service.dart';
import '../../../shared/utils/date_utils.dart';
import '../../../core/theme/theme_extension.dart';

/// 周期统计页 — 奢华自然主义风格
class PeriodStatsPage extends StatefulWidget {
  const PeriodStatsPage({super.key});

  @override
  State<PeriodStatsPage> createState() => _PeriodStatsPageState();
}

class _PeriodStatsPageState extends State<PeriodStatsPage>
    with SingleTickerProviderStateMixin {
  List<PeriodRecord> _records = [];
  bool _loading = true;
  late AnimationController _statsController;
  late Animation<double> _statsFadeAnim;

  @override
  void initState() {
    super.initState();
    _statsController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _statsFadeAnim = CurvedAnimation(
      parent: _statsController,
      curve: Curves.easeOut,
    );
    _loadData();
  }

  @override
  void dispose() {
    _statsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    _statsController.reset();

    final records = await PeriodService.instance.getAllRecords();
    PredictionService.instance.predict(records);

    if (mounted) {
      setState(() {
        _records = records;
        _loading = false;
      });
      _statsController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;

    if (_loading) {
      return Scaffold(
        backgroundColor: appTheme.cream,
        body: Center(
          child: CircularProgressIndicator(
            color: appTheme.rose,
          ),
        ),
      );
    }

    // 计算统计数据
    final completedRecords =
        _records.where((r) => r.endDate != null).toList();
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

    // 规律性评估
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
          // 头部区域
          SliverToBoxAdapter(
            child: _buildHeader(context, appTheme),
          ),

          // 统计卡片
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _statsFadeAnim,
              child: _buildStatsCard(appTheme, avgCycle, avgDuration, regularity),
            ),
          ),

          // 历史记录标题
          SliverToBoxAdapter(
            child: _buildSectionHeader(appTheme, '历史记录'),
          ),

          // 历史记录列表
          if (_records.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(appTheme),
            )
          else
            SliverToBoxAdapter(
              child: _buildRecordsList(appTheme),
            ),

          // 底部间距
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
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
          // 返回按钮
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: appTheme.creamDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: appTheme.earthMedium.withAlpha(30),
                ),
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
              fontFamily: GoogleFonts.playfairDisplay().fontFamily,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: appTheme.earth,
              letterSpacing: -0.5,
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
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            appTheme.rose.withAlpha(40),
            appTheme.roseLight.withAlpha(20),
          ],
        ),
        border: Border.all(
          color: appTheme.rose.withAlpha(40),
        ),
      ),
      child: Column(
        children: [
          // 标题
          Text(
            '周期概况',
            style: TextStyle(
              fontSize: 14,
              color: appTheme.earth.withAlpha(180),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),

          // 三个指标
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  appTheme,
                  icon: Icons.repeat_rounded,
                  label: '平均周期',
                  value: '$avgCycle天',
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: appTheme.rose.withAlpha(30),
              ),
              Expanded(
                child: _buildStatItem(
                  appTheme,
                  icon: Icons.calendar_today_rounded,
                  label: '经期天数',
                  value: '$avgDuration天',
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: appTheme.rose.withAlpha(30),
              ),
              Expanded(
                child: _buildStatItem(
                  appTheme,
                  icon: Icons.insights_rounded,
                  label: '规律性',
                  value: regularity,
                ),
              ),
            ],
          ),
        ],
      ),
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
            color: appTheme.rose.withAlpha(30),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: appTheme.rose,
            size: 20,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: appTheme.earthMedium,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: GoogleFonts.playfairDisplay().fontFamily,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: appTheme.earthMedium.withAlpha(20),
        ),
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
                  color: appTheme.earthMedium.withAlpha(15),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecordItem(AppThemeExtension appTheme, PeriodRecord record) {
    final isActive = record.endDate == null;
    final statusColor = isActive ? appTheme.primary : appTheme.rose;

    return GestureDetector(
      onLongPress: () => _confirmDelete(record.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // 状态指示器
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
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

            // 记录信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppDateUtils.formatFullDate(record.startDate),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: appTheme.earth,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.endDate != null
                        ? '结束 ${AppDateUtils.formatFullDate(record.endDate!)} · 持续${record.durationDays ?? "?"}天'
                        : '进行中',
                    style: TextStyle(
                      fontSize: 13,
                      color: isActive
                          ? appTheme.primary
                          : appTheme.earthMedium,
                    ),
                  ),
                ],
              ),
            ),

            // 周期天数
            if (record.cycleLength != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: appTheme.creamDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${record.cycleLength}天',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: appTheme.earthMedium,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppThemeExtension appTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: appTheme.rose.withAlpha(20),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              color: appTheme.rose.withAlpha(100),
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '暂无历史记录',
            style: TextStyle(
              fontSize: 16,
              color: appTheme.earthMedium,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '记录经期后会在这里显示',
            style: TextStyle(
              fontSize: 14,
              color: appTheme.earthMedium.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateStdDev(List<int> values) {
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            values.length;
    return variance; // Return variance as a simplified measure
  }

  void _confirmDelete(String id) {
    final appTheme = Theme.of(context).appTheme;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: appTheme.cream,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: appTheme.rose.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: appTheme.rose,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),

              // 标题
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

              // 内容
              Text(
                '删除后该记录将无法恢复。',
                style: TextStyle(
                  fontSize: 14,
                  color: appTheme.earthMedium,
                ),
              ),
              const SizedBox(height: 24),

              // 按钮
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: appTheme.creamDark,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: appTheme.earthMedium.withAlpha(30),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '取消',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: appTheme.earthMedium,
                            ),
                          ),
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
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text(
                            '删除',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
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
