import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../shared/foundation/app_spacing.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../models/period_record.dart';
import '../models/stage_record.dart';
import '../models/addition_record.dart';
import '../models/expense_record.dart';
import '../services/period_book_service.dart';
import '../services/period_book_settings.dart';
import '../widgets/stage_card.dart';
import '../widgets/edit_balance_dialog.dart';
import '../widgets/period_summary_card.dart';

/// 当前周期详情页（入口页）
class PeriodDetailPage extends StatefulWidget {
  /// 指定周期 ID 时以只读模式展示（历史周期）
  final int? periodId;

  const PeriodDetailPage({super.key, this.periodId});

  @override
  State<PeriodDetailPage> createState() => _PeriodDetailPageState();
}

class _PeriodDetailPageState extends State<PeriodDetailPage> {
  final _service = PeriodBookService.instance;
  final ScrollController _scrollController = ScrollController();
  double? _savedScrollOffset;

  PeriodRecord? _period;
  PeriodCalculations? _calc;
  List<StageRecord> _stages = [];
  List<List<AdditionRecord>> _stageAdditions = [];
  List<ExpenseRecord> _allExpenses = [];
  double? _largeItemsNet;
  bool _loading = true;
  bool _hasAnyPeriods = false;
  int _payday = 10;

  bool get _isReadOnly => false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadPayday();
    _service.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onDataChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _loadData();
  }

  Future<void> _loadPayday() async {
    final payday = await PeriodBookSettings.instance.getPayday();
    if (mounted) {
      setState(() => _payday = payday);
    }
  }

  void _showPaydayPicker() {
    final appTheme = Theme.of(context).appTheme;
    showDialog(
      context: context,
      barrierColor: appTheme.surfaceOverlay,
      builder: (ctx) => AlertDialog(
        backgroundColor: appTheme.cream,
        icon: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: appTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(appTheme.radiusMd),
          ),
          child: Icon(Icons.calendar_month_rounded,
              color: appTheme.primary, size: 26),
        ),
        title: Text(
          '设置发薪日',
          style: AppTypography.displayMd.copyWith(
            color: appTheme.earth,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '每月几号发薪？（1~31）',
              style: AppTypography.bodyMd.copyWith(
                color: appTheme.earthMedium,
              ),
            ),
            AppSpacing.h24,
            _PaydayPicker(
              initialValue: _payday,
              onChanged: (value) {
                setState(() => _payday = value);
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
            onPressed: () async {
              await PeriodBookSettings.instance.setPayday(_payday);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              AppSnackBar.show(ctx, '发薪日已设置为每月$_payday号');
            },
            child: Text('确认', style: TextStyle(color: appTheme.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      if (widget.periodId != null) {
        _period = await _service.getPeriodById(widget.periodId!);
      } else {
        _period = await _service.getOngoingPeriod();
      }
      if (_period != null) {
        _calc = await _service.getPeriodCalculations(_period!.id!);
        _stages = await _service.getStagesByPeriod(_period!.id!);
        final allAdditions = await _service.getAdditionsByPeriod(_period!.id!);
        _allExpenses = await _service.getExpensesByPeriod(_period!.id!);

        _stageAdditions = _stages.map((stage) {
          return allAdditions.where((a) => a.stageId == stage.id!).toList();
        }).toList();

        _largeItemsNet = await _service.getLargeItemsNet(_period!.id!);
      } else {
        // 若无进行中周期，检查是否已有历史周期（用于空状态文案区分）
        final all = await _service.getAllPeriods();
        _hasAnyPeriods = all.isNotEmpty;
      }
    } catch (e) {
      debugPrint('PeriodDetailPage load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    // 整页 push（有返回键）时标题贴返回键；被固定嵌入主页（无返回键）时
    // 回落到与「工具箱」一致的默认左侧间距。
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    if (_loading) {
      return AppScaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: appTheme.primary,
          ),
        ),
      );
    }

    if (_period == null) {
      return AppScaffold(
        appBar: AppBar(
          backgroundColor: appTheme.cream,
          elevation: 0,
          centerTitle: false,
          titleSpacing: canPop ? 0 : null,
          automaticallyImplyLeading: true,
          title: Text(
            '周期详情',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: () => context.push('/period_book/history'),
                icon: const Icon(Icons.history_rounded),
                color: appTheme.earth,
                iconSize: 20,
              ),
            ),
          ],
        ),
        body: Center(
          child: EmptyStateWidget(
            icon: Icons.account_balance_wallet_outlined,
            title: _hasAnyPeriods ? '当前没有进行中的周期' : '还没有记账周期',
            subtitle: _hasAnyPeriods
                ? '新建一个周期开始记账，或查看历史记录'
                : '创建第一个周期，开始记录你的收支',
            actionLabel: '新建周期',
            onAction: () async {
              await context.push('/period_book/new');
              if (mounted) {
                _loadData();
              }
            },
          ),
        ),
      );
    }

    final start = DateTime.parse(_period!.startDate);
    final end = DateTime.parse(_period!.endDate);

    return AppScrollScaffold(
      controller: _scrollController,
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: appTheme.cream,
          elevation: 0,
          centerTitle: false,
          titleSpacing: canPop ? 0 : null,
          automaticallyImplyLeading: true,
          title: Text(
            '${start.month}月${start.day}日 ~ ${end.month}月${end.day}日',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                onPressed: () => context.push('/period_book/history'),
                icon: const Icon(Icons.history_rounded),
                color: appTheme.earth,
                iconSize: 20,
                tooltip: '历史记录',
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, size: 20, color: appTheme.earth),
              color: appTheme.cardBackground,
              position: PopupMenuPosition.under,
              onSelected: (value) {
                switch (value) {
                  case 'new_period':
                    context.push('/period_book/new');
                    break;
                  case 'edit_period':
                    context.push('/period_book/edit/${_period!.id}');
                    break;
                  
                  case 'payday':
                    _showPaydayPicker();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'new_period',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline_rounded, size: 18, color: appTheme.earth),
                      const SizedBox(width: 8),
                      const Text('新增周期'),
                    ],
                  ),
                ),
                if (!_isReadOnly)
                  PopupMenuItem(
                    value: 'edit_period',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18, color: appTheme.earth),
                        const SizedBox(width: 8),
                        const Text('编辑周期'),
                      ],
                    ),
                  ),

                PopupMenuItem(
                  value: 'payday',
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 18, color: appTheme.earth),
                      const SizedBox(width: 8),
                      const Text('发薪日设置'),
                    ],
                  ),
                ),
              ],
            ),
          ]
        ),
        SliverToBoxAdapter(child: _buildSummarySection(appTheme)),
        SliverToBoxAdapter(child: AppSpacing.h8),
        _buildStagesSection(appTheme),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildSummarySection(AppThemeExtension appTheme) {
    return PeriodSummaryCard(
      calc: _calc!,
      period: _period!,
      onTapTotalBase: _showTotalBaseDetail,
      onTapTotalExpense: _showTotalExpenseDetail,
      largeItemsNet: _largeItemsNet,
      onEditLargeItems: _isReadOnly ? null : () => _navigateToLargeItemsEdit(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 总本金详情浮层
  // ═══════════════════════════════════════════════════════════

  void _showTotalBaseDetail() {
    final appTheme = Theme.of(context).appTheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sheetTheme = Theme.of(ctx).appTheme;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: sheetTheme.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(sheetTheme.radiusXl)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 16),
                child: Text(
                  '总本金构成',
                  style: AppTypography.displayMd.copyWith(color: sheetTheme.earth),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  children: [
                    _buildDetailRow(
                      appTheme: appTheme,
                      label: '初始本金',
                      amount: _period!.baseAmount,
                      isTotal: false,
                    ),
                    const Divider(height: 24),
                    ..._stages.asMap().entries.map((entry) {
                      final index = entry.key;
                      final stage = entry.value;
                      final additions = _stageAdditions[index];
                      final total =
                          additions.fold<double>(0, (sum, a) => sum + a.amount);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            appTheme: appTheme,
                            label: '第${stage.sortOrder}阶段追加',
                            amount: total,
                            isTotal: false,
                            isEmpty: additions.isEmpty,
                          ),
                          if (additions.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            for (final a in additions)
                              Padding(
                                padding: const EdgeInsets.only(left: 16, bottom: 4),
                                child: Row(
                                  children: [
                                    Text(
                                      '└',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: appTheme.earthMedium
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    AppSpacing.w4,
                                    Expanded(
                                      child: Text(
                                        a.reason,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: appTheme.earthMedium
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '￥${a.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: appTheme.sage,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      );
                    }),
                    const Divider(height: 24),
                    _buildDetailRow(
                      appTheme: appTheme,
                      label: '合计',
                      amount: _calc!.totalBase,
                      isTotal: true,
                    ),
                    SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 总支出详情浮层
  // ═══════════════════════════════════════════════════════════

  void _showTotalExpenseDetail() {
    final appTheme = Theme.of(context).appTheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sheetTheme = Theme.of(ctx).appTheme;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: sheetTheme.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(sheetTheme.radiusXl)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 16),
                child: Text(
                  '总支出构成',
                  style: AppTypography.displayMd.copyWith(color: sheetTheme.earth),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  children: [
                    _buildDetailRow(
                      appTheme: appTheme,
                      label: '购物',
                      amount: _calc!.shoppingTotal,
                      color: appTheme.rose,
                      isTotal: false,
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      appTheme: appTheme,
                      label: '其他',
                      amount: _calc!.otherTotal,
                      color: appTheme.rose,
                      isTotal: false,
                    ),
                    const Divider(height: 24),
                    if (_calc!.livingTotal != null &&
                        _calc!.livingTotal! > 0) ...[
                      _buildDetailRow(
                        appTheme: appTheme,
                        label: '生活',
                        amount: _calc!.livingTotal!,
                        color: appTheme.rose,
                        isTotal: false,
                      ),
                      const Divider(height: 24),
                    ],
                    _buildDetailRow(
                      appTheme: appTheme,
                      label: '合计',
                      amount: _calc!.totalBase - (_calc?.balance ?? 0),
                      color: appTheme.rose,
                      isTotal: true,
                    ),
                    SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToLargeItemsEdit() async {
    if (_period == null) return;
    await context.push('/period_book/large_items/${_period!.id}');
    if (mounted) {
      _loadData();
    }
  }

  Widget _buildDetailRow({
    required AppThemeExtension appTheme,
    required String label,
    required double amount,
    required bool isTotal,
    Color? color,
    bool isEmpty = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 15 : 14,
                fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
                color: isTotal ? appTheme.earth : appTheme.earthMedium,
              ),
            ),
          ),
          if (isEmpty)
            Text(
              '￥0.00',
              style: TextStyle(
                fontSize: isTotal ? 16 : 14,
                fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
                color: appTheme.earthMedium.withValues(alpha: 0.4),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            )
          else
            Text(
              '￥${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: isTotal ? 16 : 14,
                fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
                color: color ?? (isTotal ? appTheme.primary : appTheme.earth),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 阶段列表
  // ═══════════════════════════════════════════════════════════

  Widget _buildStagesSection(AppThemeExtension appTheme) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final stage = _stages[index];
            final stageCalc = _calc!.stages[index];
            final additions = _stageAdditions[index];

            double previousBalance;
            if (index == 0) {
              previousBalance = _period!.baseAmount;
            } else {
              previousBalance = _calc!.stages[index - 1].balance ??
                  (_calc!.stages[index - 1].baseAmount -
                      _calc!.stages[index - 1].shoppingTotal -
                      _calc!.stages[index - 1].otherTotal);
            }

            return StageCard(
              stage: stage,
              stageCalc: stageCalc,
              previousBalance: previousBalance,
              additions: additions,
              personalExpenseBreakdown:
                  stage.id != null ? _computePersonalBreakdown(stage.id!) : null,
              onEditBalance:
                  _isReadOnly ? null : () => _showEditStageBalanceDialog(stage),
              onEdit: _isReadOnly
                  ? null
                  : () async {
                      await context.push('/period_book/stage_edit/${stage.id}');
                      if (mounted) {
                        _loadData();
                      }
                    },
            );
          },
          childCount: _stages.length,
        ),
      ),
    );
  }

  Map<String, double> _computePersonalBreakdown(int stageId) {
    final stageExpenses = _allExpenses
        .where((e) => e.stageId == stageId && !e.isOther)
        .toList();
    final map = <String, double>{};
    for (final e in stageExpenses) {
      final display = _categoryDisplayName(e.category);
      map[display] = (map[display] ?? 0) + e.amount;
    }
    // 加入杂项（漏记杂项 livingTotal）
    final stageIndex = _stages.indexWhere((s) => s.id == stageId);
    if (stageIndex >= 0 && _calc != null) {
      final living = _calc!.stages[stageIndex].livingTotal ?? 0;
      if (living > 0) {
        map['杂项'] = (map['杂项'] ?? 0) + living;
      }
    }
    return map;
  }

  String _categoryDisplayName(String? dbValue) {
    const map = {
      'shopping': '购物',
      'other': '其他',
      '生活': '生活',
      
      '工作': '工作',
      '娱乐': '娱乐',
      '大餐': '大餐',
    };
    return dbValue != null && map.containsKey(dbValue) ? map[dbValue]! : (dbValue ?? '其他');
  }

  // ═══════════════════════════════════════════════════════════
  // 弹窗：编辑阶段余额
  // ═══════════════════════════════════════════════════════════

  void _showEditStageBalanceDialog(StageRecord stage) {
    final stageIndex = _stages.indexWhere((s) => s.id == stage.id);
    final stageCalc = stageIndex >= 0 ? _calc!.stages[stageIndex] : null;
    final maxBalance = stageCalc?.baseAmount ?? 0;

    EditBalanceDialog.show(
      context: context,
      currentBalance: stage.balance,
      maxBalance: maxBalance,
      onSave: (val) async {
        await _service.updateStageBalance(stage.id!, val);
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
      },
    );
  }
}

/// 发薪日选择器 — 数字滚轮
class _PaydayPicker extends StatefulWidget {
  final int initialValue;
  final ValueChanged<int> onChanged;

  const _PaydayPicker({
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_PaydayPicker> createState() => _PaydayPickerState();
}

class _PaydayPickerState extends State<_PaydayPicker> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            if (_value > 1) {
              setState(() {
                _value--;
                widget.onChanged(_value);
              });
            }
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: appTheme.creamDark,
              borderRadius: BorderRadius.circular(appTheme.radiusMd),
            ),
            child: Icon(Icons.remove_rounded,
                color: _value > 1
                    ? appTheme.earth
                    : appTheme.earthMedium.withValues(alpha: 0.3),
                size: 22),
          ),
        ),
        AppSpacing.w20,
        Text(
          '$_value',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: appTheme.earth,
          ),
        ),
        AppSpacing.w20,
        GestureDetector(
          onTap: () {
            if (_value < 31) {
              setState(() {
                _value++;
                widget.onChanged(_value);
              });
            }
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: appTheme.creamDark,
              borderRadius: BorderRadius.circular(appTheme.radiusMd),
            ),
            child: Icon(Icons.add_rounded,
                color: _value < 31
                    ? appTheme.earth
                    : appTheme.earthMedium.withValues(alpha: 0.3),
                size: 22),
          ),
        ),
      ],
    );
  }
}



