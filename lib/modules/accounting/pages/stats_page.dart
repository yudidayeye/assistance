import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/stats_service.dart';
import '../widgets/pie_chart.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../core/theme/theme_extension.dart';

/// 月度统计页 — 柔和风格
class AccountingStatsPage extends StatefulWidget {
  const AccountingStatsPage({super.key});

  @override
  State<AccountingStatsPage> createState() => _AccountingStatsPageState();
}

class _AccountingStatsPageState extends State<AccountingStatsPage> {
  DateTime _selectedMonth = DateTime.now();
  List<CategoryStats> _stats = [];
  Map<String, double> _overview = {};
  bool _loading = true;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final version = ++_loadVersion;
    setState(() => _loading = true);

    final stats =
        await StatsService.instance.getExpenseStatsByCategory(_selectedMonth);
    final overview =
        await StatsService.instance.getMonthOverview(_selectedMonth);

    if (!mounted || version != _loadVersion) return;
    setState(() {
      _stats = stats;
      _overview = overview;
      _loading = false;
    });
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + offset, 1);
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    return Scaffold(
      backgroundColor: appTheme.cream,
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: appTheme.primary,
              ),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(context, appTheme),
                ),
                SliverToBoxAdapter(
                  child: _buildMonthSwitcher(appTheme),
                ),
                SliverToBoxAdapter(
                  child: _buildOverviewCard(appTheme),
                ),
                if (_stats.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildChartCard(appTheme),
                  ),
                if (_stats.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildSectionHeader(appTheme, '分类明细'),
                  ),
                if (_stats.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildStatsList(appTheme),
                  ),
                if (_stats.isEmpty)
                  SliverFillRemaining(
                    child: EmptyStateWidget(
                      icon: Icons.bar_chart_rounded,
                      title: '暂无统计数据',
                      subtitle: '本月还没有记录哦',
                      iconColor: appTheme.primary,
                    ),
                  ),
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
            '月度统计',
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

  Widget _buildMonthSwitcher(AppThemeExtension appTheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => _changeMonth(-1),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: appTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(appTheme.radiusMd),
              ),
              child: Icon(
                Icons.chevron_left_rounded,
                color: appTheme.earthMedium,
                size: 20,
              ),
            ),
          ),
          Text(
            '${_selectedMonth.year}年${_selectedMonth.month}月',
            style: TextStyle(
              fontFamily: GoogleFonts.dmSans().fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: appTheme.earth,
            ),
          ),
          GestureDetector(
            onTap: () => _changeMonth(1),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: appTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(appTheme.radiusMd),
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
    );
  }

  Widget _buildOverviewCard(AppThemeExtension appTheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusLg),
        boxShadow: appTheme.cardShadow,
      ),
      child: Column(
        children: [
          Text(
            '收支概览',
            style: TextStyle(
              fontSize: 14,
              color: appTheme.earthMedium,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildOverviewItem(appTheme,
                    label: '收入',
                    value: _overview['income'] ?? 0,
                    color: appTheme.sage),
              ),
              Container(
                width: 1,
                height: 50,
                color: appTheme.earthMedium.withValues(alpha: 0.12),
              ),
              Expanded(
                child: _buildOverviewItem(appTheme,
                    label: '支出',
                    value: _overview['expense'] ?? 0,
                    color: appTheme.rose),
              ),
              Container(
                width: 1,
                height: 50,
                color: appTheme.earthMedium.withValues(alpha: 0.12),
              ),
              Expanded(
                child: _buildOverviewItem(appTheme,
                    label: '结余',
                    value: _overview['balance'] ?? 0,
                    color: appTheme.primary,
                    isBalance: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewItem(
    AppThemeExtension appTheme, {
    required String label,
    required double value,
    required Color color,
    bool isBalance = false,
  }) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: appTheme.earthMedium)),
        const SizedBox(height: 8),
        Text(
          isBalance
              ? FormatUtils.formatBalance(value)
              : FormatUtils.formatAmount(value),
          style: TextStyle(
            fontFamily: GoogleFonts.dmSans().fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildChartCard(AppThemeExtension appTheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusLg),
        boxShadow: appTheme.cardShadow,
      ),
      child: Column(
        children: [
          Text(
            '支出分类占比',
            style: TextStyle(
              fontFamily: GoogleFonts.playfairDisplay().fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: appTheme.earth,
            ),
          ),
          const SizedBox(height: 20),
          ExpensePieChart(stats: _stats),
        ],
      ),
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

  Widget _buildStatsList(AppThemeExtension appTheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusLg),
        boxShadow: appTheme.cardShadow,
      ),
      child: Column(
        children: _stats.asMap().entries.map((entry) {
          final index = entry.key;
          final stat = entry.value;
          final isLast = index == _stats.length - 1;
          return Column(
            children: [
              _buildStatItem(appTheme, stat),
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

  Widget _buildStatItem(AppThemeExtension appTheme, CategoryStats stat) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: appTheme.rose.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(appTheme.radiusSm),
            ),
            child: Icon(stat.category.icon, color: appTheme.rose, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              stat.category.name,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: appTheme.earth),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                FormatUtils.formatAmount(stat.total),
                style: TextStyle(
                  fontFamily: GoogleFonts.dmSans().fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: appTheme.earth,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                FormatUtils.formatPercent(stat.percent),
                style: TextStyle(fontSize: 13, color: appTheme.earthMedium),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
