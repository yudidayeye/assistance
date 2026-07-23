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
  bool _shoppingFormExpanded = false;
  bool _otherFormExpanded = false;

  // Tab 切换（0=追加记录, 1=购物支出, 2=其他支出）
  int _currentTabIndex = 0;
  final _additionReasonController = TextEditingController();
  final _additionAmountController = TextEditingController();
  final _shoppingDescController = TextEditingController();
  final _shoppingAmountController = TextEditingController();
  final _otherDescController = TextEditingController();
  final _otherAmountController = TextEditingController();

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
              borderRadius: BorderRadius.circular(10),
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
                _stage = _stage!.copyWith(startDate: _formatDate(date));
              });
              _saveStageDates();
            },
          ),
          const SizedBox(height: 12),
          _buildDateRow(
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
        Text(
          '当前日期',
          style: TextStyle(
            fontSize: 13,
            color: appTheme.earthMedium,
          ),
        ),
        const Spacer(),
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
                _stage = _stage!.copyWith(currentDate: _formatDate(picked));
              });
              _saveStageDates();
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '追加记录',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
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
          const SizedBox(height: 12),
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

  // ═══════════════════════════════════════════════════════════
  // 统一记录卡片（Tab 切换集成在卡片内）
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
          // Tab 头部（集成在卡片内）
          _buildCardTabBar(appTheme),
          // 内容区域
          _buildTabContent(appTheme),
        ],
      ),
    );
  }

  Widget _buildCardTabBar(AppThemeExtension appTheme) {
    const tabs = [
      {'label': '追加记录', 'colorKey': 'sage'},
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

  // ═══════════════════════════════════════════════════════════
  // Tab 内容
  // ═══════════════════════════════════════════════════════════

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

  Widget _buildAdditionItem(AppThemeExtension appTheme, AdditionRecord addition) {
    return InkWell(
      key: ValueKey('addition_${addition.id}'),
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
      ),
    );
  }

  Future<void> _showEditAdditionSheet(AppThemeExtension appTheme, AdditionRecord addition) async {
    final reasonController = TextEditingController(text: addition.reason);
    final amountController = TextEditingController(text: addition.amount.toStringAsFixed(2));

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
                // 追加金额
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 8 : 0),
                // 确定按钮
                GestureDetector(
                  onTap: () {
                    // 先保存一次确保最新数据写入
                    _saveAdditionEdit(addition, reasonController, amountController);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: sheetTheme.sage,
                      borderRadius: BorderRadius.circular(12),
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
  // 购物支出卡片
  // ═══════════════════════════════════════════════════════════

  Widget _buildShoppingSection(AppThemeExtension appTheme) {
    final shoppingExpenses = _expenses.where((e) => e.category == 'shopping').toList();
    final shoppingTotal = shoppingExpenses.fold(0.0, (sum, e) => sum + e.amount);

    return Container(
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
                amount: shoppingTotal,
                color: appTheme.rose,
                prefix: '-¥',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (shoppingExpenses.isEmpty)
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
                  final item = shoppingExpenses.removeAt(oldIndex);
                  shoppingExpenses.insert(newIndex, item);
                  _expenses = [
                    ..._expenses.where((e) => e.category == 'shopping')
                        .toList()..clear()
                      ..addAll(shoppingExpenses),
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
          const SizedBox(height: 8),
          if (_shoppingFormExpanded)
            _buildShoppingForm(appTheme)
          else
            GestureDetector(
              onTap: () => setState(() => _shoppingFormExpanded = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: appTheme.rose.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 其他支出卡片
  // ═══════════════════════════════════════════════════════════

  Widget _buildOtherSection(AppThemeExtension appTheme) {
    final otherExpenses = _expenses.where((e) => e.category == 'other').toList();
    final otherTotal = otherExpenses.fold(0.0, (sum, e) => sum + e.amount);

    return Container(
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
                amount: otherTotal,
                color: appTheme.rose,
                prefix: '-¥',
              ),
            ],
          ),
          const SizedBox(height: 12),
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
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = otherExpenses.removeAt(oldIndex);
                  otherExpenses.insert(newIndex, item);
                  _expenses = [
                    ..._expenses.where((e) => e.category == 'shopping'),
                    ..._expenses.where((e) => e.category == 'other')
                        .toList()..clear()
                      ..addAll(otherExpenses),
                  ];
                });
                _service.updateExpensesOrder(_expenses);
              },
              children: [
                for (int i = 0; i < otherExpenses.length; i++)
                  _buildExpenseItem(appTheme, otherExpenses[i], index: i),
              ],
            ),
          const SizedBox(height: 8),
          if (_otherFormExpanded)
            _buildOtherForm(appTheme)
          else
            GestureDetector(
              onTap: () => setState(() => _otherFormExpanded = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: appTheme.rose.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
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
          const SizedBox(height: 8),
        ],
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
                    _service.addExpense(widget.stageId, 'shopping', amount, desc).then((_) {
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
                    _service.addExpense(widget.stageId, 'other', amount, desc).then((_) {
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
        ],
      ),
    );
  }

  Widget _buildExpenseItem(AppThemeExtension appTheme, ExpenseRecord expense, {int? index}) {
    final icon = expense.category == 'shopping'
        ? Icons.shopping_bag_outlined
        : Icons.category_outlined;
    // 支出统一红色语义（购物/其他类别仍由图标形状区分）
    final color = appTheme.rose;

    return InkWell(
      key: ValueKey('expense_${expense.id}'),
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
              '-¥${expense.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: appTheme.rose,
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

  Future<void> _showEditExpenseSheet(AppThemeExtension appTheme, ExpenseRecord expense) async {
    final amountController = TextEditingController(text: expense.amount.toStringAsFixed(2));
    final descController = TextEditingController(text: expense.description);
    final isShopping = expense.category == 'shopping';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sheetTheme = Theme.of(ctx).appTheme;
        return Container(
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
                    '编辑${isShopping ? "购物" : "其他"}支出',
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
                SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 8 : 0),
                // 确定按钮
                GestureDetector(
                  onTap: () {
                    _saveExpenseEdit(expense, expense.category, amountController, descController);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: sheetTheme.primary,
                      borderRadius: BorderRadius.circular(12),
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
              ],
            ),
          );
        },
    );
    // 编辑已实时保存，关闭弹窗后刷新列表
    if (mounted) await _loadData();
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          // 原因输入
          TextField(
            controller: _additionReasonController,
            decoration: InputDecoration(
              hintText: '追加原因',
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
}
