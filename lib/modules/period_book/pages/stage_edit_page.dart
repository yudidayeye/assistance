import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extension.dart';
import '../models/stage_record.dart';
import '../models/addition_record.dart';
import '../models/expense_record.dart';
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

  // 批量记账相关
  List<Map<String, dynamic>> _pendingExpenses = [];
  String _newCategory = 'shopping';
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _stage = await _service.getStageById(widget.stageId);
      if (_stage != null) {
        _additions = await _service.getAdditionsByStage(widget.stageId);
        _expenses = await _service.getExpensesByStage(widget.stageId);
      }
    } catch (e) {
      debugPrint('Load data error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _addPendingExpense() {
    final amount = double.tryParse(_amountController.text);
    final description = _descriptionController.text.trim();

    if (amount == null || amount <= 0 || description.isEmpty) return;

    setState(() {
      _pendingExpenses.add({
        'category': _newCategory,
        'amount': amount,
        'description': description,
      });
      _amountController.clear();
      _descriptionController.clear();
    });
  }

  void _removePendingExpense(int index) {
    setState(() {
      _pendingExpenses.removeAt(index);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // 保存阶段日期修改
      if (_stage != null) {
        await _service.updateStage(_stage!.id!, {
          'start_date': _stage!.startDate,
          'end_date': _stage!.endDate,
        });
      }

      // 批量添加支出
      if (_pendingExpenses.isNotEmpty && _stage != null) {
        await _service.batchAddExpenses(_stage!.id!, _pendingExpenses);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存成功${_pendingExpenses.isNotEmpty ? "，已添加 ${_pendingExpenses.length} 条支出" : ""}'),
            backgroundColor: Theme.of(context).appTheme.sage,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Theme.of(context).appTheme.rose,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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

    if (_stage == null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: appTheme.scaffoldGradient),
          child: const Center(child: Text('阶段不存在')),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: appTheme.scaffoldGradient),
        child: Column(
          children: [
            _buildHeader(appTheme),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildDateSection(appTheme),
                    const SizedBox(height: 16),
                    _buildAdditionsSection(appTheme),
                    const SizedBox(height: 16),
                    _buildExpensesSection(appTheme),
                    const SizedBox(height: 16),
                    _buildBatchExpenseSection(appTheme),
                    const SizedBox(height: 20),
                    _buildSaveButton(appTheme),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppThemeExtension appTheme) {
    final safeTop = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, safeTop + 16, 24, 16),
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
          Text(
            '第${_stage!.sortOrder}阶段',
            style: TextStyle(
              fontFamily: GoogleFonts.dmSans().fontFamily,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: appTheme.earth,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSection(AppThemeExtension appTheme) {
    final start = DateTime.parse(_stage!.startDate);
    final end = DateTime.parse(_stage!.endDate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: appTheme.cardShadow,
        border: Border.all(color: appTheme.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '阶段日期',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: appTheme.earth,
            ),
          ),
          const SizedBox(height: 12),
          _buildDateRow(
            appTheme: appTheme,
            label: '开始日期',
            date: start,
            onDateChanged: (date) {
              setState(() {
                _stage = _stage!.copyWith(
                  startDate: '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                );
              });
            },
          ),
          const SizedBox(height: 12),
          _buildDateRow(
            appTheme: appTheme,
            label: '结束日期',
            date: end,
            onDateChanged: (date) {
              setState(() {
                _stage = _stage!.copyWith(
                  endDate: '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow({
    required AppThemeExtension appTheme,
    required String label,
    required DateTime date,
    required ValueChanged<DateTime> onDateChanged,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: appTheme.earthMedium,
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
              color: appTheme.creamDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: appTheme.earth,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: appTheme.primary,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: appTheme.cardShadow,
        border: Border.all(color: appTheme.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '追加记录',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: appTheme.earth,
            ),
          ),
          const SizedBox(height: 12),
          if (_additions.isEmpty)
            Text(
              '暂无追加记录',
              style: TextStyle(
                fontSize: 12,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
            )
          else
            ..._additions.map((addition) => _buildAdditionItem(appTheme, addition)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showAddAdditionDialog(),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: appTheme.sage.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '+ 添加追加',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: appTheme.sage,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionItem(AppThemeExtension appTheme, AdditionRecord addition) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
          const SizedBox(width: 8),
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
    );
  }

  Widget _buildExpensesSection(AppThemeExtension appTheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: appTheme.cardShadow,
        border: Border.all(color: appTheme.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '已有支出',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: appTheme.earth,
            ),
          ),
          const SizedBox(height: 12),
          if (_expenses.isEmpty)
            Text(
              '暂无支出记录',
              style: TextStyle(
                fontSize: 12,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
            )
          else
            ..._expenses.map((expense) => _buildExpenseItem(appTheme, expense)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildExpenseItem(AppThemeExtension appTheme, ExpenseRecord expense) {
    final icon = expense.category == 'shopping'
        ? Icons.shopping_bag_outlined
        : Icons.category_outlined;
    final color = expense.category == 'shopping'
        ? appTheme.sage
        : appTheme.roseLight;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
          Icon(icon, size: 16, color: color),
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
              color: appTheme.earth,
            ),
          ),
          const SizedBox(width: 8),
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
    );
  }

  Widget _buildBatchExpenseSection(AppThemeExtension appTheme) {
    final total = _pendingExpenses.fold<double>(0, (sum, e) => sum + (e['amount'] as double));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: appTheme.cardShadow,
        border: Border.all(color: appTheme.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '添加支出',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: appTheme.earth,
                ),
              ),
              const Spacer(),
              if (_pendingExpenses.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    setState(() => _pendingExpenses.clear());
                  },
                  child: Text(
                    '清空',
                    style: TextStyle(
                      fontSize: 13,
                      color: appTheme.rose,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // 待保存列表
          if (_pendingExpenses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  '暂无待保存条目，请在下方添加',
                  style: TextStyle(
                    fontSize: 12,
                    color: appTheme.earthMedium.withValues(alpha: 0.5),
                  ),
                ),
              ),
            )
          else ...[
            ..._pendingExpenses.asMap().entries.map((entry) {
              final index = entry.key;
              final expense = entry.value;
              return _buildPendingExpenseItem(appTheme, index, expense);
            }),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: appTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text(
                    '待保存合计:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: appTheme.earth,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_pendingExpenses.length} 条',
                    style: TextStyle(
                      fontSize: 12,
                      color: appTheme.earthMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '¥${total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: appTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          // 分类选择
          Text(
            '分类',
            style: TextStyle(
              fontSize: 13,
              color: appTheme.earthMedium,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildCategoryChip(
                appTheme: appTheme,
                label: '购物',
                icon: Icons.shopping_bag_outlined,
                isSelected: _newCategory == 'shopping',
                color: appTheme.sage,
                onTap: () => setState(() => _newCategory = 'shopping'),
              ),
              const SizedBox(width: 12),
              _buildCategoryChip(
                appTheme: appTheme,
                label: '其他',
                icon: Icons.category_outlined,
                isSelected: _newCategory == 'other',
                color: appTheme.roseLight,
                onTap: () => setState(() => _newCategory = 'other'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 金额输入
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: '金额',
              hintStyle: TextStyle(
                fontSize: 13,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: appTheme.creamDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: TextStyle(fontSize: 13, color: appTheme.earth),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          // 描述输入
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              hintText: '描述（如：超市采购）',
              hintStyle: TextStyle(
                fontSize: 13,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: appTheme.creamDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: TextStyle(fontSize: 13, color: appTheme.earth),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          // 添加到列表按钮
          GestureDetector(
            onTap: _canAddExpense ? _addPendingExpense : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _canAddExpense ? appTheme.primary : appTheme.creamDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '+ 添加到列表',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _canAddExpense ? Colors.white : appTheme.earthMedium.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _canAddExpense {
    final amount = double.tryParse(_amountController.text);
    final description = _descriptionController.text.trim();
    return amount != null && amount > 0 && description.isNotEmpty;
  }

  Widget _buildPendingExpenseItem(
    AppThemeExtension appTheme,
    int index,
    Map<String, dynamic> expense,
  ) {
    final category = expense['category'] as String;
    final amount = expense['amount'] as double;
    final description = expense['description'] as String;
    final icon = category == 'shopping' ? Icons.shopping_bag_outlined : Icons.category_outlined;
    final color = category == 'shopping' ? appTheme.sage : appTheme.roseLight;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: index > 0 ? Border(
          top: BorderSide(
            color: appTheme.earthMedium.withValues(alpha: 0.07),
            width: 0.5,
          ),
        ) : null,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: appTheme.earth,
              ),
            ),
          ),
          Text(
            '¥${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: appTheme.earth,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _removePendingExpense(index),
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: appTheme.earthMedium.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required AppThemeExtension appTheme,
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : appTheme.creamDark,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: color.withValues(alpha: 0.3), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? color : appTheme.earthMedium),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : appTheme.earthMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(AppThemeExtension appTheme) {
    final canSave = !_saving;

    return GestureDetector(
      onTap: canSave ? _save : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: canSave
              ? LinearGradient(
                  colors: [appTheme.primary, appTheme.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: canSave ? null : appTheme.creamDark,
          borderRadius: BorderRadius.circular(appTheme.radiusMd),
          boxShadow: canSave
              ? [
                  BoxShadow(
                    color: appTheme.primary.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: _saving
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  '保存修改',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: canSave ? Colors.white : appTheme.earthMedium.withValues(alpha: 0.4),
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }

  void _showAddAdditionDialog() {
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
                      widget.stageId,
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

  Future<void> _deleteAddition(AdditionRecord addition) async {
    await _service.deleteAddition(addition.id!);
    await _loadData();
  }

  Future<void> _deleteExpense(ExpenseRecord expense) async {
    await _service.deleteExpense(expense.id!);
    await _loadData();
  }
}
