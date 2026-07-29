import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_segmented_tab.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/amount_chip.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../shared/foundation/app_spacing.dart';
import '../models/stage_record.dart';
import '../models/addition_record.dart';
import '../models/expense_record.dart';
import '../widgets/stage_card.dart';
import '../services/period_book_service.dart';

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

  // 内嵌表单状态
  bool _additionFormExpanded = false;
  bool _shoppingFormExpanded = false;
  bool _otherFormExpanded = false;

  // Tab 切换（0=追加记录, 1=个人支出, 2=其他支出）
  int _currentTabIndex = 0;
  final _additionReasonController = TextEditingController();
  final _additionAmountController = TextEditingController();
  final _shoppingDescController = TextEditingController();
  final _shoppingAmountController = TextEditingController();
  final _otherDescController = TextEditingController();
  final _otherAmountController = TextEditingController();

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
    } catch (e) {
      debugPrint('Save stage dates error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Theme.of(context).appTheme.rose,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Theme.of(context).appTheme.radiusSm),
            ),
          ),
        );
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
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: appTheme.cream,
          elevation: 0,
          centerTitle: false,
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
              80, // ToolboxBottomNav 高度
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
                  ),
                AppSpacing.h8,
                _buildCardTabBar(appTheme),
                AppSpacing.h12,
                _buildUnifiedCard(appTheme),
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

    await AppDialog.show(
      context,
      title: '编辑阶段日期',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDialogDateRow(
            appTheme: appTheme,
            label: '开始日期',
            date: start,
            onDateChanged: (date) {
              setState(() {
                _stage = _stage!.copyWith(startDate: _formatDate(date));
              });
              _saveStageDates();
            },
          ),
          AppSpacing.h12,
          _buildDialogDateRow(
            appTheme: appTheme,
            label: '结束日期',
            date: end,
            onDateChanged: (date) {
              setState(() {
                _stage = _stage!.copyWith(endDate: _formatDate(date));
              });
              _saveStageDates();
            },
          ),
          AppSpacing.h12,
          _buildDialogDateRow(
            appTheme: appTheme,
            label: '当前日期',
            date: displayCurrentDate,
            highlight: true,
            onDateChanged: (date) {
              setState(() {
                _stage = _stage!.copyWith(currentDate: _formatDate(date));
              });
              _saveStageDates();
            },
          ),
        ],
      ),
      cancelLabel: '取消',
      confirmLabel: '完成',
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '追加记录',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: appTheme.earth,
                ),
              ),
              const Spacer(),
              _buildTotalChip(
                appTheme: appTheme,
                amount: _additionsTotal,
                color: appTheme.sage,
                prefix: '+¥',
              ),
            ],
          ),
          AppSpacing.h12,
          if (_additions.isEmpty)
            Center(
              child: Text(
                '暂无追加记录',
                style: TextStyle(
                  fontSize: 12,
                  color: appTheme.earthMedium.withValues(alpha: 0.5),
                ),
              ),
            )
          else
            ReorderableListView(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _additions.removeAt(oldIndex);
                  _additions.insert(newIndex, item);
                });
                _service.updateAdditionsOrder(_additions);
              },
              children: [
                for (final addition in _additions)
                  _buildAdditionItem(appTheme, addition),
              ],
            ),
          AppSpacing.h8,
          if (_additionFormExpanded)
            _buildAdditionForm(appTheme)
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _additionFormExpanded = true),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('添加追加'),
                style: _addButtonStyle(appTheme),
              ),
            ),
          AppSpacing.h8,
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 统一记录卡片
  // ═══════════════════════════════════════════════════════════

  Widget _buildUnifiedCard(AppThemeExtension appTheme) {
    return Container(
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
        border: Border.all(
          color: appTheme.earthMedium.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: _buildTabContent(appTheme),
    );
  }

  Widget _buildCardTabBar(AppThemeExtension appTheme) {
    return AppSegmentedTab(
      items: const [
        AppSegmentedTabItem(label: '个人支出'),
        AppSegmentedTabItem(label: '其他支出'),
        AppSegmentedTabItem(label: '追加记录'),
      ],
      selectedIndex: _currentTabIndex,
      onChanged: (index) => setState(() => _currentTabIndex = index),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Tab 内容
  // ═══════════════════════════════════════════════════════════

  Widget _buildTabContent(AppThemeExtension appTheme) {
    switch (_currentTabIndex) {
      case 0:
        return _buildShoppingSection(appTheme);
      case 1:
        return _buildOtherSection(appTheme);
      case 2:
        return _buildAdditionsSection(appTheme);
      default:
        return _buildShoppingSection(appTheme);
    }
  }

  Widget _buildAdditionItem(
      AppThemeExtension appTheme, AdditionRecord addition) {
    return InkWell(
      key: ValueKey('addition_${addition.id}'),
      onTap: () => _showEditAdditionSheet(appTheme, addition),
      borderRadius: BorderRadius.circular(appTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: appTheme.earthMedium.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.drag_handle_rounded,
              color: appTheme.earthMedium.withValues(alpha: 0.4),
              size: 18,
            ),
            AppSpacing.w8,
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
            AppSpacing.w8,
            GestureDetector(
              onTap: () => _deleteAddition(addition),
              child: Icon(
                Icons.close,
                size: 16,
                color: appTheme.earthMedium.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
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
              color: sheetTheme.cardBackground,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
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
                // 追加金额
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
                    fillColor: sheetTheme.creamDark.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(appTheme.radiusSm),
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
                // 追加原因
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
                    fillColor: sheetTheme.creamDark.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(appTheme.radiusSm),
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
                // 确定按钮
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      // 先保存一次确保最新数据写入
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
    // 编辑已实时保存，关闭弹窗后刷新列表
    if (mounted) await _loadData();
  }

  // ═══════════════════════════════════════════════════════════
  // 个人支出卡片
  // ═══════════════════════════════════════════════════════════

  Widget _buildShoppingSection(AppThemeExtension appTheme) {
    // 个人支出 = 所有非"其他"分类（兼容已有 shopping + 新分类）
    final shoppingExpenses = _expenses
        .where((e) => e.category != 'other')
        .toList();
    final shoppingTotal =
        shoppingExpenses.fold(0.0, (sum, e) => sum + e.amount);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '个人支出',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: appTheme.earth,
                ),
              ),
              const Spacer(),
              _buildTotalChip(
                appTheme: appTheme,
                amount: shoppingTotal,
                color: appTheme.rose,
                prefix: '-¥',
              ),
            ],
          ),
          AppSpacing.h12,
          if (shoppingExpenses.isEmpty)
            Center(
              child: Text(
                '暂无个人支出',
                style: TextStyle(
                  fontSize: 12,
                  color: appTheme.earthMedium.withValues(alpha: 0.5),
                ),
              ),
            )
          else
            ReorderableListView(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = shoppingExpenses.removeAt(oldIndex);
                  shoppingExpenses.insert(newIndex, item);
                  _expenses = [
                    ...shoppingExpenses,
                    ..._expenses.where((e) => e.category == 'other'),
                  ];
                });
                _service.updateExpensesOrder(_expenses);
              },
              children: [
                for (int i = 0; i < shoppingExpenses.length; i++)
                  _buildExpenseItem(appTheme, shoppingExpenses[i], index: i),
              ],
            ),
          AppSpacing.h8,
          if (_shoppingFormExpanded)
            _buildShoppingForm(appTheme)
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _shoppingFormExpanded = true),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('添加支出'),
                style: _addButtonStyle(appTheme),
              ),
            ),
          AppSpacing.h8,
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 其他支出卡片
  // ═══════════════════════════════════════════════════════════

  Widget _buildOtherSection(AppThemeExtension appTheme) {
    final otherExpenses =
        _expenses.where((e) => e.category == 'other').toList();
    final otherTotal = otherExpenses.fold(0.0, (sum, e) => sum + e.amount);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '其他支出',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: appTheme.earth,
                ),
              ),
              const Spacer(),
              _buildTotalChip(
                appTheme: appTheme,
                amount: otherTotal,
                color: appTheme.rose,
                prefix: '-¥',
              ),
            ],
          ),
          AppSpacing.h12,
          if (otherExpenses.isEmpty)
            Center(
              child: Text(
                '暂无其他支出',
                style: TextStyle(
                  fontSize: 12,
                  color: appTheme.earthMedium.withValues(alpha: 0.5),
                ),
              ),
            )
          else
            ReorderableListView(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = otherExpenses.removeAt(oldIndex);
                  otherExpenses.insert(newIndex, item);
                  _expenses = [
                    ..._expenses.where((e) => e.category != 'other'),
                    ...otherExpenses,
                  ];
                });
                _service.updateExpensesOrder(_expenses);
              },
              children: [
                for (int i = 0; i < otherExpenses.length; i++)
                  _buildExpenseItem(appTheme, otherExpenses[i], index: i),
              ],
            ),
          AppSpacing.h8,
          if (_otherFormExpanded)
            _buildOtherForm(appTheme)
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _otherFormExpanded = true),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('添加支出'),
                style: _addButtonStyle(appTheme),
              ),
            ),
          AppSpacing.h8,
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 个人支出内嵌表单
  // ═══════════════════════════════════════════════════════════

  Widget _buildShoppingForm(AppThemeExtension appTheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appTheme.creamDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _shoppingAmountController,
            focusNode: _shoppingAmountFocusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            onEditingComplete: () {
              FocusScope.of(context).requestFocus(_shoppingDescFocusNode);
            },
            decoration: InputDecoration(
              hintText: '金额',
              hintStyle: TextStyle(
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
            style: TextStyle(fontSize: 13, color: appTheme.earth),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _shoppingDescController,
            focusNode: _shoppingDescFocusNode,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              final amount = double.tryParse(_shoppingAmountController.text);
              final desc = _shoppingDescController.text.trim();
              if (amount == null || amount <= 0 || desc.isEmpty) return;
              _service
                  .addExpense(widget.stageId, '生活', amount, desc)
                  .then((_) {
                _shoppingAmountController.clear();
                _shoppingDescController.clear();
                _loadData();
              });
            },
            decoration: InputDecoration(
              hintText: '描述',
              hintStyle: TextStyle(
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
            style: TextStyle(fontSize: 13, color: appTheme.earth),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () =>
                      setState(() => _shoppingFormExpanded = false),
                  style: _secondaryButtonStyle(appTheme),
                  child: const Text('收起'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () {
                    final amount =
                        double.tryParse(_shoppingAmountController.text);
                    final desc = _shoppingDescController.text.trim();
                    if (amount == null || amount <= 0 || desc.isEmpty) return;
                    _service
                        .addExpense(widget.stageId, '生活', amount, desc)
                        .then((_) {
                      _shoppingAmountController.clear();
                      _shoppingDescController.clear();
                      _loadData();
                    });
                  },
                  style: _primaryButtonStyle(appTheme,
                      background: appTheme.primary),
                  child: const Text('确认添加'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 其他支出内嵌表单
  // ═══════════════════════════════════════════════════════════

  Widget _buildOtherForm(AppThemeExtension appTheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appTheme.creamDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _otherAmountController,
            focusNode: _otherAmountFocusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            onEditingComplete: () {
              FocusScope.of(context).requestFocus(_otherDescFocusNode);
            },
            decoration: InputDecoration(
              hintText: '金额',
              hintStyle: TextStyle(
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
            style: TextStyle(fontSize: 13, color: appTheme.earth),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _otherDescController,
            focusNode: _otherDescFocusNode,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              final amount = double.tryParse(_otherAmountController.text);
              final desc = _otherDescController.text.trim();
              if (amount == null || amount <= 0 || desc.isEmpty) return;
              _service
                  .addExpense(widget.stageId, 'other', amount, desc)
                  .then((_) {
                _otherAmountController.clear();
                _otherDescController.clear();
                _loadData();
              });
            },
            decoration: InputDecoration(
              hintText: '描述',
              hintStyle: TextStyle(
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
            style: TextStyle(fontSize: 13, color: appTheme.earth),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _otherFormExpanded = false),
                  style: _secondaryButtonStyle(appTheme),
                  child: const Text('收起'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () {
                    final amount = double.tryParse(_otherAmountController.text);
                    final desc = _otherDescController.text.trim();
                    if (amount == null || amount <= 0 || desc.isEmpty) return;
                    _service
                        .addExpense(widget.stageId, 'other', amount, desc)
                        .then((_) {
                      _otherAmountController.clear();
                      _otherDescController.clear();
                      _loadData();
                    });
                  },
                  style: _primaryButtonStyle(appTheme,
                      background: appTheme.primary),
                  child: const Text('确认添加'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseItem(AppThemeExtension appTheme, ExpenseRecord expense,
      {int? index}) {
    final displayCat = _mapCategoryForDisplay(expense.category);
    final icon = _categoryIcon(displayCat);
    final color = _categoryColor(appTheme, displayCat);

    return InkWell(
      key: ValueKey('expense_${expense.id}'),
      onTap: () => _showEditExpenseSheet(appTheme, expense),
      borderRadius: BorderRadius.circular(appTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: appTheme.earthMedium.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.drag_handle_rounded,
              color: appTheme.earthMedium.withValues(alpha: 0.4),
              size: 18,
            ),
            AppSpacing.w8,
            if (icon != null) ...[
              Icon(icon, size: 16, color: color),
              AppSpacing.w8,
            ],
            if (expense.category != 'other')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(appTheme.radiusPill),
                ),
                child: Text(
                  displayCat,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: color.withValues(alpha: 0.85),
                  ),
                ),
              ),
            AppSpacing.w8,
            Expanded(
              child: Text(
                expense.description,
                style: TextStyle(
                  fontSize: 13,
                  color: appTheme.earth,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '-¥${expense.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: appTheme.rose,
              ),
            ),
            AppSpacing.w8,
            GestureDetector(
              onTap: () => _deleteExpense(expense),
              child: Icon(
                Icons.close,
                size: 16,
                color: appTheme.earthMedium.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 数据库 category 值 → 显示名称（兼容已有数据）
  static const _categoryDisplayMap = {
    'shopping': '购物',
    'other': '其他',
  };

  // 显示名称 → 数据库存储值（反向映射，新增时用）
  static const _categoryValueMap = {
    '生活': '生活',
    '购物': '购物',
    '工作': '工作',
    '娱乐': '娱乐',
    '大餐': '大餐',
  };

  String _mapCategoryForDisplay(String dbValue) {
    return _categoryDisplayMap[dbValue] ?? dbValue;
  }

  String _categoryToDbValue(String displayName) {
    return _categoryValueMap[displayName] ?? displayName;
  }

  /// 计算个人支出分类明细（排除 other）
  Map<String, double> _computePersonalBreakdown() {
    final map = <String, double>{};
    for (final e in _expenses) {
      if (e.category == 'other') continue;
      final display = _mapCategoryForDisplay(e.category);
      map[display] = (map[display] ?? 0) + e.amount;
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
    // 其他支出不显示类型选择，直接使用原 category
    final isOther = expense.category == 'other';
    final initialCategory = isOther
        ? '其他'
        : _mapCategoryForDisplay(expense.category);
    final showCategorySelector = !isOther;
    String selectedCategory = showCategorySelector
        ? (_expenseCategories.contains(initialCategory) ? initialCategory : '生活')
        : '其他';

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
            color: sheetTheme.cardBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
              if (showCategorySelector) ...[
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
              ] else
                AppSpacing.h12,
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
                  fillColor: sheetTheme.creamDark.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(appTheme.radiusSm),
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
                  fillColor: sheetTheme.creamDark.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(appTheme.radiusSm),
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
                    final dbCategory = showCategorySelector
                        ? _categoryToDbValue(selectedCategory)
                        : 'other';
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
    if (mounted) await _loadData();
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
        borderRadius: BorderRadius.circular(appTheme.radiusSm),
      ),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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

  /// 卡片标题行右上角的合计金额徽章
  Widget _buildTotalChip({
    required AppThemeExtension appTheme,
    required double amount,
    required Color color,
    required String prefix,
  }) {
    return Container(
      key: ValueKey(amount),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(appTheme.radiusPill),
      ),
      child: Text(
        '$prefix${amount.toStringAsFixed(2)}',
        style: TextStyle(
          fontFamily: GoogleFonts.dmSans().fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Future<void> _deleteAddition(AdditionRecord addition) async {
    await _service.deleteAddition(addition.id!);
    await _loadData();
  }

  Future<void> _deleteExpense(ExpenseRecord expense) async {
    await _service.deleteExpense(expense.id!);
    await _loadData();
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
      _loadData();
      // 保持展开状态，不清空
    });
  }

  Widget _buildAdditionForm(AppThemeExtension appTheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appTheme.creamDark.withValues(alpha: 0.5),
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
              hintText: '追加金额',
              hintStyle: TextStyle(
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
            style: TextStyle(fontSize: 13, color: appTheme.earth),
          ),
          const SizedBox(height: 10),
          // 原因输入
          TextField(
            controller: _additionReasonController,
            focusNode: _additionReasonFocusNode,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitAddition(),
            decoration: InputDecoration(
              hintText: '追加原因',
              hintStyle: TextStyle(
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
            style: TextStyle(fontSize: 13, color: appTheme.earth),
          ),
          const SizedBox(height: 10),
          // 操作按钮行
          Row(
            children: [
              // 收起按钮
              Expanded(
                child: TextButton(
                  onPressed: () =>
                      setState(() => _additionFormExpanded = false),
                  style: _secondaryButtonStyle(appTheme),
                  child: const Text('收起'),
                ),
              ),
              const SizedBox(width: 10),
              // 确认添加按钮
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _submitAddition,
                  style: _primaryButtonStyle(appTheme,
                      background: appTheme.sage),
                  child: const Text('确认添加'),
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

