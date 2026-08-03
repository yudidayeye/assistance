import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/foundation/app_spacing.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/utils/format_utils.dart';

/// 报表视图类型
enum ReportViewType {
  expenseTrend, // 支出趋势（月度/阶段，根据筛选条件自动选择）
  expensePie, // 支出占比
}

/// 报表卡片 — 整合支出趋势和支出占比，支持视图切换
class ReportCard extends StatefulWidget {
  final List<Map<String, dynamic>> monthlyData;
  final List<Map<String, dynamic>> stageData;
  final Map<String, double> expenseTypeData;
  final Map<String, double>? stageExpenseTypeData;
  final ReportViewType defaultView;

  const ReportCard({
    super.key,
    required this.monthlyData,
    required this.stageData,
    required this.expenseTypeData,
    this.stageExpenseTypeData,
    this.defaultView = ReportViewType.expensePie,
  });

  @override
  State<ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<ReportCard> {
  ReportViewType _currentView = ReportViewType.expensePie;

  @override
  void initState() {
    super.initState();
    _currentView = widget.defaultView;
  }

  @override
  void didUpdateWidget(ReportCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当 defaultView 变化时，同步更新当前视图
    if (widget.defaultView != oldWidget.defaultView) {
      _currentView = widget.defaultView;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    return Column(
      children: [
        // 标题行 + 视图切换
        _buildHeader(appTheme),
        // 内容区域
        _buildContent(appTheme),
        AppSpacing.h16,
      ],
    );
  }

  /// 构建标题行
  Widget _buildHeader(AppThemeExtension appTheme) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.pageH.left,
        top: AppSpacing.w16.width!,
        right: AppSpacing.pageH.right,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        children: [
          // 标题指示条
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: appTheme.primary,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          AppSpacing.w8,
          // 标题文字
          Text(
            '报表',
            style: AppTypography.bodySm.copyWith(color: appTheme.earth),
          ),
          const Spacer(),
          // 视图切换选择器
          _buildViewSelector(appTheme),
        ],
      ),
    );
  }

  /// 构建视图切换选择器
  Widget _buildViewSelector(AppThemeExtension appTheme) {
    return GestureDetector(
      onTap: () => _showViewPicker(appTheme),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs + 2),
        decoration: BoxDecoration(
          color: appTheme.primaryLight.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(appTheme.radiusSm),
          border: Border.all(color: appTheme.primary.withValues(alpha: 0.4), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getViewLabel(_currentView),
              style: TextStyle(
                fontFamily: GoogleFonts.dmSans().fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: appTheme.primary,
              ),
            ),
            AppSpacing.w4,
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: appTheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  /// 显示视图选择弹窗
  void _showViewPicker(AppThemeExtension appTheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: appTheme.cardBackground,
            borderRadius: BorderRadius.circular(appTheme.radiusXl),
            border: Border.all(color: appTheme.cardBorder, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.lg,
                  top: AppSpacing.lg,
                  right: AppSpacing.lg,
                  bottom: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Text(
                      '切换视图',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: appTheme.earth,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: AppSpacing.lg + 4,
                        height: AppSpacing.lg + 4,
                        decoration: BoxDecoration(
                          color: appTheme.cream,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: appTheme.earthMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildViewOption(
                appTheme: appTheme,
                viewType: ReportViewType.expenseTrend,
                icon: Icons.trending_up_rounded,
                title: '支出趋势',
                subtitle: widget.stageData.isNotEmpty
                    ? '查看各阶段支出变化'
                    : '查看每月支出变化',
              ),
              _buildViewOption(
                appTheme: appTheme,
                viewType: ReportViewType.expensePie,
                icon: Icons.pie_chart_rounded,
                title: '支出占比',
                subtitle: '查看消费类型分布',
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  /// 构建视图选项
  Widget _buildViewOption({
    required AppThemeExtension appTheme,
    required ReportViewType viewType,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _currentView == viewType;

    return GestureDetector(
      onTap: () {
        setState(() => _currentView = viewType);
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? appTheme.primaryLight.withValues(alpha: 0.3) : appTheme.cream,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          border: Border.all(
            color: isSelected ? appTheme.primary.withValues(alpha: 0.4) : appTheme.cardBorder,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // 图标
            Container(
              width: AppSpacing.xl + 4,
              height: AppSpacing.xl + 4,
              decoration: BoxDecoration(
                color: isSelected
                    ? appTheme.primary.withValues(alpha: 0.15)
                    : appTheme.cardBackground,
                borderRadius: BorderRadius.circular(AppSpacing.sm),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? appTheme.primary : appTheme.earthMedium,
              ),
            ),
            AppSpacing.w12,
            // 文字
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? appTheme.primary : appTheme.earth,
                    ),
                  ),
                  AppSpacing.h2,
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: appTheme.earthMedium.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            // 选中标记
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: appTheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  /// 获取视图标签
  String _getViewLabel(ReportViewType viewType) {
    switch (viewType) {
      case ReportViewType.expenseTrend:
        return '支出趋势';
      case ReportViewType.expensePie:
        return '支出占比';
    }
  }

  /// 构建内容区域
  Widget _buildContent(AppThemeExtension appTheme) {
    switch (_currentView) {
      case ReportViewType.expenseTrend:
        // 有阶段数据时显示阶段趋势，否则显示月度趋势
        if (widget.stageData.isNotEmpty &&
            !widget.stageData.every((d) => d['expense'] == 0)) {
          return _buildStageTrend(appTheme);
        }
        return _buildMonthlyTrend(appTheme);
      case ReportViewType.expensePie:
        return _buildExpensePie(appTheme);
    }
  }

  /// 构建月度趋势图
  Widget _buildMonthlyTrend(AppThemeExtension appTheme) {
    if (widget.monthlyData.isEmpty ||
        widget.monthlyData.every((d) => d['expense'] == 0)) {
      return _buildEmptyState(appTheme, '暂无支出数据');
    }

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.pageH.left,
        top: AppSpacing.xxs,
        right: AppSpacing.pageH.right,
        bottom: AppSpacing.xs,
      ),
      child: AspectRatio(
        aspectRatio: 2.2,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: _getHorizontalInterval(),
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: appTheme.creamDark,
                  strokeWidth: 0.5,
                );
              },
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    // 仅在整数位置（数据点）显示标签
                    if (value != value.roundToDouble()) {
                      return const SizedBox.shrink();
                    }
                    final idx = value.toInt();
                    if (idx < 0 || idx >= widget.monthlyData.length) {
                      return const SizedBox.shrink();
                    }
                    final month = widget.monthlyData[idx]['month'] as int;
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '$month月',
                        style: TextStyle(
                          fontFamily: GoogleFonts.dmSans().fontFamily,
                          fontSize: 10,
                          color: appTheme.earthMedium.withValues(alpha: 0.6),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              getTouchedSpotIndicator: (barData, spotIndexes) {
                return spotIndexes.map((index) {
                  return TouchedSpotIndicatorData(
                    FlLine(
                      color: appTheme.primary.withValues(alpha: 0.3),
                      strokeWidth: 0.5,
                      dashArray: [3, 3],
                    ),
                    FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: appTheme.primary,
                          strokeWidth: 2,
                          strokeColor: appTheme.cardBackground,
                        );
                      },
                    ),
                  );
                }).toList();
              },
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (spot) => appTheme.primaryLight.withValues(alpha: 0.22),
                getTooltipItems: (spots) {
                  return spots.map((spot) {
                    final item = widget.monthlyData[spot.x.toInt()];
                    return LineTooltipItem(
                      '${item['month']}月\n${FormatUtils.formatAmount((item['expense'] as num).toDouble())}',
                      TextStyle(
                        fontSize: 12,
                        color: appTheme.earth,
                        fontWeight: FontWeight.w500,
                        fontFamily: GoogleFonts.dmSans().fontFamily,
                      ),
                    );
                  }).toList();
                },
              ),
              touchSpotThreshold: 20,
              handleBuiltInTouches: true,
            ),
            lineBarsData: [
              LineChartBarData(
                spots: _buildSpots(),
                isCurved: true,
                color: appTheme.primary,
                barWidth: 2,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) {
                    return FlDotCirclePainter(
                      radius: 3,
                      color: appTheme.primary,
                      strokeWidth: 1.5,
                      strokeColor: appTheme.cardBackground,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      appTheme.primary.withValues(alpha: 0.2),
                      appTheme.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建阶段趋势图
  Widget _buildStageTrend(AppThemeExtension appTheme) {
    if (widget.stageData.isEmpty ||
        widget.stageData.every((d) => d['expense'] == 0)) {
      return _buildEmptyState(appTheme, '暂无阶段数据');
    }

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.pageH.left,
        top: AppSpacing.xxs,
        right: AppSpacing.pageH.right,
        bottom: AppSpacing.xs,
      ),
      child: AspectRatio(
        aspectRatio: 2.2,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: _getStageHorizontalInterval(),
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: appTheme.creamDark,
                  strokeWidth: 0.5,
                );
              },
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    // 仅在整数位置（数据点）显示标签
                    if (value != value.roundToDouble()) {
                      return const SizedBox.shrink();
                    }
                    final idx = value.toInt();
                    if (idx < 0 || idx >= widget.stageData.length) {
                      return const SizedBox.shrink();
                    }
                    final stage = widget.stageData[idx]['stage'] as int;
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '第$stage阶段',
                        style: TextStyle(
                          fontFamily: GoogleFonts.dmSans().fontFamily,
                          fontSize: 10,
                          color: appTheme.earthMedium.withValues(alpha: 0.6),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              getTouchedSpotIndicator: (barData, spotIndexes) {
                return spotIndexes.map((index) {
                  return TouchedSpotIndicatorData(
                    FlLine(
                      color: appTheme.primary.withValues(alpha: 0.3),
                      strokeWidth: 0.5,
                      dashArray: [3, 3],
                    ),
                    FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: appTheme.primary,
                          strokeWidth: 2,
                          strokeColor: appTheme.cardBackground,
                        );
                      },
                    ),
                  );
                }).toList();
              },
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (spot) => appTheme.primaryLight.withValues(alpha: 0.22),
                getTooltipItems: (spots) {
                  return spots.map((spot) {
                    final item = widget.stageData[spot.x.toInt()];
                    return LineTooltipItem(
                      '第${item['stage']}阶段\n${FormatUtils.formatAmount((item['expense'] as num).toDouble())}',
                      TextStyle(
                        fontSize: 12,
                        color: appTheme.earth,
                        fontWeight: FontWeight.w500,
                        fontFamily: GoogleFonts.dmSans().fontFamily,
                      ),
                    );
                  }).toList();
                },
              ),
              touchSpotThreshold: 20,
              handleBuiltInTouches: true,
            ),
            lineBarsData: [
              LineChartBarData(
                spots: _buildStageSpots(),
                isCurved: true,
                color: appTheme.primary,
                barWidth: 2,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) {
                    return FlDotCirclePainter(
                      radius: 3,
                      color: appTheme.primary,
                      strokeWidth: 1.5,
                      strokeColor: appTheme.cardBackground,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      appTheme.primary.withValues(alpha: 0.2),
                      appTheme.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 分类显示顺序和颜色映射
  static const _categoryOrder = ['购物', '生活', '工作', '娱乐', '大餐', '其他', 'balance'];

  Color _categoryColor(String key, AppThemeExtension appTheme) {
    switch (key) {
      case '购物':
        return appTheme.sage;
      case '生活':
        return appTheme.primary;
      case '工作':
        return const Color(0xFF3E6FA0);
      case '娱乐':
        return const Color(0xFFC49A6C);
      case '大餐':
        return appTheme.rose;
      case '其他':
        return appTheme.earthMedium;
      case 'balance':
        return appTheme.primaryLight;
      default:
        return appTheme.earthMedium;
    }
  }

  String _categoryLabel(String key) {
    return key == 'balance' ? '结余' : key;
  }

  /// 构建支出占比图
  Widget _buildExpensePie(AppThemeExtension appTheme) {
    // 选中阶段时使用阶段维度的数据，否则使用全局汇总
    final data = widget.stageExpenseTypeData ?? widget.expenseTypeData;

    // 筛选有数据的分类（排除 balance），按金额从大到小排序
    final entries = _categoryOrder
        .where((k) => k != 'balance' && (data[k] ?? 0) > 0)
        .map((k) => MapEntry(k, data[k]!))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return _buildEmptyState(appTheme, '暂无支出数据');
    }

    final total = entries.fold(0.0, (sum, e) => sum + e.value);
    final monthCount = widget.monthlyData.isNotEmpty ? widget.monthlyData.length : 1;

    return Padding(
      padding: AppSpacing.pageH,
      child: Row(
        children: [
          // 饼图
          Expanded(
            flex: 5,
            child: AspectRatio(
              aspectRatio: 1,
              child: PieChart(
                PieChartData(
                  sections: entries.map((e) {
                    final pct = total > 0 ? e.value / total : 0.0;
                    return _buildPieSection(
                      value: e.value,
                      color: _categoryColor(e.key, appTheme),
                      title: _categoryLabel(e.key),
                      pct: pct,
                    );
                  }).toList(),
                  centerSpaceRadius: 28,
                  sectionsSpace: 2,
                  startDegreeOffset: -90,
                ),
              ),
            ),
          ),
          AppSpacing.w16,
          // 图例
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: entries.asMap().entries.map((indexed) {
                final e = indexed.value;
                final pct = total > 0 ? e.value / total : 0.0;
                final avg = e.value / monthCount;
                return Padding(
                  padding: EdgeInsets.only(top: indexed.key > 0 ? 14 : 0),
                  child: _buildLegend(
                    appTheme: appTheme,
                    label: _categoryLabel(e.key),
                    color: _categoryColor(e.key, appTheme),
                    value: avg,
                    pct: pct,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(AppThemeExtension appTheme, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 32,
              color: appTheme.earthMedium.withValues(alpha: 0.3),
            ),
            AppSpacing.h8,
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _buildSpots() {
    final spots = <FlSpot>[];
    for (int i = 0; i < widget.monthlyData.length; i++) {
      final expense = widget.monthlyData[i]['expense'] as num;
      spots.add(FlSpot(i.toDouble(), expense.toDouble()));
    }
    return spots;
  }

  double _getHorizontalInterval() {
    if (widget.monthlyData.isEmpty) return 1000;
    final maxExpense = widget.monthlyData
        .map((d) => (d['expense'] as num).toDouble())
        .reduce((a, b) => a > b ? a : b);
    if (maxExpense <= 0) return 1000;
    if (maxExpense <= 1000) return 200;
    if (maxExpense <= 5000) return 1000;
    if (maxExpense <= 10000) return 2000;
    return 5000;
  }

  List<FlSpot> _buildStageSpots() {
    final spots = <FlSpot>[];
    for (int i = 0; i < widget.stageData.length; i++) {
      final expense = widget.stageData[i]['expense'] as num;
      spots.add(FlSpot(i.toDouble(), expense.toDouble()));
    }
    return spots;
  }

  double _getStageHorizontalInterval() {
    if (widget.stageData.isEmpty) return 1000;
    final maxExpense = widget.stageData
        .map((d) => (d['expense'] as num).toDouble())
        .reduce((a, b) => a > b ? a : b);
    if (maxExpense <= 0) return 1000;
    if (maxExpense <= 1000) return 200;
    if (maxExpense <= 5000) return 1000;
    if (maxExpense <= 10000) return 2000;
    return 5000;
  }

  PieChartSectionData _buildPieSection({
    required double value,
    required Color color,
    required String title,
    required double pct,
  }) {
    // fl_chart 0.69.2 badge 渲染器在相邻扇区时存在越界 bug，暂时关闭 badge
    return PieChartSectionData(
      value: value > 0 ? value : 0.001,
      color: color,
      title: '',
      badgeWidget: null,
      titlePositionPercentageOffset: 0.5,
    );
  }

  Widget _buildLegend({
    required AppThemeExtension appTheme,
    required String label,
    required Color color,
    required double value,
    required double pct,
  }) {
    return Row(
      children: [
        Container(
          width: AppSpacing.xs,
          height: AppSpacing.xs,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        AppSpacing.w8,
        Text(
          label,
          style: AppTypography.bodySm.copyWith(color: appTheme.earth),
        ),
        AppSpacing.w4,
        Text(
          '${(pct * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            fontFamily: GoogleFonts.dmSans().fontFamily,
            fontSize: 11,
            color: appTheme.earth,
          ),
        ),
        const Spacer(),
        Text(
          FormatUtils.formatAmount(value),
          style: TextStyle(
            fontFamily: GoogleFonts.dmSans().fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
