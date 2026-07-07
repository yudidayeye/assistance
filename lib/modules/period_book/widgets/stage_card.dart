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
  final VoidCallback? onAddAddition;
  final VoidCallback? onEdit;
  final void Function(AdditionRecord)? onDeleteAddition;
  final void Function(ExpenseRecord)? onDeleteExpense;

  const StageCard({
    super.key,
    required this.stage,
    required this.stageCalc,
    required this.previousBalance,
    required this.additions,
    required this.expenses,
    required this.isReadOnly,
    this.onEditBalance,
    this.onAddAddition,
    this.onEdit,
    this.onDeleteAddition,
    this.onDeleteExpense,
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
          // 头部：可展开/收起
          GestureDetector(
            onTap: _toggleExpand,
            child: Padding(
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
                  // 日期范围
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        Text(
                          '${start.month}.${start.day.toString().padLeft(2, '0')} ~ ${end.month}.${end.day.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: appTheme.earthMedium.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 展开/收起图标
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: appTheme.earthMedium.withValues(alpha: 0.4),
                      size: 24,
                    ),
                  ),
                  // 编辑图标
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
                      : '—',
                  valueColor: calc.shoppingTotal > 0 ? appTheme.sage : appTheme.earthMedium.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  appTheme: appTheme,
                  label: '其他',
                  value: calc.otherTotal > 0
                      ? '-¥${calc.otherTotal.toStringAsFixed(2)}'
                      : '—',
                  valueColor: calc.otherTotal > 0 ? appTheme.roseLight : appTheme.earthMedium.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  appTheme: appTheme,
                  label: '余额',
                  value: calc.balance != null
                      ? '¥${calc.balance!.toStringAsFixed(2)}'
                      : '—',
                  valueColor: calc.balance != null ? appTheme.primary : appTheme.earthMedium.withValues(alpha: 0.4),
                  trailing: widget.onEditBalance != null
                      ? GestureDetector(
                          onTap: widget.onEditBalance,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: appTheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: appTheme.primary,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  appTheme: appTheme,
                  label: '生活',
                  value: calc.livingTotal != null
                      ? '-¥${calc.livingTotal!.abs().toStringAsFixed(2)} / ${stage.totalDays}天 = -¥${calc.livingDailyAvg!.abs().toStringAsFixed(2)}/天'
                      : '—',
                  valueColor: calc.livingTotal != null ? appTheme.earthMedium : appTheme.earthMedium.withValues(alpha: 0.4),
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
          // 展开的详细内容
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: _buildExpandedContent(appTheme),
          ),
          // 底部操作按钮
          if (!widget.isReadOnly) _buildBottomActions(appTheme),
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
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: valueFontSize,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing,
        ],
      ],
    );
  }

  Widget _buildExpandedContent(AppThemeExtension appTheme) {
    final shopping = widget.expenses.where((e) => e.category == 'shopping').toList();
    final other = widget.expenses.where((e) => e.category == 'other').toList();

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
              '明细',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: appTheme.earthMedium,
              ),
            ),
          ),
          // 购物明细
          if (shopping.isNotEmpty) ...[
            _buildExpenseGroup(
              appTheme: appTheme,
              label: '购物',
              icon: Icons.shopping_bag_outlined,
              iconColor: appTheme.sage,
              items: shopping,
            ),
          ],
          // 其他明细
          if (other.isNotEmpty) ...[
            _buildExpenseGroup(
              appTheme: appTheme,
              label: '其他',
              icon: Icons.category_outlined,
              iconColor: appTheme.roseLight,
              items: other,
            ),
          ],
          // 追加明细
          if (widget.additions.isNotEmpty) ...[
            _buildAdditionList(appTheme),
          ],
          if (shopping.isEmpty && other.isEmpty && widget.additions.isEmpty)
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

  Widget _buildExpenseGroup({
    required AppThemeExtension appTheme,
    required String label,
    required IconData icon,
    required Color iconColor,
    required List<ExpenseRecord> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Text(
                '$label (${items.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: appTheme.earthMedium,
                ),
              ),
            ],
          ),
        ),
        ...items.map((e) => _buildExpenseItem(appTheme, e)),
      ],
    );
  }

  Widget _buildExpenseItem(AppThemeExtension appTheme, ExpenseRecord expense) {
    return Dismissible(
      key: Key('expense_${expense.id}'),
      direction: widget.isReadOnly ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: appTheme.rose.withValues(alpha: 0.1),
        child: Icon(Icons.delete_outline, color: appTheme.rose, size: 18),
      ),
      onDismissed: (_) => widget.onDeleteExpense?.call(expense),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
        child: Row(
          children: [
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
                color: appTheme.earthMedium,
              ),
            ),
          ],
        ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(AppThemeExtension appTheme) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: appTheme.cardBorder,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              appTheme: appTheme,
              icon: Icons.add_circle_outline,
              label: '追加',
              color: appTheme.sage,
              onTap: widget.onAddAddition,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required AppThemeExtension appTheme,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
