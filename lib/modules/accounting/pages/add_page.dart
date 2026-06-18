import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../services/transaction_service.dart';
import '../services/category_service.dart';
import '../widgets/category_grid.dart';
import '../widgets/amount_input.dart';
import '../../../shared/widgets/number_keyboard.dart';
import '../../../core/theme/theme_extension.dart';

/// 快速记账页 — 奢华自然主义风格
class AddTransactionPage extends StatefulWidget {
  final String? editId;

  const AddTransactionPage({super.key, this.editId});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage>
    with SingleTickerProviderStateMixin {
  TransactionType _type = TransactionType.expense;
  String? _selectedCategoryId;
  String _amountText = '';
  String _note = '';
  DateTime _selectedDate = DateTime.now();
  List<Category> _categories = [];
  late AnimationController _typeController;
  late Animation<double> _typeScaleAnim;

  @override
  void initState() {
    super.initState();
    _typeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _typeScaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _typeController,
      curve: Curves.easeInOut,
    ));

    _loadCategories();
    if (widget.editId != null) {
      _loadExistingTransaction();
    }
  }

  @override
  void dispose() {
    _typeController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final cats = await CategoryService.instance.getCategories(_type);
    if (mounted) setState(() => _categories = cats);
  }

  Future<void> _loadExistingTransaction() async {
    final txn = await TransactionService.instance.getTransaction(widget.editId!);
    if (txn != null && mounted) {
      setState(() {
        _type = txn.type;
        _selectedCategoryId = txn.categoryId;
        _amountText = txn.amount == txn.amount.truncateToDouble()
            ? txn.amount.truncate().toString()
            : txn.amount.toStringAsFixed(2);
        _note = txn.note ?? '';
        _selectedDate = txn.date;
      });
      await _loadCategories();
    }
  }

  void _switchType(TransactionType type) {
    _typeController.forward().then((_) {
      _typeController.reverse();
    });

    setState(() {
      _type = type;
      _selectedCategoryId = null;
    });
    _loadCategories();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).appTheme.gold,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (_selectedCategoryId == null || _amountText.isEmpty) {
      _showSnackBar('请选择分类并输入金额', isError: true);
      return;
    }

    final amount = double.tryParse(_amountText) ?? 0;
    if (amount <= 0) return;

    final now = DateTime.now();

    if (widget.editId != null) {
      final existing =
          await TransactionService.instance.getTransaction(widget.editId!);
      if (existing != null) {
        await TransactionService.instance.updateTransaction(
          existing.copyWith(
            type: _type,
            categoryId: _selectedCategoryId!,
            amount: amount,
            note: _note.isEmpty ? null : _note,
            date: _selectedDate,
            updatedAt: now,
          ),
        );
      }
    } else {
      await TransactionService.instance.insertTransaction(
        Transaction(
          id: const Uuid().v4(),
          type: _type,
          categoryId: _selectedCategoryId!,
          amount: amount,
          note: _note.isEmpty ? null : _note,
          date: _selectedDate,
          createdAt: now,
        ),
      );
    }

    if (!context.mounted) return;

    _showSnackBar(widget.editId != null ? '已更新' : '已保存');

    if (widget.editId == null) {
      setState(() {
        _amountText = '';
        _note = '';
        _selectedDate = DateTime.now();
      });
    } else {
      context.pop();
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final appTheme = Theme.of(context).appTheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: isError ? Colors.white : appTheme.earth,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: isError ? appTheme.rose : appTheme.goldLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;
    final accentColor =
        _type == TransactionType.expense ? appTheme.rose : appTheme.sage;

    return Scaffold(
      backgroundColor: appTheme.cream,
      body: Column(
        children: [
          // 头部区域
          _buildHeader(context, appTheme),

          // 类型切换
          _buildTypeSwitcher(context, appTheme),

          // 金额显示 + 日期选择
          AmountInput(
            amountText: _amountText,
            type: _type,
            selectedDate: _selectedDate,
            onDateTap: _pickDate,
          ),

          // 分类网格（可滚动）
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 分类标题
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '选择分类',
                      style: TextStyle(
                        fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: appTheme.earth,
                      ),
                    ),
                  ),

                  // 分类网格
                  CategoryGrid(
                    type: _type,
                    categories: _categories,
                    selectedCategoryId: _selectedCategoryId,
                    onCategorySelected: (cat) =>
                        setState(() => _selectedCategoryId = cat.id),
                  ),

                  const SizedBox(height: 20),

                  // 备注输入
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: appTheme.earthMedium.withAlpha(30),
                      ),
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: '添加备注...',
                        hintStyle: TextStyle(
                          color: appTheme.earthMedium.withAlpha(120),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        prefixIcon: Icon(
                          Icons.edit_note_rounded,
                          color: appTheme.earthMedium.withAlpha(100),
                        ),
                      ),
                      style: TextStyle(
                        color: appTheme.earth,
                        fontSize: 15,
                      ),
                      onChanged: (v) => _note = v,
                      controller: TextEditingController(text: _note),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // 数字键盘 + 保存按钮
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: appTheme.earth.withAlpha(10),
                  blurRadius: 20,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NumberKeyboard(
                    currentValue: _amountText,
                    onValueChanged: (v) => setState(() => _amountText = v),
                    onDone: _save,
                    doneText: widget.editId != null ? '更新' : '保存',
                    doneColor: accentColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppThemeExtension appTheme) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.of(context).padding.top + 16, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 返回按钮和标题
          Row(
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: appTheme.creamDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: appTheme.earthMedium.withAlpha(30),
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: appTheme.earthMedium,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                widget.editId != null ? '编辑账目' : '记一笔',
                style: TextStyle(
                  fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: appTheme.earth,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),

          // 删除按钮（编辑模式）
          if (widget.editId != null)
            GestureDetector(
              onTap: () async {
                await TransactionService.instance
                    .deleteTransaction(widget.editId!);
                if (context.mounted) context.pop();
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: appTheme.rose.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: appTheme.rose,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeSwitcher(
      BuildContext context, AppThemeExtension appTheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: appTheme.creamDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: appTheme.earthMedium.withAlpha(20),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildTypeButton(
                appTheme,
                TransactionType.expense,
                '支出',
                appTheme.rose,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildTypeButton(
                appTheme,
                TransactionType.income,
                '收入',
                appTheme.sage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton(
    AppThemeExtension appTheme,
    TransactionType type,
    String label,
    Color color,
  ) {
    final isSelected = _type == type;

    return GestureDetector(
      onTap: () => _switchType(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: color.withAlpha(60))
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? color : appTheme.earthMedium,
            ),
          ),
        ),
      ),
    );
  }
}
