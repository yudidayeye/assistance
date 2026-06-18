import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/stats_service.dart';
import '../widgets/pie_chart.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../core/theme/theme_extension.dart';

/// 月度统计页 — 奢华自然主义风格
class AccountingStatsPage extends StatefulWidget {
  const AccountingStatsPage({super.key});

  @override
  State<AccountingStatsPage> createState() => _AccountingStatsPageState();
}

class _AccountingStatsPageState extends State<AccountingStatsPage>
    with SingleTickerProviderStateMixin {
  DateTime _selectedMonth = DateTime.now();
  List<CategoryStats> _stats = [];
  Map<String, double> _overview = {};
  bool _loading = true;
  late AnimationController _chartController;
  late Animation<double> _chartFadeAnim;

  @override
  void initState() {
    super.initState();
    _chartController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _chartFadeAnim = CurvedAnimation(
      parent: _chartController,
      curve: Curves.easeOut,
    );
    _loadData();
  }

  @override
  void dispose() {
    _chartController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    _chartController.reset();

    final stats =
        await StatsService.instance.getExpenseStatsByCategory(_selectedMonth);
    final overview =
        await StatsService.instance.getMonthOverview(_selectedMonth);

    if (mounted) {
      setState(() {
        _stats = stats;
        _overview = overview;
        _loading = false;
      });
      _chartController.forward();
    }
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
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;

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
                // 头部区域
                SliverToBoxAdapter(
                  child: _buildHeader(context, appTheme),
                ),

                // 月份切换
                SliverToBoxAdapter(
                  child: _buildMonthSwitcher(appTheme),
                ),

                // 收支概览卡片
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _chartFadeAnim,
                    child: _buildOverviewCard(appTheme),
                  ),
                ),

                // 饼图
                if (_stats.isNotEmpty)
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _chartFadeAnim,
                      child: _buildChartCard(appTheme),
                    ),
                  ),

                // 分类明细
                if (_stats.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildSectionHeader(appTheme, '分类明细'),
                  ),

                if (_stats.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildStatsList(appTheme),
                  ),

                // 空状态
                if (_stats.isEmpty)
                  SliverFillRemaining(
                    child: _buildEmptyState(appTheme),
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
            '月度统计',
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

  Widget _buildMonthSwitcher(AppThemeExtension appTheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
              onTap: () => _changeMonth(-1),
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
            Text(
              '${_selectedMonth.year}年${_selectedMonth.month}月',
              style: TextStyle(
                fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: appTheme.earth,
              ),
            ),

            // 下一月按钮
            GestureDetector(
              onTap: () => _changeMonth(1),
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

  Widget _buildOverviewCard(AppThemeExtension appTheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            appTheme.earth,
            appTheme.earthLight,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: appTheme.earth.withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // 标题
          Text(
            '收支概览',
            style: TextStyle(
              fontSize: 14,
              color: appTheme.cream.withAlpha(180),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),

          // 三个指标
          Row(
            children: [
              Expanded(
                child: _buildOverviewItem(
                  appTheme,
                  label: '收入',
                  value: _overview['income'] ?? 0,
                  color: appTheme.sage,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: appTheme.cream.withAlpha(30),
              ),
              Expanded(
                child: _buildOverviewItem(
                  appTheme,
                  label: '支出',
                  value: _overview['expense'] ?? 0,
                  color: appTheme.rose,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: appTheme.cream.withAlpha(30),
              ),
              Expanded(
                child: _buildOverviewItem(
                  appTheme,
                  label: '结余',
                  value: _overview['balance'] ?? 0,
                  color: appTheme.primary,
                ),
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
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: appTheme.cream.withAlpha(150),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          FormatUtils.formatAmount(value),
          style: TextStyle(
            fontFamily: GoogleFonts.playfairDisplay().fontFamily,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: appTheme.earthMedium.withAlpha(20),
        ),
      ),
      child: Column(
        children: [
          // 标题
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

          // 饼图
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: appTheme.earthMedium.withAlpha(20),
        ),
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
                  color: appTheme.earthMedium.withAlpha(15),
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
          // 分类图标
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: appTheme.rose.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              stat.category.icon,
              color: appTheme.rose,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),

          // 分类名称
          Expanded(
            child: Text(
              stat.category.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: appTheme.earth,
              ),
            ),
          ),

          // 金额和占比
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                FormatUtils.formatAmount(stat.total),
                style: TextStyle(
                  fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: appTheme.earth,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                FormatUtils.formatPercent(stat.percent),
                style: TextStyle(
                  fontSize: 13,
                  color: appTheme.earthMedium,
                ),
              ),
            ],
          ),
        ],
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
              color: appTheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.bar_chart_rounded,
              color: appTheme.primary.withAlpha(100),
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '暂无统计数据',
            style: TextStyle(
              fontSize: 16,
              color: appTheme.earthMedium,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '本月还没有记录哦',
            style: TextStyle(
              fontSize: 14,
              color: appTheme.earthMedium.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }
}
