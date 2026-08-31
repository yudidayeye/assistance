import 'package:flutter/material.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_segmented_tab.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../shared/foundation/app_spacing.dart';
import '../models/period_record.dart';
import '../models/large_addition_record.dart';
import '../models/large_expense_record.dart';
import '../services/period_book_service.dart';
import '../widgets/expense_category_helper.dart';
import '../widgets/expense_section_card.dart';
import '../widgets/addition_section_card.dart';
import '../widgets/add_form.dart';

/// 大额记录编辑页（周期级，不计入总本金和总支出）
class LargeItemsEditPage extends StatefulWidget {
  final int periodId;

  const LargeItemsEditPage({super.key, required this.periodId});

  @override
  State<LargeItemsEditPage> createState() => _LargeItemsEditPageState();
}

class _LargeItemsEditPageState extends State<LargeItemsEditPage> {
  final _service = PeriodBookService.instance;

  PeriodRecord? _period;
  List<LargeAdditionRecord> _additions = [];
  List<LargeExpenseRecord> _shoppingExpenses = [];
  List<LargeExpenseRecord> _otherExpenses = [];

  // Tab 切换（0=大额追加, 1=购物支出, 2=其他支出）
  int _currentTabIndex = 0;
  bool _additionFormExpanded = false;
  bool _shoppingFormExpanded = false;
  bool _otherFormExpanded = false;
  final _additionReasonController = TextEditingController();
  final _additionAmountController = TextEditingController();
  final _shoppingAmountController = TextEditingController();
  final _shoppingDescController = TextEditingController();
  final _otherAmountController = TextEditingController();
  final _otherDescController = TextEditingController();
  String _shoppingCategory = '生活';
  String _otherCategory = '生活';

  bool _loading = true;

  // 滚动位置保存
  final ScrollController _scrollController = ScrollController();
  double? _savedScrollOffset;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _additionReasonController.dispose();
    _additionAmountController.dispose();
    _shoppingAmountController.dispose();
    _shoppingDescController.dispose();
    _otherAmountController.dispose();
    _otherDescController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _period = await _service.getPeriodById(widget.periodId);
      if (_period != null) {
        _additions = await _service.getLargeAdditionsByPeriod(widget.periodId);
        final allExpenses =
            await _service.getLargeExpensesByPeriod(widget.periodId);
        _shoppingExpenses =
            allExpenses.where((e) => !e.isOther).toList();
        _otherExpenses =
            allExpenses.where((e) => e.isOther).toList();
      }
    } catch (e) {
      debugPrint('Load large items error: $e');
    }
    if (mounted) setState(() => _loading = false);
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
          child: const Center(child: Text('周期不存在')),
        ),
      );
    }

    final start = DateTime.parse(_period!.startDate);
    final end = DateTime.parse(_period!.endDate);
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
            '大额记录 · $dateRange',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardTabBar(appTheme),
                AppSpacing.h8,
                _buildUnifiedCard(appTheme),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 统一记录卡片（Tab 切换）
  // ═══════════════════════════════════════════════════════════

  Widget _buildUnifiedCard(AppThemeExtension appTheme) {
    return Card(
      color: appTheme.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
        side: BorderSide(color: appTheme.cardBorder, width: 1),
      ),
      elevation: 0,
      child: _buildTabContent(appTheme),
    );
  }

  Widget _buildCardTabBar(AppThemeExtension appTheme) {
    return AppSegmentedTab(
      items: const [
        AppSegmentedTabItem(label: '大额追加'),
        AppSegmentedTabItem(label: '个人支出'),
        AppSegmentedTabItem(label: '其他支出'),
      ],
      selectedIndex: _currentTabIndex,
      onChanged: (index) => setState(() => _currentTabIndex = index),
    );
  }

  Widget _buildTabContent(AppThemeExtension appTheme) {
    switch (_currentTabIndex) {
      case 0:
        return _buildAdditionsSection(appTheme);
      case 1:
        return _buildShoppingSection(appTheme);
      case 2:
        return _buildOtherSection(appTheme);
      default:
        return _buildAdditionsSection(appTheme);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 大额追加
  // ═══════════════════════════════════════════════════════════

  Widget _buildAdditionsSection(AppThemeExtension appTheme) {
    return AdditionSectionCard(
      title: '大额追加',
      emptyText: '暂无大额追加',
      additions: _additions.map((a) => AdditionItemData(
        id: 'large_${a.id}',
        reason: a.reason,
        amount: a.amount,
      )).toList(),
      color: appTheme.sage,
      prefix: '+¥',
      showAddButton: !_additionFormExpanded,
      form: _additionFormExpanded ? _buildAdditionForm(appTheme) : null,
      onAdd: () => setState(() => _additionFormExpanded = true),
      onEdit: (data) {
        final addition = _additions.firstWhere((a) => 'large_${a.id}' == data.id);
        _showEditAdditionSheet(appTheme, addition);
      },
      onDelete: (data) {
        final addition = _additions.firstWhere((a) => 'large_${a.id}' == data.id);
        _deleteAddition(addition);
      },
      onReorder: (oldIndex, newIndex) {
        setState(() {
          final item = _additions.removeAt(oldIndex);
          _additions.insert(newIndex, item);
        });
        _service.updateLargeAdditionsOrder(_additions);
      },
      leading: Icon(
        Icons.drag_handle_rounded,
        color: appTheme.earthMedium.withValues(alpha: 0.4),
        size: 18,
      ),
    );
  }

  Widget _buildAdditionForm(AppThemeExtension appTheme) {
    return AddForm(
      amountLabel: '追加金额',
      descLabel: '追加原因',
      amountHint: '请输入金额',
      descHint: '请输入追加原因',
      amountController: _additionAmountController,
      descController: _additionReasonController,
      onCollapse: () => setState(() => _additionFormExpanded = false),
      onConfirm: _submitAddition,
      confirmText: '确认添加',
      confirmForeground: appTheme.sage,
      confirmBackground: appTheme.sage,
      confirmBorder: appTheme.sage,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 购物支出
  // ═══════════════════════════════════════════════════════════

  Widget _buildShoppingSection(AppThemeExtension appTheme) {
    return ExpenseSectionCard(
      title: '个人支出',
      emptyText: '暂无个人支出',
      expenses: _shoppingExpenses.map((e) => ExpenseItemData(
        id: 'large_${e.id}',
        category: e.category,
        description: e.description,
        amount: e.amount,
      )).toList(),
      color: appTheme.rose,
      showAddButton: !_shoppingFormExpanded,
      form: _shoppingFormExpanded ? _buildShoppingForm(appTheme) : null,
      onAdd: () => setState(() => _shoppingFormExpanded = true),
      onEdit: (data) {
        final expense = _shoppingExpenses.firstWhere((e) => 'large_${e.id}' == data.id);
        _showEditExpenseSheet(appTheme, expense);
      },
      onDelete: (data) {
        final expense = _shoppingExpenses.firstWhere((e) => 'large_${e.id}' == data.id);
        _deleteExpense(expense);
      },
      onReorder: (oldIndex, newIndex) {
        setState(() {
          final item = _shoppingExpenses.removeAt(oldIndex);
          _shoppingExpenses.insert(newIndex, item);
        });
        _updateShoppingExpensesOrder();
      },
      leading: Icon(
        Icons.drag_handle_rounded,
        color: appTheme.earthMedium.withValues(alpha: 0.4),
        size: 18,
      ),
    );
  }

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
      confirmText: '确认添加',
      confirmForeground: appTheme.primary,
      confirmBackground: appTheme.primary,
      confirmBorder: appTheme.primary,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 其他支出
  // ═══════════════════════════════════════════════════════════

  Widget _buildOtherSection(AppThemeExtension appTheme) {
    return ExpenseSectionCard(
      title: '其他支出',
      emptyText: '暂无其他支出',
      expenses: _otherExpenses.map((e) => ExpenseItemData(
        id: 'large_${e.id}',
        category: e.category,
        description: e.description,
        amount: e.amount,
      )).toList(),
      color: appTheme.rose,
      isOther: true,
      showAddButton: !_otherFormExpanded,
      form: _otherFormExpanded ? _buildOtherForm(appTheme) : null,
      onAdd: () => setState(() => _otherFormExpanded = true),
      onEdit: (data) {
        final expense = _otherExpenses.firstWhere((e) => 'large_${e.id}' == data.id);
        _showEditExpenseSheet(appTheme, expense);
      },
      onDelete: (data) {
        final expense = _otherExpenses.firstWhere((e) => 'large_${e.id}' == data.id);
        _deleteExpense(expense);
      },
      onReorder: (oldIndex, newIndex) {
        setState(() {
          final item = _otherExpenses.removeAt(oldIndex);
          _otherExpenses.insert(newIndex, item);
        });
        _updateOtherExpensesOrder();
      },
      leading: Icon(
        Icons.drag_handle_rounded,
        color: appTheme.earthMedium.withValues(alpha: 0.4),
        size: 18,
      ),
    );
  }

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
      confirmText: '确认添加',
      confirmForeground: appTheme.primary,
      confirmBackground: appTheme.primary,
      confirmBorder: appTheme.primary,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 编辑弹窗
  // ═══════════════════════════════════════════════════════════

  Future<void> _showEditAdditionSheet(
      AppThemeExtension appTheme, LargeAdditionRecord addition) async {
    final amountController =
        TextEditingController(text: addition.amount.toStringAsFixed(2));
    final reasonController = TextEditingController(text: addition.reason);

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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  style: TextStyle(fontSize: 14, color: sheetTheme.earth),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: '原因',
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
                    onPressed: () async {
                      final amount = double.tryParse(amountController.text);
                      final reason = reasonController.text.trim();
                      if (amount == null || amount <= 0 || reason.isEmpty)
                        return;
                      await _service.updateLargeAddition(
                        addition.id!,
                        amount: amount,
                        reason: reason,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _loadDataPreserveScroll();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: sheetTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(appTheme.radiusSm),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('保存修改'),
                  ),
                ),
                SizedBox(
                    height: MediaQuery.of(context).padding.bottom > 0 ? 8 : 0),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditExpenseSheet(
      AppThemeExtension appTheme, LargeExpenseRecord expense) async {
    final isOther = expense.isOther;

    await ExpenseCategoryHelper.showEditExpenseSheet(
      context: context,
      appTheme: appTheme,
      category: expense.category,
      amount: expense.amount,
      description: expense.description,
      showCategorySelector: true,
      isOther: isOther,
      onSave: (dbCategory, amount, description) async {
        await _service.updateLargeExpense(
          expense.id!,
          category: dbCategory,
          amount: amount,
          description: description,
        );
        await _loadDataPreserveScroll();
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 操作
  // ═══════════════════════════════════════════════════════════

  Future<void> _deleteAddition(LargeAdditionRecord addition) async {
    await _service.deleteLargeAddition(addition.id!);
    await _loadDataPreserveScroll();
  }

  Future<void> _deleteExpense(LargeExpenseRecord expense) async {
    await _service.deleteLargeExpense(expense.id!);
    await _loadDataPreserveScroll();
  }

  // ═══════════════════════════════════════════════════════════
  // 排序
  // ═══════════════════════════════════════════════════════════

  Future<void> _updateShoppingExpensesOrder() async {
    final allExpenses = [
      ..._shoppingExpenses.map((e) => LargeExpenseRecord(
            id: e.id,
            periodId: e.periodId,
            category: e.category,
            amount: e.amount,
            description: e.description,
            sortOrder: 0,
            createdAt: e.createdAt,
          )),
      ..._otherExpenses.map((e) => LargeExpenseRecord(
            id: e.id,
            periodId: e.periodId,
            category: e.category,
            amount: e.amount,
            description: e.description,
            sortOrder: 0,
            createdAt: e.createdAt,
          )),
    ];
    for (var i = 0; i < allExpenses.length; i++) {
      await _service.updateLargeExpense(allExpenses[i].id!, sortOrder: i);
    }
  }

  Future<void> _updateOtherExpensesOrder() async {
    final allExpenses = [
      ..._shoppingExpenses.map((e) => LargeExpenseRecord(
            id: e.id,
            periodId: e.periodId,
            category: e.category,
            amount: e.amount,
            description: e.description,
            sortOrder: 0,
            createdAt: e.createdAt,
          )),
      ..._otherExpenses.map((e) => LargeExpenseRecord(
            id: e.id,
            periodId: e.periodId,
            category: e.category,
            amount: e.amount,
            description: e.description,
            sortOrder: 0,
            createdAt: e.createdAt,
          )),
    ];
    for (var i = 0; i < allExpenses.length; i++) {
      await _service.updateLargeExpense(allExpenses[i].id!, sortOrder: i);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 表单提交
  // ═══════════════════════════════════════════════════════════

  void _submitAddition() {
    final amount = double.tryParse(_additionAmountController.text);
    final reason = _additionReasonController.text.trim();
    if (amount == null || amount <= 0 || reason.isEmpty) return;

    _service.addLargeAddition(widget.periodId, amount, reason).then((_) {
      _additionReasonController.clear();
      _additionAmountController.clear();
      _loadDataPreserveScroll();
    });
  }

  void _submitShoppingExpense() {
    final amount = double.tryParse(_shoppingAmountController.text);
    final desc = _shoppingDescController.text.trim();
    if (amount == null || amount <= 0 || desc.isEmpty) return;

    _service
        .addLargeExpense(
          widget.periodId,
          ExpenseCategoryHelper.categoryToDbValue(_shoppingCategory),
          amount,
          desc,
        )
        .then((_) {
      _shoppingAmountController.clear();
      _shoppingDescController.clear();
      _loadDataPreserveScroll();
    });
  }

  void _submitOtherExpense() {
    final amount = double.tryParse(_otherAmountController.text);
    final desc = _otherDescController.text.trim();
    if (amount == null || amount <= 0 || desc.isEmpty) return;

    _service
        .addLargeExpense(
          widget.periodId,
          ExpenseCategoryHelper.toOtherCategory(_otherCategory),
          amount,
          desc,
        )
        .then((_) {
      _otherAmountController.clear();
      _otherDescController.clear();
      _loadDataPreserveScroll();
    });
  }
}
