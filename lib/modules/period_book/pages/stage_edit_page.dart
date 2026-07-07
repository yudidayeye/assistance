import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extension.dart';
import '../models/period_record.dart';
import '../models/stage_record.dart';
import '../models/addition_record.dart';
import '../models/expense_record.dart';
import '../services/period_book_service.dart';

/// 阶段批量编辑页
class StageEditPage extends StatefulWidget {
  final int periodId;

  const StageEditPage({super.key, required this.periodId});

  @override
  State<StageEditPage> createState() => _StageEditPageState();
}

class _StageEditPageState extends State<StageEditPage> {
  final _service = PeriodBookService.instance;

  PeriodRecord? _period;
  List<StageRecord> _stages = [];
  List<List<AdditionRecord>> _stageAdditions = [];
  List<List<ExpenseRecord>> _stageExpenses = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _period = await _service.getPeriodById(widget.periodId);
      _stages = await _service.getStagesByPeriod(widget.periodId);

      _stageAdditions = [];
      _stageExpenses = [];
      for (final stage in _stages) {
        final additions = await _service.getAdditionsByStage(stage.id!);
        final expenses = await _service.getExpensesByStage(stage.id!);
        _stageAdditions.add(additions);
        _stageExpenses.add(expenses);
      }
    } catch (e) {
      debugPrint('Load data error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // 保存所有修改到数据库
      for (int i = 0; i < _stages.length; i++) {
        final stage = _stages[i];
        await _service.updateStage(stage.id!, {
          'start_date': stage.startDate,
          'end_date': stage.endDate,
          'sort_order': i + 1,
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
                    ..._stages.asMap().entries.map((entry) {
                      final index = entry.key;
                      return _buildStageSection(appTheme, index);
                    }),
                    const SizedBox(height: 16),
                    _buildAddStageButton(appTheme),
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
            '阶段管理',
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

  Widget _buildStageSection(AppThemeExtension appTheme, int index) {
    final stage = _stages[index];
    final additions = _stageAdditions[index];
    final expenses = _stageExpenses[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // 阶段标题
          Row(
            children: [
              Text(
                '第${stage.sortOrder}阶段',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: appTheme.earth,
                ),
              ),
              const Spacer(),
              if (_stages.length > 1)
                GestureDetector(
                  onTap: () => _showDeleteStageDialog(index),
                  child: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: appTheme.rose,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // 日期编辑
          _buildDateRow(
            appTheme: appTheme,
            label: '开始日期',
            date: DateTime.parse(stage.startDate),
            onDateChanged: (date) {
              setState(() {
                _stages[index] = stage.copyWith(
                  startDate: '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                );
              });
            },
          ),
          const SizedBox(height: 12),
          _buildDateRow(
            appTheme: appTheme,
            label: '结束日期',
            date: DateTime.parse(stage.endDate),
            onDateChanged: (date) {
              setState(() {
                _stages[index] = stage.copyWith(
                  endDate: '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                );
              });
            },
          ),
          const SizedBox(height: 12),
          _buildDateRow(
            appTheme: appTheme,
            label: '当前时间',
            date: DateTime.parse(stage.endDate), // TODO: 添加 current_date 字段
            onDateChanged: (date) {
              // TODO: 更新当前时间
            },
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          // 追加记录
          Text(
            '追加记录',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: appTheme.earth,
            ),
          ),
          const SizedBox(height: 8),
          _buildAdditionsTable(appTheme, index, additions),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _showAddAdditionDialog(index),
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
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          // 支出明细
          Text(
            '支出明细',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: appTheme.earth,
            ),
          ),
          const SizedBox(height: 8),
          _buildExpensesTable(appTheme, index, expenses),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _showAddExpenseDialog(index),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: appTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '+ 添加支出',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: appTheme.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          // 余额编辑
          _buildBalanceRow(appTheme, index, stage),
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

  Widget _buildAdditionsTable(
    AppThemeExtension appTheme,
    int stageIndex,
    List<AdditionRecord> additions,
  ) {
    if (additions.isEmpty) {
      return Text(
        '暂无追加记录',
        style: TextStyle(
          fontSize: 12,
          color: appTheme.earthMedium.withValues(alpha: 0.5),
        ),
      );
    }

    return Column(
      children: additions.map((addition) {
        final index = additions.indexOf(addition);
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: index > 0
                ? Border(
                    top: BorderSide(
                      color: appTheme.earthMedium.withValues(alpha: 0.1),
                      width: 0.5,
                    ),
                  )
                : null,
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
                onTap: () {
                  setState(() {
                    _stageAdditions[stageIndex].removeAt(index);
                  });
                },
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: appTheme.earthMedium.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExpensesTable(
    AppThemeExtension appTheme,
    int stageIndex,
    List<ExpenseRecord> expenses,
  ) {
    if (expenses.isEmpty) {
      return Text(
        '暂无支出记录',
        style: TextStyle(
          fontSize: 12,
          color: appTheme.earthMedium.withValues(alpha: 0.5),
        ),
      );
    }

    return Column(
      children: expenses.map((expense) {
        final index = expenses.indexOf(expense);
        final icon = expense.category == 'shopping'
            ? Icons.shopping_bag_outlined
            : Icons.category_outlined;
        final color = expense.category == 'shopping'
            ? appTheme.sage
            : appTheme.roseLight;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: index > 0
                ? Border(
                    top: BorderSide(
                      color: appTheme.earthMedium.withValues(alpha: 0.1),
                      width: 0.5,
                    ),
                  )
                : null,
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
                onTap: () {
                  setState(() {
                    _stageExpenses[stageIndex].removeAt(index);
                  });
                },
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: appTheme.earthMedium.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBalanceRow(
    AppThemeExtension appTheme,
    int index,
    StageRecord stage,
  ) {
    return Row(
      children: [
        Text(
          '余额',
          style: TextStyle(
            fontSize: 13,
            color: appTheme.earthMedium,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {
            // TODO: 显示编辑余额对话框
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
                  stage.balance != null
                      ? '¥${stage.balance!.toStringAsFixed(2)}'
                      : '未设置',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: stage.balance != null
                        ? appTheme.earth
                        : appTheme.earthMedium.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.edit,
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

  Widget _buildAddStageButton(AppThemeExtension appTheme) {
    return GestureDetector(
      onTap: () {
        // TODO: 添加新阶段
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: appTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: appTheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            '+ 添加阶段',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: appTheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton(AppThemeExtension appTheme) {
    return GestureDetector(
      onTap: _saving ? null : _save,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [appTheme.primary, appTheme.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(appTheme.radiusMd),
          boxShadow: [
            BoxShadow(
              color: appTheme.primary.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
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
                  '保存所有修改',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }

  void _showDeleteStageDialog(int index) {
    final appTheme = Theme.of(context).appTheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: appTheme.cream,
        title: Text(
          '删除阶段',
          style: TextStyle(
            fontFamily: GoogleFonts.playfairDisplay().fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: appTheme.earth,
          ),
        ),
        content: Text(
          '确定要删除第${_stages[index].sortOrder}阶段吗？阶段内的所有支出和追加记录将一并删除。',
          style: TextStyle(
            fontSize: 14,
            color: appTheme.earthMedium,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              '取消',
              style: TextStyle(color: appTheme.earthMedium),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _stages.removeAt(index);
                _stageAdditions.removeAt(index);
                _stageExpenses.removeAt(index);
              });
              Navigator.pop(ctx);
            },
            child: Text(
              '删除',
              style: TextStyle(color: appTheme.rose),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddAdditionDialog(int stageIndex) {
    // TODO: 实现添加追加对话框
  }

  void _showAddExpenseDialog(int stageIndex) {
    // TODO: 实现添加支出对话框
  }
}
