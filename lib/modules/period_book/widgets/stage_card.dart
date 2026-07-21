import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extension.dart';
import '../models/stage_record.dart';
import '../models/addition_record.dart';
import '../models/expense_record.dart';
import '../services/period_book_service.dart';

/// 阶段卡片组件
class StageCard extends StatefulWidget {
  final StageRecord stage;
  final StageCalculations stageCalc;
  final double previousBalance;
  final List<AdditionRecord> additions;
  final List<ExpenseRecord> expenses;
  final bool isReadOnly;
  final VoidCallback? onEditBalance;
  final VoidCallback? onEdit;
  final void Function(AdditionRecord)? onDeleteAddition;
  final void Function(ExpenseRecord)? onDeleteExpense;
  final void Function(List<ExpenseRecord>)? onReorderExpenses;

  const StageCard({
    super.key,
    required this.stage,
    required this.stageCalc,
    required this.previousBalance,
    required this.additions,
    required this.expenses,
    required this.isReadOnly,
    this.onEditBalance,
    this.onEdit,
    this.onDeleteAddition,
    this.onDeleteExpense,
    this.onReorderExpenses,
  });

  @override
  State<StageCard> createState() => _StageCardState();
}

class _StageCardState extends State<StageCard> with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    final stage = widget.stage;
    final calc = widget.stageCalc;
    final start = DateTime.parse(stage.startDate);
    final end = DateTime.parse(stage.endDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: appTheme.cardShadow,
        border: Border.all(color: appTheme.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：纯展示（不再有点击展开）
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              children: [
                // 阶段序号
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        appTheme.primary.withValues(alpha: 0.15),
                        appTheme.primary.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${stage.sortOrder}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: appTheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 阶段标题 + 时间 + 编辑图标
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '第${stage.sortOrder}阶段',
                            style: TextStyle(
                              fontFamily: GoogleFonts.dmSans().fontFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: appTheme.earth,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${start.month}.${start.day.toString().padLeft(2, '0')} ~ ${end.month}.${end.day.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 12,
                              color: appTheme.earthMedium.withValues(alpha: 0.6),
                            ),
                          ),
                          const Spacer(),
                          if (widget.onEdit != null) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: widget.onEdit,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: appTheme.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: appTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 简要信息
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              children: [
                _buildInfoRow(
                  appTheme: appTheme,
                  label: '本金',
                  value: '¥${calc.baseAmount.toStringAsFixed(2)}',
                  valueColor: appTheme.earth,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  appTheme: appTheme,
                  label: '购物',
                  value: calc.shoppingTotal > 0
                      ? '-¥${calc.shoppingTotal.toStringAsFixed(2)}'
                      : '¥0.00',
                  valueColor: calc.shoppingTotal > 0 ? appTheme.rose : appTheme.earthMedium.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  appTheme: appTheme,
                  label: '其他',
                  value: calc.otherTotal > 0
                      ? '-¥${calc.otherTotal.toStringAsFixed(2)}'
                      : '¥0.00',
                  valueColor: calc.otherTotal > 0 ? appTheme.rose : appTheme.earthMedium.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  appTheme: appTheme,
                  label: '余额',
                  labelTrailing: widget.onEditBalance != null
                      ? GestureDetector(
                          onTap: widget.onEditBalance,
                          child: Icon(
                            Icons.create_outlined,
                            size: 14,
                            color: appTheme.primary.withValues(alpha: 0.6),
                          ),
                        )
                      : null,
                  value: calc.balance != null
                      ? '¥${calc.balance!.toStringAsFixed(2)}'
                      : '¥0.00',
                  valueColor: calc.balance != null ? appTheme.earth : appTheme.earthMedium.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  appTheme: appTheme,
                  label: '生活',
                  value: calc.livingTotal != null
                      ? '-¥${calc.livingTotal!.abs().toStringAsFixed(2)} / ${stage.livingDays}天 = -¥${calc.livingDailyAvg!.abs().toStringAsFixed(2)}/天'
                      : '¥0.00',
                  valueColor: calc.livingTotal != null ? appTheme.rose : appTheme.earthMedium.withValues(alpha: 0.4),
                  valueFontSize: 12,
                ),
                if (widget.additions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    appTheme: appTheme,
                    label: '追加',
                    value: '+¥${calc.additionsTotal.toStringAsFixed(2)}',
                    valueColor: appTheme.sage,
                  ),
                ],
              ],
            ),
          ),
          // 底部展开/收起按钮
          _buildExpandButton(appTheme),
          // 展开的详细内容
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: _buildExpandedContent(appTheme),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required AppThemeExtension appTheme,
    required String label,
    required String value,
    required Color valueColor,
    double valueFontSize = 14,
    Widget? labelTrailing,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: appTheme.earthMedium.withValues(alpha: 0.7),
          ),
        ),
        if (labelTrailing != null) ...[
          const SizedBox(width: 6),
          labelTrailing,
        ],
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: valueFontSize,
            fontWeight: FontWeight.w600,
            color: valueColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing,
        ],
      ],
    );
  }

  Widget _buildExpandButton(AppThemeExtension appTheme) {
    return GestureDetector(
      onTap: _toggleExpand,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: appTheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 18,
              color: appTheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              _expanded ? '收起明细' : '展开明细',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: appTheme.primary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent(AppThemeExtension appTheme) {
    // 只读展示，不可排序不可删除
    final expenses = widget.expenses;

    return Container(
      decoration: BoxDecoration(
        color: appTheme.creamDark.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              '支出明细',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: appTheme.earthMedium,
              ),
            ),
          ),
          if (expenses.isNotEmpty)
            ...expenses.map((expense) => _buildExpenseItem(appTheme, expense)),
          if (widget.additions.isNotEmpty) ...[
            _buildAdditionList(appTheme),
          ],
          if (expenses.isEmpty && widget.additions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  '暂无明细',
                  style: TextStyle(
                    fontSize: 13,
                    color: appTheme.earthMedium.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildExpenseItem(AppThemeExtension appTheme, ExpenseRecord expense) {
    final icon = expense.category == 'shopping'
        ? Icons.shopping_bag_outlined
        : Icons.category_outlined;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: appTheme.rose.withValues(alpha: 0.75)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              expense.description,
              style: TextStyle(
                fontSize: 13,
                color: appTheme.earth,
              ),
            ),
          ),
          Text(
            '-¥${expense.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: appTheme.rose,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionList(AppThemeExtension appTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            children: [
              Icon(Icons.add_circle_outline, size: 14, color: appTheme.sage),
              const SizedBox(width: 4),
              Text(
                '追加 (${widget.additions.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: appTheme.earthMedium,
                ),
              ),
            ],
          ),
        ),
        ...widget.additions.map((a) => _buildAdditionItem(appTheme, a)),
      ],
    );
  }

  Widget _buildAdditionItem(AppThemeExtension appTheme, AdditionRecord addition) {
    return Dismissible(
      key: Key('addition_${addition.id}'),
      direction: widget.isReadOnly ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: appTheme.rose.withValues(alpha: 0.1),
        child: Icon(Icons.delete_outline, color: appTheme.rose, size: 18),
      ),
      onDismissed: (_) => widget.onDeleteAddition?.call(addition),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                addition.reason,
                style: TextStyle(
                  fontSize: 13,
                  color: appTheme.earth,
                ),
              ),
            ),
            Text(
              '+¥${addition.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: appTheme.sage,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
