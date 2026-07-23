import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../../shared/utils/format_utils.dart';
import '../models/period_record.dart';
import '../models/large_addition_record.dart';
import '../models/large_expense_record.dart';
import '../services/period_book_service.dart';

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
  String _expenseCategory = 'shopping';

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
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
        final allExpenses = await _service.getLargeExpensesByPeriod(widget.periodId);
        _shoppingExpenses =
            allExpenses.where((e) => e.category == 'shopping').toList();
        _otherExpenses =
            allExpenses.where((e) => e.category == 'other').toList();
      }
    } catch (e) {
      debugPrint('Load large items error: $e');
    }
    if (mounted) setState(() => _loading = false);
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
                    _buildUnifiedCard(appTheme),
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
      padding: EdgeInsets.fromLTRB(16, safeTop + 10, 16, 12),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Center(
                child: Text(
                  '大额记录',
                  style: TextStyle(
                    fontFamily: GoogleFonts.dmSans().fontFamily,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: appTheme.earth,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.pop(),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          color: appTheme.earth, size: 22),
                    ),
                  ),
                  const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 统一记录卡片（Tab 切换）
  // ═══════════════════════════════════════════════════════════

  Widget _buildUnifiedCard(AppThemeExtension appTheme) {
    return Container(
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: appTheme.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTabBar(appTheme),
          _buildTabContent(appTheme),
        ],
      ),
    );
  }

  Widget _buildCardTabBar(AppThemeExtension appTheme) {
    const tabs = [
      {'label': '大额追加', 'colorKey': 'sage'},
      {'label': '购物支出', 'colorKey': 'rose'},
      {'label': '其他支出', 'colorKey': 'rose'},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: appTheme.creamDark.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border(
            bottom: BorderSide(
              color: appTheme.earthMedium.withValues(alpha: 0.06),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: List.generate(tabs.length, (index) {
            final isSelected = _currentTabIndex == index;
            final tab = tabs[index];
            final color = tab['colorKey'] == 'sage' ? appTheme.sage : appTheme.rose;

            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _currentTabIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? appTheme.cardBackground
                        : appTheme.creamDark.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? color : appTheme.earthMedium,
                    ),
                    child: Text(
                      tab['label'] as String,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '大额追加',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: appTheme.earth,
                ),
              ),
              const Spacer(),
              _buildTotalChip(
                appTheme: appTheme,
                amount: _additions.fold(0.0, (sum, a) => sum + a.amount),
                color: appTheme.sage,
                prefix: '+¥',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_additions.isEmpty)
            Center(
              child: Text(
                '暂无大额追加',
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
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _additions.removeAt(oldIndex);
                  _additions.insert(newIndex, item);
                });
                _service.updateLargeAdditionsOrder(_additions);
              },
              children: [
                for (final addition in _additions)
                  _buildAdditionItem(appTheme, addition),
              ],
            ),
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

  Widget _buildAdditionItem(AppThemeExtension appTheme, LargeAdditionRecord addition) {
    return InkWell(
      key: ValueKey('large_addition_${addition.id}'),
      onTap: () => _showEditAdditionSheet(appTheme, addition),
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
              '+${FormatUtils.formatAmount(addition.amount)}',
              style: TextStyle(
                fontFamily: GoogleFonts.dmSans().fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: appTheme.sage,
                fontFeatures: const [FontFeature.tabularFigures()],
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
      ),
    );
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
              fillColor: appTheme.cardBackground,
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
          TextField(
            controller: _additionReasonController,
            decoration: InputDecoration(
              hintText: '追加原因（必填）',
              hintStyle: TextStyle(
                fontSize: 13,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: appTheme.cardBackground,
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
          Row(
            children: [
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

  // ═══════════════════════════════════════════════════════════
  // 购物支出
  // ═══════════════════════════════════════════════════════════

  Widget _buildShoppingSection(AppThemeExtension appTheme) {
    final color = appTheme.rose;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '购物支出',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: appTheme.earth,
                ),
              ),
              const Spacer(),
              _buildTotalChip(
                appTheme: appTheme,
                amount: _shoppingExpenses.fold(0.0, (sum, e) => sum + e.amount),
                color: color,
                prefix: '-¥',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_shoppingExpenses.isEmpty)
            Center(
              child: Text(
                '暂无购物支出',
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
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _shoppingExpenses.removeAt(oldIndex);
                  _shoppingExpenses.insert(newIndex, item);
                });
                _updateShoppingExpensesOrder();
              },
              children: [
                for (final expense in _shoppingExpenses)
                  _buildExpenseItem(appTheme, expense, color: color),
              ],
            ),
          const SizedBox(height: 12),
          if (_shoppingFormExpanded)
            _buildShoppingForm(appTheme)
          else
            GestureDetector(
              onTap: () => setState(() => _shoppingFormExpanded = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: appTheme.rose.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '+ 添加支出',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: appTheme.rose,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 其他支出
  // ═══════════════════════════════════════════════════════════

  Widget _buildOtherSection(AppThemeExtension appTheme) {
    final color = appTheme.rose;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '其他支出',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: appTheme.earth,
                ),
              ),
              const Spacer(),
              _buildTotalChip(
                appTheme: appTheme,
                amount: _otherExpenses.fold(0.0, (sum, e) => sum + e.amount),
                color: color,
                prefix: '-¥',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_otherExpenses.isEmpty)
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
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _otherExpenses.removeAt(oldIndex);
                  _otherExpenses.insert(newIndex, item);
                });
                _updateOtherExpensesOrder();
              },
              children: [
                for (final expense in _otherExpenses)
                  _buildExpenseItem(appTheme, expense, color: color),
              ],
            ),
          const SizedBox(height: 12),
          if (_otherFormExpanded)
            _buildOtherForm(appTheme)
          else
            GestureDetector(
              onTap: () => setState(() => _otherFormExpanded = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: appTheme.rose.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '+ 添加支出',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: appTheme.rose,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 支出项（购物/其他共用）
  // ═══════════════════════════════════════════════════════════

  Widget _buildExpenseItem(AppThemeExtension appTheme, LargeExpenseRecord expense, {required Color color}) {
    final icon = expense.category == 'shopping'
        ? Icons.shopping_bag_outlined
        : Icons.category_outlined;

    return InkWell(
      key: ValueKey('large_expense_${expense.id}'),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '-${FormatUtils.formatAmount(expense.amount)}',
              style: TextStyle(
                fontFamily: GoogleFonts.dmSans().fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: appTheme.rose,
                fontFeatures: const [FontFeature.tabularFigures()],
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
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 购物支出内嵌表单
  // ═══════════════════════════════════════════════════════════

  Widget _buildShoppingForm(AppThemeExtension appTheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appTheme.creamDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _shoppingAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: '金额',
              hintStyle: TextStyle(
                fontSize: 13,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: appTheme.cardBackground,
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
          TextField(
            controller: _shoppingDescController,
            decoration: InputDecoration(
              hintText: '描述',
              hintStyle: TextStyle(
                fontSize: 13,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: appTheme.cardBackground,
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
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _shoppingFormExpanded = false),
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
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () {
                    final amount = double.tryParse(_shoppingAmountController.text);
                    final desc = _shoppingDescController.text.trim();
                    if (amount == null || amount <= 0 || desc.isEmpty) return;
                    _service.addLargeExpense(widget.periodId, 'shopping', amount, desc).then((_) {
                      _shoppingAmountController.clear();
                      _shoppingDescController.clear();
                      _loadData();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: appTheme.rose,
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

  // ═══════════════════════════════════════════════════════════
  // 其他支出内嵌表单
  // ═══════════════════════════════════════════════════════════

  Widget _buildOtherForm(AppThemeExtension appTheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appTheme.creamDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _otherAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: '金额',
              hintStyle: TextStyle(
                fontSize: 13,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: appTheme.cardBackground,
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
          TextField(
            controller: _otherDescController,
            decoration: InputDecoration(
              hintText: '描述',
              hintStyle: TextStyle(
                fontSize: 13,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: appTheme.cardBackground,
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
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _otherFormExpanded = false),
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
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () {
                    final amount = double.tryParse(_otherAmountController.text);
                    final desc = _otherDescController.text.trim();
                    if (amount == null || amount <= 0 || desc.isEmpty) return;
                    _service.addLargeExpense(widget.periodId, 'other', amount, desc).then((_) {
                      _otherAmountController.clear();
                      _otherDescController.clear();
                      _loadData();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: appTheme.rose,
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

  // ═══════════════════════════════════════════════════════════
  // 编辑弹窗
  // ═══════════════════════════════════════════════════════════

  Future<void> _showEditAdditionSheet(AppThemeExtension appTheme, LargeAdditionRecord addition) async {
    final amountController = TextEditingController(text: addition.amount.toStringAsFixed(2));
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
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Icon(Icons.close_rounded,
                          size: 20, color: sheetTheme.earthMedium.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () async {
                      final amount = double.tryParse(amountController.text);
                      final reason = reasonController.text.trim();
                      if (amount == null || amount <= 0 || reason.isEmpty) return;
                      await _service.updateLargeAddition(
                        addition.id!,
                        amount: amount,
                        reason: reason,
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

  Future<void> _showEditExpenseSheet(AppThemeExtension appTheme, LargeExpenseRecord expense) async {
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
                      color: sheetTheme.rose,
                      onTap: () => setLocal(() => category = 'other'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
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
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () async {
                      final amount = double.tryParse(amountController.text);
                      final desc = descController.text.trim();
                      if (amount == null || amount <= 0 || desc.isEmpty) return;
                      await _service.updateLargeExpense(
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

  // ═══════════════════════════════════════════════════════════
  // 金额徽章
  // ═══════════════════════════════════════════════════════════

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
          borderRadius: BorderRadius.circular(999),
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
  // 操作
  // ═══════════════════════════════════════════════════════════

  Future<void> _deleteAddition(LargeAdditionRecord addition) async {
    await _service.deleteLargeAddition(addition.id!);
    await _loadData();
  }

  Future<void> _deleteExpense(LargeExpenseRecord expense) async {
    await _service.deleteLargeExpense(expense.id!);
    await _loadData();
  }

  // ═══════════════════════════════════════════════════════════
  // 排序（按分类更新 sort_order）
  // ═══════════════════════════════════════════════════════════

  Future<void> _updateShoppingExpensesOrder() async {
    // 重新合并所有支出以保持全局 sort_order 一致
    final allExpenses = [
      ..._shoppingExpenses.map((e) => LargeExpenseRecord(
        id: e.id, periodId: e.periodId, category: e.category,
        amount: e.amount, description: e.description, sortOrder: 0, createdAt: e.createdAt,
      )),
      ..._otherExpenses.map((e) => LargeExpenseRecord(
        id: e.id, periodId: e.periodId, category: e.category,
        amount: e.amount, description: e.description, sortOrder: 0, createdAt: e.createdAt,
      )),
    ];
    for (var i = 0; i < allExpenses.length; i++) {
      await _service.updateLargeExpense(allExpenses[i].id!, sortOrder: i);
    }
  }

  Future<void> _updateOtherExpensesOrder() async {
    final allExpenses = [
      ..._shoppingExpenses.map((e) => LargeExpenseRecord(
        id: e.id, periodId: e.periodId, category: e.category,
        amount: e.amount, description: e.description, sortOrder: 0, createdAt: e.createdAt,
      )),
      ..._otherExpenses.map((e) => LargeExpenseRecord(
        id: e.id, periodId: e.periodId, category: e.category,
        amount: e.amount, description: e.description, sortOrder: 0, createdAt: e.createdAt,
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
      _loadData();
    });
  }

  void _submitShoppingExpense() {
    final amount = double.tryParse(_shoppingAmountController.text);
    final desc = _shoppingDescController.text.trim();
    if (amount == null || amount <= 0 || desc.isEmpty) return;

    _service.addLargeExpense(widget.periodId, 'shopping', amount, desc).then((_) {
      _shoppingAmountController.clear();
      _shoppingDescController.clear();
      _loadData();
    });
  }

  void _submitOtherExpense() {
    final amount = double.tryParse(_otherAmountController.text);
    final desc = _otherDescController.text.trim();
    if (amount == null || amount <= 0 || desc.isEmpty) return;

    _service.addLargeExpense(widget.periodId, 'other', amount, desc).then((_) {
      _otherAmountController.clear();
      _otherDescController.clear();
      _loadData();
    });
  }

}
