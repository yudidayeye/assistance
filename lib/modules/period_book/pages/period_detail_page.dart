import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/number_keyboard.dart';
import '../models/period_record.dart';
import '../models/stage_record.dart';
import '../models/addition_record.dart';
import '../models/expense_record.dart';
import '../services/period_book_service.dart';
import '../widgets/stage_card.dart';
import '../widgets/period_summary_card.dart';

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

  PeriodRecord? _period;
  PeriodCalculations? _calc;
  List<StageRecord> _stages = [];
  List<List<AdditionRecord>> _stageAdditions = [];
  List<List<ExpenseRecord>> _stageExpenses = [];
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
        // 一次性获取所有数据（性能优化）
        _calc = await _service.getPeriodCalculations(_period!.id!);
        _stages = await _service.getStagesByPeriod(_period!.id!);
        final allAdditions = await _service.getAdditionsByPeriod(_period!.id!);
        final allExpenses = await _service.getExpensesByPeriod(_period!.id!);

        // 按阶段分组追加和支出记录
        _stageAdditions = _stages.map((stage) {
          return allAdditions.where((a) => a.stageId == stage.id!).toList();
        }).toList();

        _stageExpenses = _stages.map((stage) {
          return allExpenses.where((e) => e.stageId == stage.id!).toList();
        }).toList();
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
          child: Column(
            children: [
              // 返回导航
              _buildEmptyHeader(appTheme),
              // 空状态内容
              Expanded(
                child: EmptyStateWidget(
                  icon: Icons.account_balance_wallet_outlined,
                  title: '还没有记账周期',
                  subtitle: '创建第一个周期，开始记录你的收支',
                  actionLabel: '新建周期',
                  onAction: () async {
                    await context.push('/period_book/new');
                    // 从新建页返回后刷新数据
                    if (mounted) {
                      _loadData();
                    }
                  },
                ),
              ),
            ],
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
            _buildStagesSection(appTheme),
            SliverToBoxAdapter(child: const SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: _isReadOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await context.push('/period_book/batch_expense/${_period!.id}');
                // 从批量记账页返回后刷新数据
                if (mounted) {
                  _loadData();
                }
              },
              backgroundColor: appTheme.primary,
              heroTag: 'batch_expense',
              icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
              label: const Text('批量记账',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 空状态头部（返回导航）
  // ═══════════════════════════════════════════════════════════

  Widget _buildEmptyHeader(AppThemeExtension appTheme) {
    final safeTop = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, safeTop + 16, 24, 0),
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
        ],
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
                    '共${_period!.totalDays}天 · ${_stages.length}个阶段',
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
                onTap: () => context.push('/period_book/edit/${_period!.id}'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: appTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(appTheme.radiusMd),
                  ),
                  child: Icon(Icons.edit_outlined,
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
      period: _period!,
      onTapTotalBase: _showTotalBaseDetail,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 总本金详情浮层
  // ═══════════════════════════════════════════════════════════

  void _showTotalBaseDetail() {
    final appTheme = Theme.of(context).appTheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
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
              padding: const EdgeInsets.only(top: 20, bottom: 16),
              child: Text(
                '总本金构成',
                style: TextStyle(
                  fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: appTheme.earth,
                ),
              ),
            ),
            // 内容
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  // 初始本金
                  _buildDetailRow(
                    appTheme: appTheme,
                    label: '初始本金',
                    amount: _period!.baseAmount,
                    isTotal: false,
                  ),
                  const Divider(height: 24),
                  // 各阶段追加
                  ..._stages.asMap().entries.map((entry) {
                    final index = entry.key;
                    final stage = entry.value;
                    final additions = _stageAdditions[index];
                    final total = additions.fold<double>(0, (sum, a) => sum + a.amount);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow(
                          appTheme: appTheme,
                          label: '第${stage.sortOrder}周追加',
                          amount: total,
                          isTotal: false,
                          isEmpty: additions.isEmpty,
                        ),
                        if (additions.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          ...additions.map((a) => Padding(
                                padding: const EdgeInsets.only(left: 16, bottom: 4),
                                child: Row(
                                  children: [
                                    Text(
                                      '└',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: appTheme.earthMedium.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        a.reason,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: appTheme.earthMedium.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '¥${a.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: appTheme.sage,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ],
                    );
                  }),
                  const Divider(height: 24),
                  // 合计
                  _buildDetailRow(
                    appTheme: appTheme,
                    label: '合计',
                    amount: _calc!.totalBase,
                    isTotal: true,
                  ),
                  SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required AppThemeExtension appTheme,
    required String label,
    required double amount,
    required bool isTotal,
    bool isEmpty = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 15 : 14,
                fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
                color: isTotal ? appTheme.earth : appTheme.earthMedium,
              ),
            ),
          ),
          if (isEmpty)
            Text(
              '—',
              style: TextStyle(
                fontSize: 14,
                color: appTheme.earthMedium.withValues(alpha: 0.4),
              ),
            )
          else
            Text(
              '¥${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: isTotal ? 16 : 14,
                fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
                color: isTotal ? appTheme.primary : appTheme.earth,
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 阶段列表
  // ═══════════════════════════════════════════════════════════

  Widget _buildStagesSection(AppThemeExtension appTheme) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final stage = _stages[index];
            final stageCalc = _calc!.stages[index];
            final additions = _stageAdditions[index];
            final expenses = _stageExpenses[index];

            // 计算上一阶段余额（用于显示本金来源）
            double previousBalance;
            if (index == 0) {
              previousBalance = _period!.baseAmount;
            } else {
              previousBalance = _calc!.stages[index - 1].balance ??
                  (_calc!.stages[index - 1].baseAmount -
                      _calc!.stages[index - 1].shoppingTotal -
                      _calc!.stages[index - 1].otherTotal);
            }

            return StageCard(
              stage: stage,
              stageCalc: stageCalc,
              previousBalance: previousBalance,
              additions: additions,
              expenses: expenses,
              isReadOnly: _isReadOnly,
              onEditBalance: _isReadOnly ? null : () => _showEditStageBalanceDialog(stage),
              onAddAddition: _isReadOnly ? null : () => _showAddAdditionDialog(stage),
              onDeleteAddition: _isReadOnly ? null : (a) => _deleteAddition(a),
              onDeleteExpense: _isReadOnly ? null : (e) => _deleteExpense(e),
            );
          },
          childCount: _stages.length,
        ),
      ),
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
  // 弹窗：编辑阶段余额
  // ═══════════════════════════════════════════════════════════

  void _showEditStageBalanceDialog(StageRecord stage) {
    final appTheme = Theme.of(context).appTheme;
    String balance = stage.balance?.toStringAsFixed(2) ?? '';

    // 获取当前阶段的本金
    final stageIndex = _stages.indexWhere((s) => s.id == stage.id);
    final stageCalc = stageIndex >= 0 ? _calc!.stages[stageIndex] : null;
    final maxBalance = stageCalc?.baseAmount ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
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
                // 提示文字
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    '最大余额: ¥${maxBalance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: appTheme.earthMedium.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
                          child: Text(
                            balance.isEmpty ? '0' : balance,
                            style: TextStyle(
                              fontFamily: GoogleFonts.dmSans().fontFamily,
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: _isValidBalance(balance, maxBalance)
                                  ? appTheme.earth
                                  : appTheme.rose,
                            ),
                          ),
                        ),
                        if (balance.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              setModalState(() => balance = '');
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
                  currentValue: balance,
                  onValueChanged: (v) {
                    setModalState(() => balance = v);
                  },
                  onDone: () async {
                    final val = double.tryParse(balance);
                    // 验证余额不能超过本金
                    if (val != null && val > maxBalance) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('余额不能超过本金 ¥${maxBalance.toStringAsFixed(2)}'),
                          backgroundColor: appTheme.rose,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                      return;
                    }
                    await _service.updateStageBalance(
                      stage.id!,
                      val,
                    );
                    await _loadData();
                    Navigator.pop(ctx);
                  },
                  doneColor: _isValidBalance(balance, maxBalance)
                      ? appTheme.primary
                      : appTheme.rose,
                ),
                SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 验证余额是否有效（不超过本金）
  bool _isValidBalance(String balance, double maxBalance) {
    if (balance.isEmpty) return true;
    final val = double.tryParse(balance);
    if (val == null) return true;
    return val <= maxBalance;
  }

  // ═══════════════════════════════════════════════════════════
  // 弹窗：追加本金
  // ═══════════════════════════════════════════════════════════

  void _showAddAdditionDialog(StageRecord stage) {
    final appTheme = Theme.of(context).appTheme;
    final reasonController = TextEditingController();
    String amount = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
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
                    setModalState(() => amount = v);
                  },
                  onDone: () async {
                    final val = double.tryParse(amount);
                    final reason = reasonController.text.trim();
                    if (val == null || val <= 0 || reason.isEmpty) return;
                    await _service.addAddition(
                      stage.id!,
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
}
