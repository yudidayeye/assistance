import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extension.dart';
import '../models/period_record.dart';
import '../models/stage_record.dart';
import '../services/period_book_service.dart';

/// 批量记账页
class BatchExpensePage extends StatefulWidget {
  final int periodId;

  const BatchExpensePage({super.key, required this.periodId});

  @override
  State<BatchExpensePage> createState() => _BatchExpensePageState();
}

class _BatchExpensePageState extends State<BatchExpensePage> {
  final _service = PeriodBookService.instance;

  PeriodRecord? _period;
  List<StageRecord> _stages = [];
  StageRecord? _selectedStage;
  List<Map<String, dynamic>> _expenses = []; // [{category, amount, description}]

  bool _loading = true;
  bool _saving = false;

  String _newCategory = 'shopping';
  String _newAmount = '';
  String _newDescription = '';

  // 使用 controller 来清空输入框
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _period = await _service.getPeriodById(widget.periodId);
      _stages = await _service.getStagesByPeriod(widget.periodId);
      if (_stages.isNotEmpty && mounted) {
        setState(() {
          _selectedStage = _stages.first;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Load data error: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _addExpense() {
    if (_newAmount.isEmpty || _newDescription.isEmpty) return;

    setState(() {
      _expenses.add({
        'category': _newCategory,
        'amount': double.parse(_newAmount),
        'description': _newDescription,
      });
      _newAmount = '';
      _newDescription = '';
      // 清空输入框
      _amountController.clear();
      _descriptionController.clear();
    });
  }

  void _removeExpense(int index) {
    setState(() {
      _expenses.removeAt(index);
    });
  }

  Future<void> _saveExpenses() async {
    if (_selectedStage == null || _expenses.isEmpty) return;

    setState(() => _saving = true);
    try {
      await _service.batchAddExpenses(_selectedStage!.id!, _expenses);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已保存 ${_expenses.length} 条记录'),
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
      debugPrint('Save error: $e');
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

    if (_period == null || _stages.isEmpty) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: appTheme.scaffoldGradient),
          child: const Center(child: Text('无可用阶段')),
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
                    _buildStageSelector(appTheme),
                    const SizedBox(height: 20),
                    _buildExpenseTable(appTheme),
                    const SizedBox(height: 20),
                    _buildAddForm(appTheme),
                    const SizedBox(height: 20),
                    _buildSummary(appTheme),
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

  // ═══════════════════════════════════════════════════════════
  // 头部
  // ═══════════════════════════════════════════════════════════

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
            '批量记账',
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

  // ═══════════════════════════════════════════════════════════
  // 阶段选择器
  // ═══════════════════════════════════════════════════════════

  Widget _buildStageSelector(AppThemeExtension appTheme) {
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
          // 标题
          Row(
            children: [
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
                child: Icon(Icons.layers_outlined, color: appTheme.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                '选择阶段',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: appTheme.earth,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 阶段选择网格
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _stages.map((stage) {
              final isSelected = _selectedStage?.id == stage.id;
              final start = DateTime.parse(stage.startDate);
              final end = DateTime.parse(stage.endDate);

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedStage = stage);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? appTheme.primary.withValues(alpha: 0.12)
                        : appTheme.creamDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? appTheme.primary.withValues(alpha: 0.3)
                          : appTheme.cardBorder,
                      width: isSelected ? 1.5 : 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '第${stage.sortOrder}周',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? appTheme.primary : appTheme.earth,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${start.month}.${start.day}-${end.month}.${end.day}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? appTheme.primary.withValues(alpha: 0.7)
                              : appTheme.earthMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 支出表格
  // ═══════════════════════════════════════════════════════════

  Widget _buildExpenseTable(AppThemeExtension appTheme) {
    return Container(
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: appTheme.cardShadow,
        border: Border.all(color: appTheme.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Text(
                  '待记账条目',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: appTheme.earth,
                  ),
                ),
                const Spacer(),
                if (_expenses.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() => _expenses.clear());
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
          ),
          if (_expenses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '暂无条目，请在下方添加',
                  style: TextStyle(
                    fontSize: 13,
                    color: appTheme.earthMedium.withValues(alpha: 0.5),
                  ),
                ),
              ),
            )
          else
            ..._expenses.asMap().entries.map((entry) {
              final index = entry.key;
              final expense = entry.value;
              return _buildExpenseRow(
                appTheme: appTheme,
                index: index,
                expense: expense,
              );
            }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildExpenseRow({
    required AppThemeExtension appTheme,
    required int index,
    required Map<String, dynamic> expense,
  }) {
    final category = expense['category'] as String;
    final amount = expense['amount'] as double;
    final description = expense['description'] as String;
    final icon = category == 'shopping' ? Icons.shopping_bag_outlined : Icons.category_outlined;
    final color = category == 'shopping' ? appTheme.sage : appTheme.roseLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
            flex: 2,
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: appTheme.earth,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '¥${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: appTheme.earth,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 编辑按钮
          GestureDetector(
            onTap: () => _showEditExpenseDialog(index, expense),
            child: Icon(
              Icons.edit_outlined,
              size: 18,
              color: appTheme.primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _removeExpense(index),
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

  // ═══════════════════════════════════════════════════════════
  // 添加表单
  // ═══════════════════════════════════════════════════════════

  Widget _buildAddForm(AppThemeExtension appTheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: appTheme.cardShadow,
        border: Border.all(color: appTheme.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '添加新条目',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: appTheme.earth,
            ),
          ),
          const SizedBox(height: 12),
          // 分类选择
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
            onChanged: (v) => setState(() => _newAmount = v),
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
            onChanged: (v) => setState(() => _newDescription = v),
          ),
          const SizedBox(height: 12),
          // 添加按钮
          GestureDetector(
            onTap: _newAmount.isNotEmpty && _newDescription.isNotEmpty ? _addExpense : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _newAmount.isNotEmpty && _newDescription.isNotEmpty
                    ? appTheme.primary
                    : appTheme.creamDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '+ 添加到列表',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _newAmount.isNotEmpty && _newDescription.isNotEmpty
                        ? Colors.white
                        : appTheme.earthMedium.withValues(alpha: 0.4),
                  ),
                ),
              ),
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

  // ═══════════════════════════════════════════════════════════
  // 汇总
  // ═══════════════════════════════════════════════════════════

  Widget _buildSummary(AppThemeExtension appTheme) {
    final total = _expenses.fold<double>(0, (sum, e) => sum + (e['amount'] as double));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appTheme.primary.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Text(
            '本次合计:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: appTheme.earth,
            ),
          ),
          const Spacer(),
          Text(
            '${_expenses.length} 条',
            style: TextStyle(
              fontSize: 13,
              color: appTheme.earthMedium,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '¥${total.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: appTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 保存按钮
  // ═══════════════════════════════════════════════════════════

  Widget _buildSaveButton(AppThemeExtension appTheme) {
    final canSave = _expenses.isNotEmpty && !_saving;

    return GestureDetector(
      onTap: canSave ? _saveExpenses : null,
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
                  '保存所有记录',
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

  // ═══════════════════════════════════════════════════════════
  // 编辑条目对话框
  // ═══════════════════════════════════════════════════════════

  void _showEditExpenseDialog(int index, Map<String, dynamic> expense) {
    final appTheme = Theme.of(context).appTheme;
    final categoryController = TextEditingController(text: expense['category'] as String);
    final amountController = TextEditingController(text: (expense['amount'] as double).toString());
    final descriptionController = TextEditingController(text: expense['description'] as String);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: appTheme.cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: appTheme.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '编辑条目',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: appTheme.earth,
              ),
            ),
            const SizedBox(height: 20),
            // 分类选择
            Text(
              '分类',
              style: TextStyle(
                fontSize: 14,
                color: appTheme.earthMedium,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildCategoryButton(
                    appTheme,
                    '购物',
                    Icons.shopping_bag_outlined,
                    categoryController.text == 'shopping',
                    appTheme.sage,
                    () {
                      setState(() => categoryController.text = 'shopping');
                      Navigator.pop(ctx);
                      _showEditExpenseDialog(index, {
                        ...expense,
                        'category': 'shopping',
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCategoryButton(
                    appTheme,
                    '其他',
                    Icons.category_outlined,
                    categoryController.text == 'other',
                    appTheme.roseLight,
                    () {
                      setState(() => categoryController.text = 'other');
                      Navigator.pop(ctx);
                      _showEditExpenseDialog(index, {
                        ...expense,
                        'category': 'other',
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 金额输入
            Text(
              '金额',
              style: TextStyle(
                fontSize: 14,
                color: appTheme.earthMedium,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '输入金额',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: appTheme.earthMedium.withValues(alpha: 0.4),
                ),
                filled: true,
                fillColor: appTheme.creamDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: appTheme.earth,
              ),
            ),
            const SizedBox(height: 16),
            // 描述输入
            Text(
              '描述',
              style: TextStyle(
                fontSize: 14,
                color: appTheme.earthMedium,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                hintText: '输入描述',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: appTheme.earthMedium.withValues(alpha: 0.4),
                ),
                filled: true,
                fillColor: appTheme.creamDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              style: TextStyle(
                fontSize: 16,
                color: appTheme.earth,
              ),
            ),
            const SizedBox(height: 20),
            // 保存按钮
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: appTheme.creamDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: appTheme.earthMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () {
                      final amount = double.tryParse(amountController.text);
                      final description = descriptionController.text.trim();
                      final category = categoryController.text;

                      if (amount == null || amount <= 0 || description.isEmpty) {
                        return;
                      }

                      setState(() {
                        _expenses[index] = {
                          'category': category,
                          'amount': amount,
                          'description': description,
                        };
                      });
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [appTheme.primary, appTheme.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '保存',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryButton(
    AppThemeExtension appTheme,
    String label,
    IconData icon,
    bool isSelected,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : appTheme.creamDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.5) : appTheme.cardBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isSelected ? color : appTheme.earthMedium),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : appTheme.earthMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
