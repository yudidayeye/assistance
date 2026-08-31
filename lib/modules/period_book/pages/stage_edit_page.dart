import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../shared/foundation/app_spacing.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../models/stage_record.dart';
import '../models/addition_record.dart';
import '../models/expense_record.dart';
import '../widgets/stage_card.dart';
import '../services/period_book_service.dart';
import '../widgets/expense_category_helper.dart';
import '../widgets/expense_section_card.dart';
import '../widgets/addition_section_card.dart';
import '../widgets/records_tab_card.dart';
import '../widgets/add_form.dart';
import '../widgets/edit_balance_dialog.dart';

/// 阶段编辑页（单阶段编辑 + 批量记账）
class StageEditPage extends StatefulWidget {
  final int stageId;

  const StageEditPage({super.key, required this.stageId});

  @override
  State<StageEditPage> createState() => _StageEditPageState();
}

class _StageEditPageState extends State<StageEditPage> {
  final _service = PeriodBookService.instance;

  StageRecord? _stage;
  List<AdditionRecord> _additions = [];
  List<ExpenseRecord> _expenses = [];
  StageCalculations? _stageCalc;
  double _previousBalance = 0;

  // 滚动位置保存
  final ScrollController _scrollController = ScrollController();
  double? _savedScrollOffset;

  // 内嵌表单状态
  bool _additionFormExpanded = false;
  bool _shoppingFormExpanded = false;
  bool _otherFormExpanded = false;

  final _additionReasonController = TextEditingController();
  final _additionAmountController = TextEditingController();
  final _shoppingDescController = TextEditingController();
  final _shoppingAmountController = TextEditingController();
  final _otherDescController = TextEditingController();
  final _otherAmountController = TextEditingController();
  String _shoppingCategory = '生活';
  String _otherCategory = '生活';

  // 焦点节点：金额 → 描述/原因
  final _additionAmountFocusNode = FocusNode();
  final _additionReasonFocusNode = FocusNode();
  final _shoppingAmountFocusNode = FocusNode();
  final _shoppingDescFocusNode = FocusNode();
  final _otherAmountFocusNode = FocusNode();
  final _otherDescFocusNode = FocusNode();

  bool _loading = true;

  /// 所有追加记录合计金额
  double get _additionsTotal =>
      _additions.fold(0.0, (sum, addition) => sum + addition.amount);

  /// 所有支出记录合计金额
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _additionReasonController.dispose();
    _additionAmountController.dispose();
    _shoppingDescController.dispose();
    _shoppingAmountController.dispose();
    _otherDescController.dispose();
    _otherAmountController.dispose();
    _additionAmountFocusNode.dispose();
    _additionReasonFocusNode.dispose();
    _shoppingAmountFocusNode.dispose();
    _shoppingDescFocusNode.dispose();
    _otherAmountFocusNode.dispose();
    _otherDescFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _stage = await _service.getStageById(widget.stageId);
      if (_stage != null) {
        // 如果 currentDate 为空，默认设为 endDate
        if (_stage!.currentDate == null || _stage!.currentDate!.isEmpty) {
          _stage = _stage!.copyWith(currentDate: _stage!.endDate);
        }
        _additions = await _service.getAdditionsByStage(widget.stageId);
        _expenses = await _service.getExpensesByStage(widget.stageId);

        // 计算上一阶段余额（用于 StageCard 展示）
        final period = await _service.getPeriodById(_stage!.periodId);
        if (period != null) {
          final stages = await _service.getStagesByPeriod(period.id!);
          final stageIndex = stages.indexWhere((s) => s.id == widget.stageId);
          if (stageIndex == 0) {
            _previousBalance = period.baseAmount;
          } else if (stageIndex > 0) {
            final prevStage = stages[stageIndex - 1];
            final prevCalc = await _service.getStageCalculations(
                prevStage.id!, stageIndex == 1 ? period.baseAmount : 0);
            _previousBalance = prevCalc.balance ??
                (prevCalc.baseAmount -
                    prevCalc.shoppingTotal -
                    prevCalc.otherTotal);
          }
          _stageCalc = await _service.getStageCalculations(
              widget.stageId, _previousBalance);
        }
      }
    } catch (e) {
      debugPrint('Load data error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }


  /// 刷新数据（不显示加载指示器，保持滚动位置）
  Future<void> _refreshData() async {
    try {
      _stage = await _service.getStageById(widget.stageId);
      if (_stage != null) {
        // 如果 currentDate 为空，默认设为 endDate
        if (_stage!.currentDate == null || _stage!.currentDate!.isEmpty) {
          _stage = _stage!.copyWith(currentDate: _stage!.endDate);
        }
        _additions = await _service.getAdditionsByStage(widget.stageId);
        _expenses = await _service.getExpensesByStage(widget.stageId);

        // 计算上一阶段余额（用于 StageCard 展示）
        final period = await _service.getPeriodById(_stage!.periodId);
        if (period != null) {
          final stages = await _service.getStagesByPeriod(period.id!);
          final stageIndex = stages.indexWhere((s) => s.id == widget.stageId);
          if (stageIndex == 0) {
            _previousBalance = period.baseAmount;
          } else if (stageIndex > 0) {
            final prevStage = stages[stageIndex - 1];
            final prevCalc = await _service.getStageCalculations(
                prevStage.id!, stageIndex == 1 ? period.baseAmount : 0);
            _previousBalance = prevCalc.balance ??
                (prevCalc.baseAmount -
                    prevCalc.shoppingTotal -
                    prevCalc.otherTotal);
          }
          _stageCalc = await _service.getStageCalculations(
              widget.stageId, _previousBalance);
        }
      }
    } catch (e) {
      debugPrint('Refresh data error: ');
    }
    if (mounted) setState(() {});
  }

  /// 加载数据并保持滚动位置
  Future<void> _loadDataPreserveScroll() async {
    _savedScrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : null;
    await _loadData();
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_savedScrollOffset != null &&
            _scrollController.hasClients) {
          _scrollController.jumpTo(_savedScrollOffset!);
        }
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 实时保存阶段日期修改（选择日期后立即写入数据库）
  Future<void> _saveStageDates() async {
    final stage = _stage;
    if (stage == null) return;
    final id = stage.id;
    if (id == null) return;
    try {
      await _service.updateStage(id, {
        'start_date': stage.startDate,
        'end_date': stage.endDate,
        'current_date': stage.currentDate,
      });
      // 日期变化后重新计算阶段统计（天数变化 → 杂项日均同步更新）
      if (mounted) {
        final updated = await _service.getStageById(id);
        if (updated != null) {
          final calc =
              await _service.getStageCalculations(id, _previousBalance);
          setState(() {
            _stage = updated;
            _stageCalc = calc;
          });
        }
      }
    } catch (e) {
      debugPrint('Save stage dates error: $e');
      if (mounted) {
        AppSnackBar.show(context, '保存失败: $e',
            type: AppSnackBarType.error);
      }
    }
  }

  /// 实时保存追加记录编辑（金额与原因均合法时才写入）
  void _saveAdditionEdit(
    AdditionRecord addition,
    TextEditingController reasonController,
    TextEditingController amountController,
  ) {
    if (addition.id == null) return;
    final amount = double.tryParse(amountController.text);
    final reason = reasonController.text.trim();
    if (amount == null || amount <= 0 || reason.isEmpty) return;
    _service.updateAddition(addition.id!, amount: amount, reason: reason);
  }

  /// 实时保存支出记录编辑（金额与描述均合法时才写入）
  void _saveExpenseEdit(
    ExpenseRecord expense,
    String category,
    TextEditingController amountController,
    TextEditingController descController,
  ) {
    if (expense.id == null) return;
    final amount = double.tryParse(amountController.text);
    final desc = descController.text.trim();
    if (amount == null || amount <= 0 || desc.isEmpty) return;
    _service.updateExpense(
      expense.id!,
      category: category,
      amount: amount,
      description: desc,
    );
  }

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

    if (_stage == null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: appTheme.scaffoldGradient),
          child: const Center(child: Text('阶段不存在')),
        ),
      );
    }

    final start = DateTime.parse(_stage!.startDate);
    final end = DateTime.parse(_stage!.endDate);
    final dateRange = '${start.month}/${start.day} ~ ${end.month}/${end.day}';

    return AppScrollScaffold(
      controller: _scrollController,
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: appTheme.cream,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 0,
          automaticallyImplyLeading: true,
          title: Text(
            '第${_stage!.sortOrder}阶段 · $dateRange',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
          ),
          actions: [
            IconButton(
              onPressed: () => _showEditDatesDialog(appTheme),
              icon: const Icon(Icons.edit_outlined),
              color: appTheme.earth,
              iconSize: 20,
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              20, // ToolboxBottomNav 高度
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 使用 StageCard 组件展示阶段头部
                if (_stageCalc != null)
                  StageCard(
                    stage: _stage!,
                    stageCalc: _stageCalc!,
                    previousBalance: _previousBalance,
                    additions: _additions,
                    showHeader: false,
                    expandExpenseByDefault: true,
                    personalExpenseBreakdown: _computePersonalBreakdown(),
                    onEdit: () => context.pop(),
                    onEditBalance: _showEditBalanceSheet,
                  ),
                AppSpacing.h8,
                RecordsTabCard(
                  additionLabel: '追加记录',
                  personalSection: _buildShoppingSection(appTheme),
                  otherSection: _buildOtherSection(appTheme),
                  additionSection: _buildAdditionsSection(appTheme),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 弹框：编辑阶段日期
  // ═══════════════════════════════════════════════════════════

  Future<void> _showEditDatesDialog(AppThemeExtension appTheme) async {
    final start = DateTime.parse(_stage!.startDate);
    final end = DateTime.parse(_stage!.endDate);
    final currentDateStr = _stage?.currentDate;
    final displayCurrentDate =
        currentDateStr != null ? DateTime.parse(currentDateStr) : end;

    await showDialog(
      context: context,
      barrierColor: Theme.of(context).appTheme.surfaceOverlay,
      builder: (ctx) {
        // 弹窗内实时回显的日期状态（选择后仅回显，完成时才保存并触发数据变动）
        var currentStart = start;
        var currentEnd = end;
        var currentCurrentDate = displayCurrentDate;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: appTheme.cream,
            title: Text(
              '编辑阶段日期',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: appTheme.earth,
              ),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogDateRow(
                  appTheme: appTheme,
                  label: '开始日期',
                  date: currentStart,
                  onDateChanged: (date) {
                    currentStart = date;
                    setDialogState(() {});
                  },
                ),
                AppSpacing.h12,
                _buildDialogDateRow(
                  appTheme: appTheme,
                  label: '结束日期',
                  date: currentEnd,
                  onDateChanged: (date) {
                    currentEnd = date;
                    setDialogState(() {});
                  },
                ),
                AppSpacing.h12,
                _buildDialogDateRow(
                  appTheme: appTheme,
                  label: '当前日期',
                  date: currentCurrentDate,
                  onDateChanged: (date) {
                    currentCurrentDate = date;
                    setDialogState(() {});
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('取消', style: TextStyle(color: appTheme.earthMedium)),
              ),
              TextButton(
                onPressed: () {
                  // 完成：统一提交日期修改并触发数据变动（保存 + 重算日均）
                  setState(() {
                    _stage = _stage!.copyWith(
                      startDate: _formatDate(currentStart),
                      endDate: _formatDate(currentEnd),
                      currentDate: _formatDate(currentCurrentDate),
                    );
                  });
                  _saveStageDates();
                  Navigator.pop(ctx);
                },
                child: Text('完成', style: TextStyle(color: appTheme.primary)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDialogDateRow({
    required AppThemeExtension appTheme,
    required String label,
    required DateTime date,
    required ValueChanged<DateTime> onDateChanged,
    bool highlight = false,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: highlight ? appTheme.primary : appTheme.earthMedium,
            fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null) {
              onDateChanged(picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: highlight
                  ? appTheme.primary.withValues(alpha: 0.08)
                  : appTheme.creamDark,
              borderRadius: BorderRadius.circular(appTheme.radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: highlight ? appTheme.primary : appTheme.earth,
                  ),
                ),
                AppSpacing.w4,
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: highlight ? appTheme.primary : appTheme.earthMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildAdditionsSection(AppThemeExtension appTheme) {
    return AdditionSectionCard(
      title: '追加记录',
      emptyText: '暂无追加记录',
      additions: _additions.map((a) => AdditionItemData(
        id: '${a.id}',
        reason: a.reason,
        amount: a.amount,
      )).toList(),
      color: appTheme.sage,
      prefix: '+¥',
      showAddButton: !_additionFormExpanded,
      form: _additionFormExpanded ? _buildAdditionForm(appTheme) : null,
      onAdd: () { setState(() => _additionFormExpanded = true); WidgetsBinding.instance.addPostFrameCallback((_) { if (_scrollController.hasClients) { _scrollController.animateTo( _scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut, ); } }); },
      onEdit: (data) {
        final addition = _additions.firstWhere((a) => '${a.id}' == data.id);
        _showEditAdditionSheet(appTheme, addition);
      },
      onDelete: (data) {
        final addition = _additions.firstWhere((a) => '${a.id}' == data.id);
        _deleteAddition(addition);
      },
      onReorder: (oldIndex, newIndex) {
        setState(() {
          final item = _additions.removeAt(oldIndex);
          _additions.insert(newIndex, item);
        });
        _service.updateAdditionsOrder(_additions);
      },
      leading: Icon(
        Icons.drag_handle_rounded,
        color: appTheme.earthMedium.withValues(alpha: 0.4),
        size: 18,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 弹窗：编辑阶段余额
  // ═══════════════════════════════════════════════════════════

  Future<void> _showEditBalanceSheet() async {
    final maxBalance = _stageCalc?.baseAmount ?? 0;
    
    await EditBalanceDialog.show(
      context: context,
      currentBalance: _stage!.balance,
      maxBalance: maxBalance,
      onSave: (val) async {
        await _service.updateStageBalance(widget.stageId, val);
        await _loadData();
      },
    );
  }

  Future<void> _showEditAdditionSheet(
      AppThemeExtension appTheme, AdditionRecord addition) async {
    final reasonController = TextEditingController(text: addition.reason);
    final amountController =
        TextEditingController(text: addition.amount.toStringAsFixed(2));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sheetTheme = Theme.of(ctx).appTheme;
        return StatefulBuilder(
          builder: (ctx, setLocal) => Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: sheetTheme.cream,
              borderRadius: BorderRadius.vertical(top: Radius.circular(sheetTheme.radiusXl)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '编辑追加',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: sheetTheme.earth,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: sheetTheme.earthMedium.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                AppSpacing.h16,
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '追加金额',
                    hintText: '请输入金额',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: sheetTheme.earthMedium.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: sheetTheme.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(sheetTheme.radiusSm),
                      borderSide: BorderSide(
                        color: sheetTheme.earthMedium.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  style: TextStyle(fontSize: 14, color: sheetTheme.earth),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: '追加原因',
                    hintText: '请输入追加原因',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: sheetTheme.earthMedium.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: sheetTheme.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(sheetTheme.radiusSm),
                      borderSide: BorderSide(
                        color: sheetTheme.earthMedium.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  style: TextStyle(fontSize: 14, color: sheetTheme.earth),
                ),
                AppSpacing.h16,
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      _saveAdditionEdit(
                          addition, reasonController, amountController);
                      Navigator.pop(ctx);
                    },
                    style: _primaryButtonStyle(
                      sheetTheme,
                      background: sheetTheme.primary,
                      verticalPadding: 14,
                      radius: sheetTheme.radiusMd,
                      fontSize: 15,
                    ),
                    child: const Text('保存修改'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (mounted) await _refreshData();
  }

  // ═══════════════════════════════════════════════════════════
  // 个人支出卡片
  // ═══════════════════════════════════════════════════════════

  Widget _buildShoppingSection(AppThemeExtension appTheme) {
    final shoppingExpenses = _expenses.where((e) => !e.isOther).toList();

    return ExpenseSectionCard(
      title: '个人支出',
      emptyText: '暂无个人支出',
      expenses: shoppingExpenses.map((e) => ExpenseItemData(
        id: '${e.id}',
        category: e.category,
        description: e.description,
        amount: e.amount,
      )).toList(),
      color: appTheme.rose,
      showAddButton: !_shoppingFormExpanded,
      form: _shoppingFormExpanded ? _buildShoppingForm(appTheme) : null,
      onAdd: () { setState(() => _shoppingFormExpanded = true); WidgetsBinding.instance.addPostFrameCallback((_) { if (_scrollController.hasClients) { _scrollController.animateTo( _scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut, ); } }); },
      onEdit: (data) {
        final expense = _expenses.firstWhere((e) => '${e.id}' == data.id);
        _showEditExpenseSheet(appTheme, expense);
      },
      onDelete: (data) {
        final expense = _expenses.firstWhere((e) => '${e.id}' == data.id);
        _deleteExpense(expense);
      },
      onReorder: (oldIndex, newIndex) {
        setState(() {
          final shoppingExpenses = _expenses.where((e) => !e.isOther).toList();
          final item = shoppingExpenses.removeAt(oldIndex);
          shoppingExpenses.insert(newIndex, item);
          _expenses = [
            ...shoppingExpenses,
            ..._expenses.where((e) => e.isOther),
          ];
        });
        _service.updateExpensesOrder(_expenses);
      },
      leading: Icon(
        Icons.drag_handle_rounded,
        color: appTheme.earthMedium.withValues(alpha: 0.4),
        size: 18,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 其他支出卡片
  // ═══════════════════════════════════════════════════════════

  Widget _buildOtherSection(AppThemeExtension appTheme) {
    final otherExpenses = _expenses.where((e) => e.isOther).toList();

    return ExpenseSectionCard(
      title: '其他支出',
      emptyText: '暂无其他支出',
      expenses: otherExpenses.map((e) => ExpenseItemData(
        id: '${e.id}',
        category: e.category,
        description: e.description,
        amount: e.amount,
      )).toList(),
      color: appTheme.rose,
      isOther: true,
      showAddButton: !_otherFormExpanded,
      form: _otherFormExpanded ? _buildOtherForm(appTheme) : null,
      onAdd: () { setState(() => _otherFormExpanded = true); WidgetsBinding.instance.addPostFrameCallback((_) { if (_scrollController.hasClients) { _scrollController.animateTo( _scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut, ); } }); },
      onEdit: (data) {
        final expense = _expenses.firstWhere((e) => '${e.id}' == data.id);
        _showEditExpenseSheet(appTheme, expense);
      },
      onDelete: (data) {
        final expense = _expenses.firstWhere((e) => '${e.id}' == data.id);
        _deleteExpense(expense);
      },
      onReorder: (oldIndex, newIndex) {
        setState(() {
          final otherExpenses = _expenses.where((e) => e.isOther).toList();
          final item = otherExpenses.removeAt(oldIndex);
          otherExpenses.insert(newIndex, item);
          _expenses = [
            ..._expenses.where((e) => !e.isOther),
            ...otherExpenses,
          ];
        });
        _service.updateExpensesOrder(_expenses);
      },
      leading: Icon(
        Icons.drag_handle_rounded,
        color: appTheme.earthMedium.withValues(alpha: 0.4),
        size: 18,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 个人支出内嵌表单
  // ═══════════════════════════════════════════════════════════

  Widget _buildShoppingForm(AppThemeExtension appTheme) {
    return AddForm(
      amountLabel: '金额',
      descLabel: '描述',
      amountHint: '请输入金额',
      descHint: '请输入描述',
      amountController: _shoppingAmountController,
      descController: _shoppingDescController,
      categories: ExpenseCategoryHelper.expenseCategories,
      selectedCategory: _shoppingCategory,
      onCategoryChanged: (category) =>
          setState(() => _shoppingCategory = category),
      onCollapse: () => setState(() => _shoppingFormExpanded = false),
      onConfirm: _submitShoppingExpense,
      confirmForeground: appTheme.primary,
      confirmBackground: appTheme.primary,
      confirmBorder: appTheme.primary,
    );
  }

  void _submitShoppingExpense() {
    final amount = double.tryParse(_shoppingAmountController.text);
    final desc = _shoppingDescController.text.trim();
    if (amount == null || amount <= 0 || desc.isEmpty) return;
    final category =
        ExpenseCategoryHelper.categoryToDbValue(_shoppingCategory);
    _service.addExpense(widget.stageId, category, amount, desc).then((_) {
      _shoppingAmountController.clear();
      _shoppingDescController.clear();
      _refreshData();
    });
  }

  // 其他支出内嵌表单
  Widget _buildOtherForm(AppThemeExtension appTheme) {
    return AddForm(
      amountLabel: '金额',
      descLabel: '描述',
      amountHint: '请输入金额',
      descHint: '请输入描述',
      amountController: _otherAmountController,
      descController: _otherDescController,
      categories: ExpenseCategoryHelper.expenseCategories,
      selectedCategory: _otherCategory,
      onCategoryChanged: (category) =>
          setState(() => _otherCategory = category),
      onCollapse: () => setState(() => _otherFormExpanded = false),
      onConfirm: _submitOtherExpense,
      confirmForeground: appTheme.primary,
      confirmBackground: appTheme.primary,
      confirmBorder: appTheme.primary,
    );
  }

  void _submitOtherExpense() {
    final amount = double.tryParse(_otherAmountController.text);
    final desc = _otherDescController.text.trim();
    if (amount == null || amount <= 0 || desc.isEmpty) return;
    final category = ExpenseCategoryHelper.toOtherCategory(_otherCategory);
    _service.addExpense(widget.stageId, category, amount, desc).then((_) {
      _otherAmountController.clear();
      _otherDescController.clear();
      _refreshData();
    });
  }

  // 显示名称 → 数据库存储值（反向映射，新增时用）
  static const _categoryValueMap = {
    '生活': '生活',
    '购物': '购物',
    '工作': '工作',
    '娱乐': '娱乐',
    '大餐': '大餐',
  };

  String _mapCategoryForDisplay(String dbValue) {
    return ExpenseCategoryHelper.mapCategoryForDisplay(dbValue);
  }

  String _categoryToDbValue(String displayName) {
    return _categoryValueMap[displayName] ?? displayName;
  }

  /// 计算个人支出分类明细
  Map<String, double> _computePersonalBreakdown() {
    final map = <String, double>{};
    for (final e in _expenses.where((expense) => !expense.isOther)) {
      final display = _mapCategoryForDisplay(e.category);
      map[display] = (map[display] ?? 0) + e.amount;
    }
    // 加入杂项（漏记杂项 livingTotal）
    if (_stageCalc != null) {
      final living = _stageCalc!.livingTotal ?? 0;
      if (living > 0) {
        map['杂项'] = (map['杂项'] ?? 0) + living;
      }
    }
    return map;
  }

  IconData? _categoryIcon(String displayName) {
    switch (displayName) {
      case '其他':
        return null;
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
      default:
        return Icons.category_outlined;
    }
  }

  Color _categoryColorForName(String displayName) {
    final appTheme = Theme.of(context).appTheme;
    return _categoryColor(appTheme, displayName);
  }

  Color _categoryColor(AppThemeExtension appTheme, String displayName) {
    switch (displayName) {
      case '生活':
        return appTheme.sage;
      case '购物':
        return const Color(0xFF8B7EC8); // 紫色
      case '工作':
        return const Color(0xFF3E6FA0); // 鲜明蓝
      case '娱乐':
        return const Color(0xFFC49A6C); // 柔和暖棕
      case '大餐':
        return appTheme.rose;
      default:
        return appTheme.earthMedium.withValues(alpha: 0.5);
    }
  }

  // 可选类型列表（可后续扩展）
  List<String> get _expenseCategories =>
      const ['生活', '购物', '工作', '娱乐', '大餐'];

  Future<void> _showEditExpenseSheet(
      AppThemeExtension appTheme, ExpenseRecord expense) async {
    final amountController =
        TextEditingController(text: expense.amount.toStringAsFixed(2));
    final descController = TextEditingController(text: expense.description);
    final isOther = expense.isOther;
    final initialCategory = _mapCategoryForDisplay(expense.category);
    String selectedCategory = _expenseCategories.contains(initialCategory)
        ? initialCategory
        : '生活';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sheetTheme = Theme.of(ctx).appTheme;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Container(
              padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: sheetTheme.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(sheetTheme.radiusXl)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  Text(
                    isOther ? '编辑其他支出' : '编辑支出',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: sheetTheme.earth,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: sheetTheme.earthMedium.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              AppSpacing.h12,
              // 类型选择
                Text(
                  '类型',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: sheetTheme.earthMedium.withValues(alpha: 0.7),
                  ),
                ),
                AppSpacing.h8,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _expenseCategories.map((cat) {
                    final isSelected = selectedCategory == cat;
                    final catColor = _categoryColorForName(cat);
                    return GestureDetector(
                      onTap: () {
                        setLocal(() => selectedCategory = cat);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? catColor.withValues(alpha: 0.12)
                              : sheetTheme.creamDark.withValues(alpha: 0.5),
                          borderRadius:
                              BorderRadius.circular(sheetTheme.radiusPill),
                          border: Border.all(
                            color: isSelected
                                ? catColor.withValues(alpha: 0.4)
                                : sheetTheme.earthMedium.withValues(alpha: 0.1),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? catColor.withValues(alpha: 0.85)
                                : sheetTheme.earthMedium,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              AppSpacing.h16,
              // 金额
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '金额',
                  hintText: '请输入金额',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: sheetTheme.earthMedium.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: sheetTheme.cardBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(sheetTheme.radiusSm),
                    borderSide: BorderSide(
                      color: sheetTheme.earthMedium.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                style: TextStyle(fontSize: 14, color: sheetTheme.earth),
              ),
              const SizedBox(height: 14),
              // 描述
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: '描述',
                  hintText: '请输入描述',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: sheetTheme.earthMedium.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: sheetTheme.cardBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(sheetTheme.radiusSm),
                    borderSide: BorderSide(
                      color: sheetTheme.earthMedium.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                style: TextStyle(fontSize: 14, color: sheetTheme.earth),
              ),
              AppSpacing.h16,
              // 确定按钮
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final dbCategory = isOther
                        ? ExpenseCategoryHelper.toOtherCategory(selectedCategory)
                        : _categoryToDbValue(selectedCategory);
                    _saveExpenseEdit(
                        expense, dbCategory, amountController, descController);
                    Navigator.pop(ctx);
                  },
                  style: _primaryButtonStyle(
                    sheetTheme,
                    background: sheetTheme.primary,
                    verticalPadding: 14,
                    radius: sheetTheme.radiusMd,
                    fontSize: 15,
                  ),
                  child: const Text('保存修改'),
                ),
              ),
            ],
          ),
        );
      },
    );
  },
);
    // 编辑已实时保存，关闭弹窗后刷新列表
    if (mounted) await _refreshData();
  }

  // ═══════════════════════════════════════════════════════════
  // Material 按钮样式
  // ═══════════════════════════════════════════════════════════

  /// 添加按钮样式（OutlinedButton.icon 用）
  ButtonStyle _addButtonStyle(AppThemeExtension appTheme) {
    return OutlinedButton.styleFrom(
      foregroundColor: appTheme.primary,
      backgroundColor: appTheme.primary.withValues(alpha: 0.1),
      side: BorderSide(color: appTheme.primary.withValues(alpha: 0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    );
  }

  /// 次要按钮样式（收起）
  ButtonStyle _secondaryButtonStyle(AppThemeExtension appTheme) {
    return TextButton.styleFrom(
      backgroundColor: appTheme.creamDark,
      foregroundColor: appTheme.earthMedium,
      padding: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: const TextStyle(fontSize: 14),
    );
  }

  /// 主要按钮样式（确认添加 / 保存修改）
  ButtonStyle _primaryButtonStyle(
    AppThemeExtension appTheme, {
    required Color background,
    double verticalPadding = 10,
    double? radius,
    double fontSize = 14,
  }) {
    return FilledButton.styleFrom(
      backgroundColor: background,
      foregroundColor: Colors.white,
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius ?? appTheme.radiusSm),
      ),
      textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
    );
  }

  Future<void> _deleteAddition(AdditionRecord addition) async {
    await _service.deleteAddition(addition.id!);
    await _refreshData();
  }

  Future<void> _deleteExpense(ExpenseRecord expense) async {
    await _service.deleteExpense(expense.id!);
    await _refreshData();
  }

  // ═══════════════════════════════════════════════════════════
  // 内嵌表单逻辑（需求2）
  // ═══════════════════════════════════════════════════════════

  void _submitAddition() {
    final amount = double.tryParse(_additionAmountController.text);
    final reason = _additionReasonController.text.trim();
    if (amount == null || amount <= 0 || reason.isEmpty) return;

    _service.addAddition(widget.stageId, amount, reason).then((_) {
      _additionReasonController.clear();
      _additionAmountController.clear();
      _refreshData();
    });
  }

  Widget _buildAdditionForm(AppThemeExtension appTheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appTheme.creamDark.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 金额输入
          TextField(
            controller: _additionAmountController,
            focusNode: _additionAmountFocusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            onEditingComplete: () {
              FocusScope.of(context).requestFocus(_additionReasonFocusNode);
            },
            decoration: InputDecoration(
              labelText: '追加金额',
              hintText: '请输入追加金额',
              hintStyle: TextStyle(
                fontSize: 13,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
              labelStyle: TextStyle(
                fontSize: 13,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: appTheme.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(appTheme.radiusSm),
                borderSide: BorderSide(
                  color: appTheme.earthMedium.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            style: TextStyle(fontSize: 14, color: appTheme.earth),
          ),
          const SizedBox(height: 10),
          // 原因输入
          TextField(
            controller: _additionReasonController,
            focusNode: _additionReasonFocusNode,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitAddition(),
            decoration: InputDecoration(
              labelText: '追加原因',
              hintText: '请输入追加原因',
              hintStyle: TextStyle(
                fontSize: 13,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
              labelStyle: TextStyle(
                fontSize: 13,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: appTheme.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(appTheme.radiusSm),
                borderSide: BorderSide(
                  color: appTheme.earthMedium.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            style: TextStyle(fontSize: 14, color: appTheme.earth),
          ),
          const SizedBox(height: 10),
          // 操作按钮行
          Row(
            children: [
              // 收起按钮
              Expanded(
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _additionFormExpanded = false),
                  style: _secondaryButtonStyle(appTheme),
                  icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 18),
                  label: const Text('收起'),
                ),
              ),
              const SizedBox(width: 10),
              // 确认添加按钮
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _submitAddition,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('确认添加'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: appTheme.sage,
                    backgroundColor: appTheme.sage.withValues(alpha: 0.1),
                    side: BorderSide(color: appTheme.sage.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 8 : 0),
        ],
      ),
    );
  }
}
