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

  // 内嵌表单状态
  bool _additionFormExpanded = false;
  bool _expenseFormExpanded = false;
  final _additionReasonController = TextEditingController();
  final _additionAmountController = TextEditingController();
  String _expenseCategory = 'shopping';
  final _expenseAmountController = TextEditingController();
  final _expenseDescriptionController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _additionReasonController.dispose();
    _expenseAmountController.dispose();
    _expenseDescriptionController.dispose();
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
      }
    } catch (e) {
      debugPrint('Load data error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // 保存阶段日期修改
      if (_stage != null) {
        await _service.updateStage(_stage!.id!, {
          'start_date': _stage!.startDate,
          'end_date': _stage!.endDate,
          'current_date': _stage!.currentDate,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('保存成功'),
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
      padding: EdgeInsets.fromLTRB(24, safeTop + 12, 24, 12),
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
          const SizedBox(height: 12),
          _buildCurrentDateRow(appTheme),
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

  Widget _buildCurrentDateRow(AppThemeExtension appTheme) {
    final currentDateStr = _stage?.currentDate;
    final start = DateTime.parse(_stage!.startDate);
    final end = DateTime.parse(_stage!.endDate);
    final displayDate = currentDateStr != null
        ? DateTime.parse(currentDateStr)
        : end;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '当前日期（用于计算日均）',
                style: TextStyle(
                  fontSize: 12,
                  color: appTheme.earthMedium.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '生活费日均 = 生活支出 ÷ ${_stage!.livingDays}天',
                style: TextStyle(
                  fontSize: 11,
                  color: appTheme.earthMedium.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () async {
            final initialDate = currentDateStr != null
                ? DateTime.parse(currentDateStr)
                : end;
            final picked = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: start,
              lastDate: end,
            );
            if (picked != null) {
              setState(() {
                _stage = _stage!.copyWith(
                  currentDate:
                      '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
                );
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: appTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${displayDate.month.toString().padLeft(2, '0')}.${displayDate.day.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: appTheme.primary,
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
          if (_additionFormExpanded)
            _buildAdditionForm(appTheme)
          else
            GestureDetector(
              onTap: () => setState(() => _additionFormExpanded = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: appTheme.sage.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    '+ 添加追加',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
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
            ReorderableListView(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _expenses.removeAt(oldIndex);
                  _expenses.insert(newIndex, item);
                });
                _service.updateExpensesOrder(_expenses);
              },
              children: [
                for (int i = 0; i < _expenses.length; i++)
                  _buildExpenseItem(appTheme, _expenses[i], index: i),
              ],
            ),
          const SizedBox(height: 8),
          if (_expenseFormExpanded)
            _buildExpenseForm(appTheme)
          else
            GestureDetector(
              onTap: () => setState(() => _expenseFormExpanded = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: appTheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    '+ 添加支出',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildExpenseItem(AppThemeExtension appTheme, ExpenseRecord expense, {int? index}) {
    final icon = expense.category == 'shopping'
        ? Icons.shopping_bag_outlined
        : Icons.category_outlined;
    final color = expense.category == 'shopping'
        ? appTheme.sage
        : appTheme.roseLight;

    return InkWell(
      key: ValueKey(expense.id),
      onTap: () => _showEditExpenseSheet(appTheme, expense),
      borderRadius: BorderRadius.circular(14),
      child: Container(
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
            Icon(
              Icons.drag_handle_rounded,
              color: appTheme.earthMedium.withValues(alpha: 0.4),
              size: 18,
            ),
            const SizedBox(width: 8),
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
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _deleteExpense(expense),
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

  Future<void> _showEditExpenseSheet(AppThemeExtension appTheme, ExpenseRecord expense) async {
    String category = expense.category;
    final amountController = TextEditingController(text: expense.amount.toStringAsFixed(2));
    final descController = TextEditingController(text: expense.description);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sheetTheme = Theme.of(ctx).appTheme;
        return StatefulBuilder(
          builder: (ctx, setLocal) => Container(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
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
                      '编辑支出',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: sheetTheme.earth,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Icon(Icons.close_rounded,
                          size: 20, color: sheetTheme.earthMedium.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 分类选择
                Text('分类', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sheetTheme.earthMedium)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildCategoryChip(
                      appTheme: sheetTheme,
                      label: '购物',
                      icon: Icons.shopping_bag_outlined,
                      isSelected: category == 'shopping',
                      color: sheetTheme.sage,
                      onTap: () => setLocal(() => category = 'shopping'),
                    ),
                    const SizedBox(width: 10),
                    _buildCategoryChip(
                      appTheme: sheetTheme,
                      label: '其他',
                      icon: Icons.category_outlined,
                      isSelected: category == 'other',
                      color: sheetTheme.roseLight,
                      onTap: () => setLocal(() => category = 'other'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // 金额
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: sheetTheme.earthMedium.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: sheetTheme.earthMedium.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  style: TextStyle(fontSize: 14, color: sheetTheme.earth),
                ),
                const SizedBox(height: 16),
                // 保存按钮
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () async {
                      final amount = double.tryParse(amountController.text);
                      final desc = descController.text.trim();
                      if (amount == null || amount <= 0 || desc.isEmpty) return;
                      await _service.updateExpense(
                        expense.id!,
                        category: category,
                        amount: amount,
                        description: desc,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _loadData();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: sheetTheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '保存修改',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 8 : 0),
              ],
            ),
          ),
        );
      },
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

  void _submitExpense() {
    final amount = double.tryParse(_expenseAmountController.text);
    final description = _expenseDescriptionController.text.trim();
    if (amount == null || amount <= 0 || description.isEmpty) return;

    _service.addExpense(
      widget.stageId,
      _expenseCategory,
      amount,
      description,
    ).then((_) {
      _expenseAmountController.clear();
      _expenseDescriptionController.clear();
      _expenseCategory = 'shopping';
      _loadData();
      // 保持展开状态，不清空
    });
  }

  Widget _buildAdditionForm(AppThemeExtension appTheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appTheme.creamDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 原因输入
          TextField(
            controller: _additionReasonController,
            decoration: InputDecoration(
              hintText: '追加原因（必填）',
              hintStyle: TextStyle(
                fontSize: 13,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: appTheme.earthMedium.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            style: TextStyle(fontSize: 13, color: appTheme.earth),
          ),
          const SizedBox(height: 10),
          // 金额输入
          TextField(
            controller: _additionAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: '追加金额',
              hintStyle: TextStyle(
                fontSize: 13,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: appTheme.earthMedium.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            style: TextStyle(fontSize: 13, color: appTheme.earth),
          ),
          const SizedBox(height: 10),
          // 操作按钮行
          Row(
            children: [
              // 收起按钮
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _additionFormExpanded = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: appTheme.creamDark,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '收起',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: appTheme.earthMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 确认添加按钮
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _submitAddition,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: appTheme.sage,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '确认添加',
                        style: TextStyle(
                          fontSize: 14,
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
          SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 8 : 0),
        ],
      ),
    );
  }

  Widget _buildExpenseForm(AppThemeExtension appTheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appTheme.creamDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分类选择
          Row(
            children: [
              _buildCategoryChip(
                appTheme: appTheme,
                label: '购物',
                icon: Icons.shopping_bag_outlined,
                isSelected: _expenseCategory == 'shopping',
                color: appTheme.sage,
                onTap: () => setState(() => _expenseCategory = 'shopping'),
              ),
              const SizedBox(width: 10),
              _buildCategoryChip(
                appTheme: appTheme,
                label: '其他',
                icon: Icons.category_outlined,
                isSelected: _expenseCategory == 'other',
                color: appTheme.roseLight,
                onTap: () => setState(() => _expenseCategory = 'other'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 金额输入
          TextField(
            controller: _expenseAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: '金额',
              hintStyle: TextStyle(
                fontSize: 13,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: appTheme.earthMedium.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            style: TextStyle(fontSize: 13, color: appTheme.earth),
          ),
          const SizedBox(height: 10),
          // 描述输入
          TextField(
            controller: _expenseDescriptionController,
            decoration: InputDecoration(
              hintText: '描述（如：超市采购）',
              hintStyle: TextStyle(
                fontSize: 13,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: appTheme.earthMedium.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            style: TextStyle(fontSize: 13, color: appTheme.earth),
          ),
          const SizedBox(height: 10),
          // 操作按钮行
          Row(
            children: [
              // 收起按钮
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _expenseFormExpanded = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: appTheme.creamDark,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '收起',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: appTheme.earthMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 确认添加按钮
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _submitExpense,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: appTheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '确认添加',
                        style: TextStyle(
                          fontSize: 14,
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
          SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 8 : 0),
        ],
      ),
    );
  }
}
