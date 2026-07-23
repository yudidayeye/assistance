import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/utils/format_utils.dart';
import '../models/stage_record.dart';
import '../models/expense_record.dart';
import '../services/period_book_service.dart';

/// 阶段卡片 — 严格按设计稿配色
class StageCard extends StatefulWidget {
  final StageRecord stage;
  final StageCalculations stageCalc;
  final PeriodBookService service;
  final VoidCallback? onTap;

  const StageCard({
    super.key,
    required this.stage,
    required this.stageCalc,
    required this.service,
    this.onTap,
  });

  @override
  State<StageCard> createState() => _StageCardState();
}

class _StageCardState extends State<StageCard> {
  bool _expanded = false;
  bool _loadingExpenses = false;
  List<ExpenseRecord> _expenses = [];
  bool _expensesLoaded = false;

  late final DateTime _today = DateTime.now();
  late final DateTime _start = DateTime.parse(widget.stage.startDate);
  late final DateTime _end = DateTime.parse(widget.stage.endDate);
  late final bool _isCurrent =
      _today.isAfter(_start.subtract(const Duration(days: 1))) &&
          _today.isBefore(_end.add(const Duration(days: 1)));
  late final bool _isCompleted = _today.isAfter(_end);

  // 设计稿颜色
  static const Color _blue = Color(0xFF5B8FF9);
  static const Color _darkText = Color(0xFF333333);
  static const Color _subText = Color(0xFF999999);

  Future<void> _toggleExpand() async {
    if (!_isCompleted) return;
    if (!_expensesLoaded && !_loadingExpenses) {
      setState(() => _loadingExpenses = true);
      try {
        final expenses =
            await widget.service.getExpensesByStage(widget.stage.id!);
        if (mounted) {
          _expenses = expenses;
          _expensesLoaded = true;
          _loadingExpenses = false;
        }
      } catch (_) {
        if (mounted) _loadingExpenses = false;
      }
    }
    if (mounted) setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final isExpandable = _isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A000000),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _isCurrent ? _blue : const Color(0xFFE8E8E8),
          width: _isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // 头部
          GestureDetector(
            onTap: isExpandable ? _toggleExpand : widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  _buildStatusIndicator(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              '第${widget.stage.sortOrder}阶段',
                              style: TextStyle(
                                fontFamily: GoogleFonts.dmSans().fontFamily,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _darkText,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_fmtDate(_start)}-${_fmtDate(_end)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: _subText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_isCurrent) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '进行中',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (isExpandable)
                    RotationTransition(
                      turns: AlwaysStoppedAnimation(_expanded ? 0.5 : 0),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: const Color(0xFFCCCCCC),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 三列汇总
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryColumn(
                    label: '本金',
                    value: widget.stageCalc.baseAmount,
                    color: _blue,
                  ),
                ),
                Container(
                  width: 0.5,
                  height: 28,
                  color: const Color(0xFFEEEEEE),
                ),
                Expanded(
                  child: _buildSummaryColumn(
                    label: '支出',
                    value: -(widget.stageCalc.shoppingTotal +
                        widget.stageCalc.otherTotal),
                    color: _blue,
                    isNegative: true,
                  ),
                ),
                Container(
                  width: 0.5,
                  height: 28,
                  color: const Color(0xFFEEEEEE),
                ),
                Expanded(
                  child: _buildSummaryColumn(
                    label: '余额',
                    value: widget.stageCalc.balance ?? 0,
                    color: _blue,
                  ),
                ),
              ],
            ),
          ),
          if (_expanded && _isCompleted)
            _buildExpenseDetailSection(),
        ],
      ),
    );
  }

  /// 左侧状态指示器
  Widget _buildStatusIndicator() {
    if (_isCurrent) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: _blue,
          shape: BoxShape.circle,
        ),
      );
    } else if (_isCompleted) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: _blue.withValues(alpha: 0.10),
          shape: BoxShape.circle,
          border: Border.all(
            color: _blue.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.check_rounded,
          size: 14,
          color: _blue,
        ),
      );
    } else {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFDDDDDD),
            width: 1.5,
          ),
        ),
      );
    }
  }

  /// 三列汇总单元格
  Widget _buildSummaryColumn({
    required String label,
    required double value,
    required Color color,
    bool isNegative = false,
  }) {
    final absValue = value.abs();
    final prefix = isNegative ? '-' : '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: _subText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$prefix${FormatUtils.formatAmount(absValue)}',
          style: TextStyle(
            fontFamily: GoogleFonts.dmSans().fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  /// 展开的支出明细区域 — 按设计稿格式：状态点 + 日期 + 分类 + 金额
  Widget _buildExpenseDetailSection() {

    return Column(
      children: [
        Divider(
          height: 1,
          color: const Color(0xFFEEEEEE),
        ),
        if (_loadingExpenses)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _blue,
                ),
              ),
            ),
          )
        else if (_expenses.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                '暂无支出明细',
                style: TextStyle(
                  fontSize: 13,
                  color: const Color(0xFFBBBBBB),
                ),
              ),
            ),
          )
        else
          ..._expenses.asMap().entries.map((entry) {
            final idx = entry.key;
            final e = entry.value;
            final expenseDate = _start.add(Duration(days: idx));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // 蓝色状态指示点
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  // 日期 + 分类
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          '${expenseDate.month}.${expenseDate.day.toString().padLeft(2, "0")}',
                          style: TextStyle(
                            fontSize: 13,
                            color: _darkText,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _expenseCategoryLabel(e.category),
                          style: TextStyle(
                            fontSize: 13,
                            color: _darkText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 金额
                  Text(
                    '-${FormatUtils.formatAmount(e.amount)}',
                    style: TextStyle(
                      fontFamily: GoogleFonts.dmSans().fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _blue,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            );
          }),
        // 分隔线 + 查看全部支出
        Divider(
          height: 1,
          color: const Color(0xFFEEEEEE),
        ),
        // 查看全部支出 — 行样式带右箭头
        GestureDetector(
          onTap: () {
            // 跳转到支出明细页或展开更多
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '查看全部支出',
                  style: TextStyle(
                    fontSize: 13,
                    color: _blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: _blue,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _expenseCategoryLabel(String category) {
    switch (category) {
      case 'shopping':
        return '购物';
      case 'other':
        return '其他';
      case 'living':
        return '生活';
      default:
        return category;
    }
  }

  String _fmtDate(DateTime dt) {
    return '${dt.month}.${dt.day.toString().padLeft(2, '0')}';
  }
}
