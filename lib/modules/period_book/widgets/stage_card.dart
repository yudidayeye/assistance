import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/foundation/app_spacing.dart';
import '../models/stage_record.dart';
import '../models/addition_record.dart';
import '../services/period_book_service.dart';

/// 阶段卡片组件 — 纯汇总展示，当前阶段（今日所在区间）边框强调
class StageCard extends StatefulWidget {
  final StageRecord stage;
  final StageCalculations stageCalc;
  final double previousBalance;
  final List<AdditionRecord> additions;
  final VoidCallback? onEditBalance;
  final VoidCallback? onEdit;
  /// 是否显示头部行（标题 + 日期）。阶段编辑页传 false 避免与页面标题重复
  final bool showHeader;
  /// 是否默认展开支出明细
  final bool expandExpenseByDefault;
  /// 个人支出分类明细（用于饼图展示），key 为分类名，value 为金额
  final Map<String, double>? personalExpenseBreakdown;

  const StageCard({
    super.key,
    required this.stage,
    required this.stageCalc,
    required this.previousBalance,
    required this.additions,
    this.onEditBalance,
    this.onEdit,
    this.showHeader = true,
    this.expandExpenseByDefault = false,
    this.personalExpenseBreakdown,
  });

  @override
  State<StageCard> createState() => _StageCardState();
}

class _StageCardState extends State<StageCard> {
  late bool _expenseExpanded;
  late bool _baseExpanded;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _expenseExpanded = widget.expandExpenseByDefault || _isCurrentStage;
    _baseExpanded = false;
  }

  @override
  void didUpdateWidget(covariant StageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stage.id != widget.stage.id) {
      _expenseExpanded = widget.expandExpenseByDefault || _isCurrentStage;
      _baseExpanded = false;
    }
  }

  // 未开始阶段：开始日期晚于今天
  bool get _isFutureStage {
    final start = DateTime.parse(widget.stage.startDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = DateTime(start.year, start.month, start.day);
    return startDate.difference(today).inDays > 0;
  }

  bool get _isCurrentStage {
    final start = DateTime.parse(widget.stage.startDate);
    final end = DateTime.parse(widget.stage.endDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    return today.difference(startDate).inDays >= 0 &&
        endDate.difference(today).inDays >= 0;
  }

  double get _totalExpense {
    final living = widget.stageCalc.livingTotal ?? 0;
    if (_isBalanceOverridden) {
      return widget.stageCalc.shoppingTotal + widget.stageCalc.otherTotal;
    }
    return widget.stageCalc.shoppingTotal +
        widget.stageCalc.otherTotal +
        living;
  }

  /// 余额是否大于计算值（本金 + 追加 - 个人支出 - 其他支出），说明用户手动修改过余额
  bool get _isBalanceOverridden {
    final balance = widget.stageCalc.balance;
    if (balance == null) return false;
    final expected = widget.previousBalance +
        widget.stageCalc.additionsTotal -
        widget.stageCalc.shoppingTotal -
        widget.stageCalc.otherTotal;
    return balance > expected;
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    final isCurrentStage = _isCurrentStage;
    final canExpandBase = widget.stageCalc.additionsTotal > 0;

    // 未开始阶段：紧凑单行展示（参考设计图第四阶段）
    if (_isFutureStage) {
      return _buildFutureCard(appTheme);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs), // 更紧凑
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusMd), // Apple 风格
        border: Border.all(
          color: isCurrentStage
              ? appTheme.primary.withValues(alpha: 0.55)
              : appTheme.earthMedium.withValues(alpha: 0.15),
          width: isCurrentStage ? 1.2 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showHeader)
            GestureDetector(
              onTap: widget.onEdit,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.xs), // 更紧凑
                child: _buildHeaderRow(appTheme),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.sm,
              widget.showHeader ? 0 : AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.xs,
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _buildBaseMetric(appTheme)),
                    Expanded(child: _buildExpenseMetric(appTheme)),
                    Expanded(child: _buildBalanceMetric(appTheme)),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: _baseExpanded && canExpandBase
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildBaseBreakdown(appTheme),
                        )
                      : const SizedBox.shrink(),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: _expenseExpanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildExpenseBreakdown(appTheme),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 本金列：水平三列之一，左对齐，显示本阶段真实本金（上阶段余额 + 追加）
  Widget _buildBaseMetric(AppThemeExtension appTheme) {
    final canExpand = widget.stageCalc.additionsTotal > 0;
    return _buildMetric(
      appTheme: appTheme,
      label: '本金',
      align: CrossAxisAlignment.center,
      onTap: canExpand
          ? () => setState(() {
                _baseExpanded = !_baseExpanded;
                if (_baseExpanded) _expenseExpanded = false;
              })
          : null,
      labelTrailing: canExpand
          ? AnimatedRotation(
              turns: _baseExpanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: appTheme.earthMedium.withValues(alpha: 0.42),
              ),
            )
          : null,
      value: Text(
        '¥${widget.stageCalc.baseAmount.toStringAsFixed(2)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _amountStyle(appTheme, color: appTheme.earth, fontSize: 12),
      ),
    );
  }

  // 支行列：水平三列之一，居中，金额右侧带展开/收起箭头
  Widget _buildExpenseMetric(AppThemeExtension appTheme) {
    return _buildMetric(
      appTheme: appTheme,
      label: '支出',
      align: CrossAxisAlignment.center,
      onTap: () => setState(() {
        _expenseExpanded = !_expenseExpanded;
        if (_expenseExpanded) _baseExpanded = false;
      }),
      labelTrailing: AnimatedRotation(
        turns: _expenseExpanded ? 0.25 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Icon(
          Icons.chevron_right_rounded,
          size: 16,
          color: appTheme.earthMedium.withValues(alpha: 0.42),
        ),
      ),
      value: Text(
        '-¥${_totalExpense.abs().toStringAsFixed(2)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _amountStyle(appTheme, color: appTheme.rose, fontSize: 12),
      ),
    );
  }

  // 水平指标通用骨架：标签在上、值在下，按列对齐，可选整体点击；
  // labelTrailing 为标题行尾的小图标（展开箭头 / 编辑图标）
  Widget _buildMetric({
    required AppThemeExtension appTheme,
    required String label,
    required Widget value,
    Widget? labelTrailing,
    CrossAxisAlignment align = CrossAxisAlignment.start,
    VoidCallback? onTap,
  }) {
    final labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: appTheme.earthMedium.withValues(alpha: 0.9),
    );
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Column(
        crossAxisAlignment: align,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 18,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 左侧占位与右侧[间距+图标盒]等宽，保证标题居中而不被图标顶偏
                if (labelTrailing != null) const SizedBox(width: 20),
                Flexible(
                  child: Text(
                    label,
                    style: labelStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (labelTrailing != null) ...[
                  const SizedBox(width: 2),
                  SizedBox(
                    width: 18,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: labelTrailing,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(height: 22, child: value),
        ],
      ),
    );
    if (onTap == null) return content;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }

  Widget _buildExpenseBreakdown(AppThemeExtension appTheme) {
    final breakdown = widget.personalExpenseBreakdown;
    final hasBreakdown = breakdown != null && breakdown.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 4, 8),
      child: Container(
        decoration: BoxDecoration(
          color: appTheme.cardBackground.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(appTheme.radiusMd),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧饼图 — 盒子需完整容纳饼图（含图标徽章），
            // 超出盒子绘制的部分无法命中点击手势
            if (hasBreakdown)
              Padding(
                padding: const EdgeInsets.only(right: 13),
                child: SizedBox(
                  width: 116,
                  height: 116,
                  child: _buildMiniPieChart(appTheme, breakdown!),
                ),
              ),
            // 右侧明细 — 金额右对齐
            Expanded(
              child: Column(
                children: [
                  _buildCategoryRow(
                    appTheme: appTheme,
                    icon: Icons.shopping_cart_outlined,
                    label: '个人消费',
                    amountText:
                        '-¥${widget.stageCalc.shoppingTotal.toStringAsFixed(2)}',
                  ),
                  _buildSoftDivider(appTheme),
                  _buildCategoryRow(
                    appTheme: appTheme,
                    icon: Icons.more_horiz,
                    label: '其他消费',
                    amountText:
                        '-¥${widget.stageCalc.otherTotal.toStringAsFixed(2)}',
                  ),
                  _buildSoftDivider(appTheme),
                  _buildBalanceRow(appTheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPieChart(
      AppThemeExtension appTheme, Map<String, double> breakdown) {
    final total = breakdown.values.fold(0.0, (sum, v) => sum + v);
    if (total <= 0) return const SizedBox.shrink();

    final colorMap = {
      '生活': appTheme.sage.withValues(alpha: 0.72),
      '购物': const Color(0xFF8B7EC8).withValues(alpha: 0.72),
      '工作': const Color(0xFF3E6FA0).withValues(alpha: 0.72),
      '娱乐': const Color(0xFFE88D67).withValues(alpha: 0.72),
      '大餐': appTheme.rose.withValues(alpha: 0.72),
      '杂项': const Color(0xFFD4A76A).withValues(alpha: 0.72),
      '其他': const Color(0xFF4DB6AC).withValues(alpha: 0.72),
    };

    final sortedEntries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final pctMap = {for (final e in sortedEntries) e.key: total > 0 ? e.value / total : 0.0};

    return Stack(
      clipBehavior: Clip.none,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // 116 = 饼图原始尺寸（中心空洞 18 + 扇区半径 40 的直径），
            // 图表盒子与绘制范围一致，扇区与分类图标均可命中点击手势
            final size = constraints.biggest.shortestSide.clamp(0.0, 116.0);
            final ratio = size / 116;
            final centerRadius = 18 * ratio;
            final sectionRadius = size / 2 - centerRadius;

            final sections = sortedEntries.asMap().entries.map((indexed) {
              final entry = indexed.value;
              final icon = _categoryIcon(entry.key);
              final pct = pctMap[entry.key]!;
              final showBadge = icon != null && pct >= 0.05;
              return PieChartSectionData(
                value: entry.value,
                color: colorMap[entry.key] ?? appTheme.earthMedium,
                radius: sectionRadius,
                showTitle: false,
                badgeWidget: showBadge
                    ? IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            icon,
                            size: 10,
                            color:
                                colorMap[entry.key] ?? appTheme.earthMedium,
                          ),
                        ),
                      )
                    : null,
                badgePositionPercentageOffset: 0.65,
              );
            }).toList();

            return Center(
              child: SizedBox(
                width: size,
                height: size,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: centerRadius,
                    sectionsSpace: 1.5 * ratio,
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        // 只响应点击事件，忽略悬浮
                        if (event is! FlTapDownEvent) return;
                        if (pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          if (_touchedIndex != null) {
                            setState(() => _touchedIndex = null);
                          }
                          return;
                        }
                        final newIndex =
                            pieTouchResponse.touchedSection!.touchedSectionIndex;
                        if (newIndex < 0 || newIndex >= sortedEntries.length) {
                          if (_touchedIndex != null) {
                            setState(() => _touchedIndex = null);
                          }
                        } else if (newIndex == _touchedIndex) {
                          // 再次点击同一扇区则取消选中
                          setState(() => _touchedIndex = null);
                        } else {
                          setState(() => _touchedIndex = newIndex);
                        }
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (_touchedIndex != null &&
            _touchedIndex! >= 0 &&
            _touchedIndex! < sortedEntries.length)
          Positioned(
            // 贴在饼图底部内侧，避免 tooltip 溢出卡片区域
            bottom: -10,
            left: 0,
            right: 0,
            child: Center(
              child: _buildPieTooltip(
                appTheme,
                sortedEntries[_touchedIndex!].key,
                sortedEntries[_touchedIndex!].value,
                pctMap[sortedEntries[_touchedIndex!].key]!,
                colorMap[sortedEntries[_touchedIndex!].key] ?? appTheme.earthMedium,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPieTooltip(
    AppThemeExtension appTheme,
    String label,
    double amount,
    double pct,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusSm),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$label ${(pct * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: appTheme.earth,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '¥${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFamily: GoogleFonts.dmSans().fontFamily,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData? _categoryIcon(String category) {
    switch (category) {
      case '生活':
        return Icons.coffee_outlined;
      case '购物':
        return Icons.shopping_bag_outlined;
      case '工作':
        return Icons.business_center_outlined;
      case '娱乐':
        return Icons.sports_esports_outlined;
      case '大餐':
        return Icons.restaurant_outlined;
      case '杂项':
        return Icons.wb_sunny_outlined;
      case '其他':
        return Icons.more_horiz;
      default:
        return Icons.category_outlined;
    }
  }

  // 余额列：水平三列之一，右对齐，金额右侧带编辑图标，整列可点编辑
  Widget _buildBalanceMetric(AppThemeExtension appTheme) {
    return _buildMetric(
      appTheme: appTheme,
      label: '余额',
      align: CrossAxisAlignment.center,
      onTap: widget.onEditBalance,
      labelTrailing: widget.onEditBalance != null
          ? Icon(
              Icons.edit_outlined,
              size: 13,
              color: appTheme.primary.withValues(alpha: 0.6),
            )
          : null,
      value: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isBalanceOverridden)
            Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: Color(0xFFE6A817),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  '!',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (_isBalanceOverridden) const SizedBox(width: 3),
          Text(
            widget.stageCalc.balance != null
                ? '¥${widget.stageCalc.balance!.toStringAsFixed(2)}'
                : '¥0.00',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _amountStyle(
              appTheme,
              color: widget.stageCalc.balance != null
                  ? appTheme.primary
                  : appTheme.earthMedium.withValues(alpha: 0.42),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // 本金展开：初始本金 + 追加金额（含追加明细）
  Widget _buildBaseBreakdown(AppThemeExtension appTheme) {
    final additionsTotal = widget.stageCalc.additionsTotal;
    return Container(
      decoration: BoxDecoration(
        color: appTheme.cardBackground.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
      ),
      child: Column(
        children: [
          _buildBreakdownRow(
            appTheme: appTheme,
            label: '初始本金',
            amountText: '¥${widget.previousBalance.toStringAsFixed(2)}',
            color: appTheme.earth,
          ),
          _buildSoftDivider(appTheme, indent: 12),
          _buildBreakdownRow(
            appTheme: appTheme,
            label: '追加',
            amountText: additionsTotal > 0
                ? '+¥${additionsTotal.toStringAsFixed(2)}'
                : '¥0.00',
            color: additionsTotal > 0
                ? appTheme.sage
                : appTheme.earthMedium.withValues(alpha: 0.42),
          ),
          if (widget.additions.isNotEmpty)
            ...widget.additions.map(
              (a) => _buildBreakdownRow(
                appTheme: appTheme,
                label: a.reason,
                amountText: '¥${a.amount.toStringAsFixed(2)}',
                color: appTheme.sage,
                sub: true,
              ),
            ),
        ],
      ),
    );
  }

  // 展开明细通用行：左标签 + 右金额，sub 为缩进子项
  Widget _buildBreakdownRow({
    required AppThemeExtension appTheme,
    required String label,
    required String amountText,
    required Color color,
    bool sub = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: sub ? 16 : 12, vertical: 7),
      child: Row(
        children: [
          if (sub)
            Text(
              '└ ',
              style: TextStyle(
                fontSize: 12,
                color: appTheme.earthMedium.withValues(alpha: 0.3),
              ),
            ),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: sub ? 12 : 13,
                fontWeight: FontWeight.w600,
                color: sub
                    ? appTheme.earthMedium.withValues(alpha: 0.6)
                    : appTheme.earth,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amountText,
            style:
                _amountStyle(appTheme, color: color, fontSize: sub ? 12 : 13),
          ),
        ],
      ),
    );
  }

  // 未开始阶段：紧凑单行卡片（参考设计图第四阶段）
  Widget _buildFutureCard(AppThemeExtension appTheme) {
    return GestureDetector(
      onTap: widget.onEdit,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
        decoration: BoxDecoration(
          color: appTheme.cardBackground,
          borderRadius: BorderRadius.circular(appTheme.radiusLg),
          boxShadow: appTheme.cardShadow,
          border: Border.all(
            color: appTheme.cardBorder.withValues(alpha: 0.7),
            width: 0.5,
          ),
        ),
        child: _buildHeaderRow(appTheme),
      ),
    );
  }

  // 头部行：序号圆（三态）+ 标题 + 日期 + 状态徽章（单行），右侧箭头进编辑
  Widget _buildHeaderRow(AppThemeExtension appTheme) {
    final start = DateTime.parse(widget.stage.startDate);
    final end = DateTime.parse(widget.stage.endDate);
    final dateText =
        '${start.month}.${start.day.toString().padLeft(2, '0')} ~ ${end.month}.${end.day.toString().padLeft(2, '0')}';
    final badge = _statusBadge(appTheme);
    return Row(
      children: [
        _buildIndexBadge(appTheme),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '第${widget.stage.sortOrder}阶段',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: GoogleFonts.dmSans().fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: appTheme.earth,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  dateText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: appTheme.earthMedium.withValues(alpha: 0.52),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (badge != null) ...[const SizedBox(width: 8), badge],
        if (widget.onEdit != null) ...[
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: appTheme.earthMedium.withValues(alpha: 0.36),
          ),
        ],
      ],
    );
  }

  // 序号圆三态：未开始灰圆 / 进行中蓝实心圆 / 已完成对勾圆
  Widget _buildIndexBadge(AppThemeExtension appTheme) {
    if (_isFutureStage) {
      return _badgeCircle(
        background: appTheme.earthMedium.withValues(alpha: 0.08),
        borderColor: appTheme.earthMedium.withValues(alpha: 0.12),
        child: Text(
          '${widget.stage.sortOrder}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: appTheme.earth,
            fontFamily: GoogleFonts.dmSans().fontFamily,
          ),
        ),
      );
    }
    if (_isCurrentStage) {
      return _badgeCircle(
        background: appTheme.primary,
        child: Text(
          '${widget.stage.sortOrder}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontFamily: GoogleFonts.dmSans().fontFamily,
          ),
        ),
      );
    }
    return _badgeCircle(
      background: appTheme.primary.withValues(alpha: 0.12),
      child: Icon(Icons.check_rounded, size: 15, color: appTheme.primary),
    );
  }

  // 状态徽章：进行中 / 未开始，已完成无徽章
  Widget? _statusBadge(AppThemeExtension appTheme) {
    if (_isFutureStage) {
      return _statusPill(
        appTheme,
        '未开始',
        background: appTheme.earthMedium.withValues(alpha: 0.10),
        foreground: appTheme.earthMedium.withValues(alpha: 0.6),
      );
    }
    if (_isCurrentStage) {
      return _statusPill(
        appTheme,
        '进行中',
        background: appTheme.primary.withValues(alpha: 0.10),
        foreground: appTheme.primary,
      );
    }
    return null;
  }

  Widget _statusPill(
    AppThemeExtension appTheme,
    String text, {
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(appTheme.radiusPill),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: foreground,
        ),
      ),
    );
  }

  Widget _badgeCircle({
    required Color background,
    Color? borderColor,
    required Widget child,
  }) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Theme.of(context).appTheme.radiusPill),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor, width: 0.5),
      ),
      child: Center(child: child),
    );
  }

  Widget _buildCategoryRow({
    required AppThemeExtension appTheme,
    required IconData icon,
    required String label,
    required String amountText,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: appTheme.earthMedium.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(appTheme.radiusPill),
            ),
            child: Icon(
              icon,
              size: 13,
              color: appTheme.earth.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 8),
          // 标签 + 金额紧贴
          ...(subtitle != null
              ? [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: appTheme.earth,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: appTheme.earthMedium.withValues(alpha: 0.48),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    amountText,
                    style: _amountStyle(appTheme, color: appTheme.rose, fontSize: 12),
                  ),
                ]
              : [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: appTheme.earth,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    amountText,
                    style: _amountStyle(appTheme, color: appTheme.rose, fontSize: 12),
                  ),
                ]),
        ],
      ),
    );
  }

  Widget _buildSoftDivider(AppThemeExtension appTheme, {double indent = 52}) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: appTheme.earthMedium.withValues(alpha: 0.10),
      ),
    );
  }

  Widget _buildBalanceRow(AppThemeExtension appTheme) {
    final hasSubtitle = widget.stageCalc.livingTotal != null &&
        widget.stageCalc.livingDailyAvg != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: appTheme.earthMedium.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(appTheme.radiusPill),
            ),
            child: Icon(
              Icons.wb_sunny_outlined,
              size: 13,
              color: appTheme.earth.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '漏记杂项',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: appTheme.earth,
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isBalanceOverridden)
                    Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE6A817),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '!',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  if (_isBalanceOverridden) const SizedBox(width: 3),
                  Text(
                    hasSubtitle
                        ? (_isBalanceOverridden
                            ? '+¥${widget.stageCalc.livingTotal!.abs().toStringAsFixed(2)}'
                            : '-¥${widget.stageCalc.livingTotal!.abs().toStringAsFixed(2)}')
                        : '-¥0.00',
                    style: _amountStyle(
                      appTheme,
                      color: appTheme.rose,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (hasSubtitle)
                Text(
                  '¥${widget.stageCalc.livingDailyAvg!.abs().toStringAsFixed(2)}/天 × ${widget.stage.livingDays}天',
                  style: TextStyle(
                    fontSize: 10,
                    color: appTheme.earthMedium.withValues(alpha: 0.45),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  TextStyle _amountStyle(
    AppThemeExtension appTheme, {
    required Color color,
    double fontSize = 14,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      fontFamily: GoogleFonts.dmSans().fontFamily,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}

