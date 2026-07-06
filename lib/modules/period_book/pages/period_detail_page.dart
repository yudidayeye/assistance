import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/number_keyboard.dart';
import '../models/period_record.dart';
import '../models/addition_record.dart';
import '../models/expense_record.dart';
import '../services/period_book_service.dart';
import '../services/period_book_stats_service.dart';
import '../widgets/period_summary_card.dart';
import '../widgets/expense_list_item.dart';
import '../widgets/addition_list_item.dart';
import '../widgets/expense_pie_chart.dart';
import '../widgets/balance_trend_chart.dart';

/// 当前周期详情页（入口页）
class PeriodDetailPage extends StatefulWidget {
  /// 指定周期 ID 时以只读模式展示（历史周期）
  final int? periodId;

  const PeriodDetailPage({super.key, this.periodId});

  @override
  State<PeriodDetailPage> createState() => _PeriodDetailPageState();
}

class _PeriodDetailPageState extends State<PeriodDetailPage> {
  final _service = PeriodBookService.instance;
  final _statsService = PeriodBookStatsService.instance;

  PeriodRecord? _period;
  PeriodCalculations? _calc;
  List<AdditionRecord> _additions = [];
  List<ExpenseRecord> _expenses = [];
  Map<String, double> _pieData = {};
  List<Map<String, dynamic>> _trendData = [];
  bool _loading = true;

  bool get _isReadOnly => widget.periodId != null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      if (_isReadOnly && widget.periodId != null) {
        _period = await _service.getPeriodById(widget.periodId!);
      } else {
        _period = await _service.getOngoingPeriod();
      }
      if (_period != null) {
        final results = await Future.wait([
          _service.getPeriodCalculations(_period!.id!),
          _service.getAdditionsByPeriod(_period!.id!),
          _service.getExpensesByPeriod(_period!.id!),
          _statsService.getPieChartData(_period!.id!),
          _statsService.getBalanceTrendData(),
        ]);
        _calc = results[0] as PeriodCalculations;
        _additions = results[1] as List<AdditionRecord>;
        _expenses = results[2] as List<ExpenseRecord>;
        _pieData = results[3] as Map<String, double>;
        _trendData = results[4] as List<Map<String, dynamic>>;
      }
    } catch (e) {
      debugPrint('PeriodDetailPage load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  // ═══════════════════════════════════════════════════════════
  // 构建
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    if (_loading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: appTheme.scaffoldGradient),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_period == null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: appTheme.scaffoldGradient),
          child: EmptyStateWidget(
            icon: Icons.account_balance_wallet_outlined,
            title: '还没有记账周期',
            subtitle: '创建第一个周期，开始记录你的收支',
            actionLabel: '新建周期',
            onAction: () => context.push('/period_book/new'),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: appTheme.scaffoldGradient),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildHeader(appTheme),
            SliverToBoxAdapter(child: SizedBox(height: appTheme.spaceLg)),
            SliverToBoxAdapter(child: _buildSummarySection(appTheme)),
            SliverToBoxAdapter(child: SizedBox(height: appTheme.spaceLg)),
            SliverToBoxAdapter(child: _buildAdditionsSection(appTheme)),
            SliverToBoxAdapter(child: SizedBox(height: appTheme.spaceLg)),
            SliverToBoxAdapter(child: _buildExpensesSection(appTheme)),
            SliverToBoxAdapter(child: SizedBox(height: appTheme.spaceLg)),
            SliverToBoxAdapter(child: ExpensePieChart(data: _pieData)),
            SliverToBoxAdapter(child: SizedBox(height: appTheme.spaceLg)),
            SliverToBoxAdapter(child: BalanceTrendChart(data: _trendData)),
            SliverToBoxAdapter(child: const SizedBox(height: 80)),
          ],
        ),
      ),
      floatingActionButton: _isReadOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddExpenseDialog,
              backgroundColor: appTheme.primary,
              icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
              label: const Text('记一笔',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 头部
  // ═══════════════════════════════════════════════════════════

  Widget _buildHeader(AppThemeExtension appTheme) {
    final safeTop = MediaQuery.of(context).padding.top;
    final start = DateTime.parse(_period!.startDate);
    final end = DateTime.parse(_period!.endDate);
    final title = '${start.month}月${start.day}日 ~ ${end.month}月${end.day}日';

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, safeTop + 16, 24, 24),
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
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    color: appTheme.earthMedium, size: 18),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: GoogleFonts.dmSans().fontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: appTheme.earth,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '共${_period!.totalDays}天',
                    style: TextStyle(
                      fontSize: 12,
                      color: appTheme.earthMedium.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (!_isReadOnly) ...[
              // 历史记录按钮
              GestureDetector(
                onTap: () => context.push('/period_book/history'),
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: appTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(appTheme.radiusMd),
                  ),
                  child: Icon(Icons.history_rounded,
                      color: appTheme.primary, size: 20),
                ),
              ),
              // 编辑按钮
              GestureDetector(
                onTap: _showEditPeriodDialog,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: appTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(appTheme.radiusMd),
                  ),
                  child: Icon(Icons.more_vert_rounded,
                      color: appTheme.earthMedium, size: 20),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 汇总卡片
  // ══════════════════════════════════════════════════════════

  Widget _buildSummarySection(AppThemeExtension appTheme) {
    return PeriodSummaryCard(
      calc: _calc!,
      onEditBalance: _isReadOnly ? null : _showEditBalanceDialog,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 追加记录区域
  // ═══════════════════════════════════════════════════════════

  Widget _buildAdditionsSection(AppThemeExtension appTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          appTheme: appTheme,
          title: '追加记录',
          subtitle: '${_additions.length} 笔',
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: appTheme.cardBackground,
            borderRadius: BorderRadius.circular(20),
            boxShadow: appTheme.cardShadow,
            border: Border.all(color: appTheme.cardBorder, width: 0.5),
          ),
          child: Column(
            children: [
              if (_additions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    '暂无追加记录',
                    style: TextStyle(
                      fontSize: 13,
                      color: appTheme.earthMedium.withValues(alpha: 0.5),
                    ),
                  ),
                )
              else
                ..._additions.map((a) => AdditionListItem(
                      addition: a,
                      onDelete: () => _deleteAddition(a),
                      isReadOnly: _isReadOnly,
                    )),
              if (!_isReadOnly) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _showAddAdditionDialog,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline_rounded,
                            size: 18, color: appTheme.sage),
                        const SizedBox(width: 6),
                        Text(
                          '追加本金',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: appTheme.sage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 支出明细区域（分组）
  // ══════════════════════════════════════════════════════════

  Widget _buildExpensesSection(AppThemeExtension appTheme) {
    final shopping = _expenses.where((e) => e.category == 'shopping').toList();
    final other = _expenses.where((e) => e.category == 'other').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          appTheme: appTheme,
          title: '支出明细',
          subtitle: '${_expenses.length} 笔',
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: appTheme.cardBackground,
            borderRadius: BorderRadius.circular(20),
            boxShadow: appTheme.cardShadow,
            border: Border.all(color: appTheme.cardBorder, width: 0.5),
          ),
          child: Column(
            children: [
              _buildExpenseGroup(
                appTheme: appTheme,
                label: '购物',
                icon: Icons.shopping_bag_outlined,
                iconColor: appTheme.sage,
                items: shopping,
              ),
              _buildExpenseGroup(
                appTheme: appTheme,
                label: '其他',
                icon: Icons.category_outlined,
                iconColor: appTheme.roseLight,
                items: other,
              ),
              if (shopping.isEmpty && other.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    '暂无支出记录',
                    style: TextStyle(
                      fontSize: 13,
                      color: appTheme.earthMedium.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              if (!_isReadOnly) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _showAddExpenseDialog,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_note_rounded,
                            size: 18, color: appTheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          '记一笔',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: appTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: appTheme.earthMedium,
                ),
              ),
              const Spacer(),
              Text(
                '${items.length} 笔',
                style: TextStyle(
                  fontSize: 12,
                  color: appTheme.earthMedium.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Text(
                '暂无',
                style: TextStyle(
                  fontSize: 12,
                  color: appTheme.earthMedium.withValues(alpha: 0.35),
                ),
              ),
            ),
          )
        else
          ...items.map((e) => ExpenseListItem(
                expense: e,
                onDelete: () => _deleteExpense(e),
                isReadOnly: _isReadOnly,
              )),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 操作：删除
  // ═══════════════════════════════════════════════════════════

  Future<void> _deleteExpense(ExpenseRecord e) async {
    await _service.deleteExpense(e.id!);
    await _loadData();
  }

  Future<void> _deleteAddition(AdditionRecord a) async {
    await _service.deleteAddition(a.id!);
    await _loadData();
  }

  // ═══════════════════════════════════════════════════════════
  // 弹窗：编辑余额
  // ═══════════════════════════════════════════════════════════

  void _showEditBalanceDialog() {
    final appTheme = Theme.of(context).appTheme;
    final controller = TextEditingController(
      text: _period!.balance?.toStringAsFixed(2) ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: appTheme.cream,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(appTheme.radiusXl),
            topRight: Radius.circular(appTheme.radiusXl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 12),
              child: Text(
                '编辑余额',
                style: TextStyle(
                  fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: appTheme.earth,
                ),
              ),
            ),
            // 输入显示
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: appTheme.creamDark,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Text(
                      '¥',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: appTheme.earthMedium.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        readOnly: true,
                        style: TextStyle(
                          fontFamily: GoogleFonts.dmSans().fontFamily,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: appTheme.earth,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (controller.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          controller.clear();
                        },
                        child: Icon(Icons.clear_rounded,
                            color: appTheme.earthMedium.withValues(alpha: 0.4),
                            size: 22),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 数字键盘
            NumberKeyboard(
              currentValue: controller.text,
              onValueChanged: (v) {
                controller.text = v;
                controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: v.length),
                );
              },
              onDone: () async {
                final val = double.tryParse(controller.text);
                if (val != null) {
                  await _service.updatePeriod(
                    _period!.id!,
                    {'balance': val},
                  );
                  await _loadData();
                }
                Navigator.pop(ctx);
              },
              doneColor: appTheme.primary,
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 弹窗：追加本金
  // ═══════════════════════════════════════════════════════════

  void _showAddAdditionDialog() {
    final appTheme = Theme.of(context).appTheme;
    final reasonController = TextEditingController();
    String amount = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: BoxDecoration(
              color: appTheme.cream,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(appTheme.radiusXl),
                topRight: Radius.circular(appTheme.radiusXl),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 16),
                  child: Text(
                    '追加本金',
                    style: TextStyle(
                      fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: appTheme.earth,
                    ),
                  ),
                ),
                // 原因输入
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: reasonController,
                    style: TextStyle(
                      fontSize: 15,
                      color: appTheme.earth,
                    ),
                    decoration: InputDecoration(
                      hintText: '追加原因（必填）',
                      hintStyle: TextStyle(
                        color: appTheme.earthMedium.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: appTheme.creamDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    maxLength: 50,
                  ),
                ),
                const SizedBox(height: 12),
                // 金额显示
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: appTheme.creamDark,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '¥',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: appTheme.earthMedium.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            amount.isEmpty ? '0' : amount,
                            style: TextStyle(
                              fontFamily: GoogleFonts.dmSans().fontFamily,
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: appTheme.earth,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                NumberKeyboard(
                  currentValue: amount,
                  onValueChanged: (v) {
                    setSheetState(() => amount = v);
                  },
                  onDone: () async {
                    final val = double.tryParse(amount);
                    final reason = reasonController.text.trim();
                    if (val == null || val <= 0 || reason.isEmpty) return;
                    await _service.addAddition(
                      _period!.id!,
                      val,
                      reason,
                    );
                    await _loadData();
                    Navigator.pop(ctx);
                  },
                  doneColor: appTheme.sage,
                ),
                SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 弹窗：记一笔
  // ═══════════════════════════════════════════════════════════

  void _showAddExpenseDialog() {
    final appTheme = Theme.of(context).appTheme;
    final descController = TextEditingController();
    String amount = '';
    String category = 'shopping';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: BoxDecoration(
              color: appTheme.cream,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(appTheme.radiusXl),
                topRight: Radius.circular(appTheme.radiusXl),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 16),
                  child: Text(
                    '记一笔',
                    style: TextStyle(
                      fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: appTheme.earth,
                    ),
                  ),
                ),
                // 分类切换
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      _buildCategoryChip(
                        appTheme: appTheme,
                        label: '购物',
                        isSelected: category == 'shopping',
                        color: appTheme.sage,
                        onTap: () =>
                            setSheetState(() => category = 'shopping'),
                      ),
                      const SizedBox(width: 12),
                      _buildCategoryChip(
                        appTheme: appTheme,
                        label: '其他',
                        isSelected: category == 'other',
                        color: appTheme.roseLight,
                        onTap: () => setSheetState(() => category = 'other'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 描述输入
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: descController,
                    style: TextStyle(
                      fontSize: 15,
                      color: appTheme.earth,
                    ),
                    decoration: InputDecoration(
                      hintText: '描述（如：盒马会员）',
                      hintStyle: TextStyle(
                        color: appTheme.earthMedium.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: appTheme.creamDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    maxLength: 50,
                  ),
                ),
                const SizedBox(height: 12),
                // 金额显示
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: appTheme.creamDark,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '¥',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: appTheme.earthMedium.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            amount.isEmpty ? '0' : amount,
                            style: TextStyle(
                              fontFamily: GoogleFonts.dmSans().fontFamily,
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: appTheme.earth,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                NumberKeyboard(
                  currentValue: amount,
                  onValueChanged: (v) {
                    setSheetState(() => amount = v);
                  },
                  onDone: () async {
                    final val = double.tryParse(amount);
                    final desc = descController.text.trim();
                    if (val == null || val <= 0 || desc.isEmpty) return;
                    await _service.addExpense(
                      _period!.id!,
                      category,
                      val,
                      desc,
                    );
                    await _loadData();
                    Navigator.pop(ctx);
                  },
                  doneColor: appTheme.primary,
                ),
                SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryChip({
    required AppThemeExtension appTheme,
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : appTheme.creamDark,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: color.withValues(alpha: 0.3), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Icon(Icons.check_rounded, size: 16, color: color),
            if (isSelected) const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : appTheme.earthMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 弹窗：编辑周期（结束日期 / 进行中日期）
  // ═══════════════════════════════════════════════════════════

  void _showEditPeriodDialog() {
    final appTheme = Theme.of(context).appTheme;
    showDialog(
      context: context,
      barrierColor: appTheme.surfaceOverlay,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: appTheme.cream,
            borderRadius: BorderRadius.circular(appTheme.radiusMd),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '编辑周期',
                style: TextStyle(
                  fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: appTheme.earth,
                ),
              ),
              const SizedBox(height: 20),
              _buildEditRow(
                appTheme: appTheme,
                label: '修改结束日期',
                icon: Icons.calendar_today_outlined,
                onTap: () async {
                  Navigator.pop(ctx);
                  final newDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.parse(_period!.endDate),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (newDate != null && mounted) {
                    final dateStr = '${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}';
                    await _service.updatePeriod(
                      _period!.id!,
                      {'end_date': dateStr},
                    );
                    await _loadData();
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildEditRow(
                appTheme: appTheme,
                label: _period!.inProgressDate != null
                    ? '清除进行中日期'
                    : '设置进行中日期',
                icon: Icons.today_outlined,
                isDestructive: _period!.inProgressDate != null,
                onTap: () async {
                  Navigator.pop(ctx);
                  if (_period!.inProgressDate != null) {
                    // 清除
                    await _service.updatePeriod(
                      _period!.id!,
                      {'in_progress_date': null},
                    );
                  } else {
                    final newDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.parse(_period!.startDate),
                      lastDate: DateTime.parse(_period!.endDate),
                    );
                    if (newDate != null && mounted) {
                      final dateStr = '${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}';
                      await _service.updatePeriod(
                        _period!.id!,
                        {'in_progress_date': dateStr},
                      );
                    }
                  }
                  await _loadData();
                },
              ),
              const SizedBox(height: 12),
              _buildEditRow(
                appTheme: appTheme,
                label: '标记为已结束',
                icon: Icons.lock_outline_rounded,
                isDestructive: true,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _service.closePeriod(_period!.id!);
                  await _loadData();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditRow({
    required AppThemeExtension appTheme,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? appTheme.rose : appTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDestructive ? appTheme.rose : appTheme.earth,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: appTheme.earthMedium.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Section 标题
// ═══════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final AppThemeExtension appTheme;
  final String title;
  final String? subtitle;

  const _SectionTitle({
    required this.appTheme,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: appTheme.primary,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontFamily: GoogleFonts.dmSans().fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: appTheme.earthMedium,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
