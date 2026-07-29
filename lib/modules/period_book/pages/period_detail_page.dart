import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../shared/foundation/app_spacing.dart';
import '../models/period_record.dart';
import '../models/stage_record.dart';
import '../models/addition_record.dart';
import '../models/expense_record.dart';
import '../services/period_book_service.dart';
import '../widgets/stage_card.dart';
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

  bool get _isReadOnly => false;

  @override
  void initState() {
    super.initState();
    _loadData();
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
      }
    } catch (e) {
      debugPrint('PeriodDetailPage load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

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
          automaticallyImplyLeading: true,
          title: Text(
            '周期详情',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: EmptyStateWidget(
                icon: Icons.account_balance_wallet_outlined,
                title: '还没有记账周期',
                subtitle: '创建第一个周期，开始记录你的收支',
                actionLabel: '新建周期',
                onAction: () async {
                  await context.push('/period_book/new');
                  if (mounted) {
                    _loadData();
                  }
                },
              ),
            ),
          ],
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
          automaticallyImplyLeading: true,
          title: Text(
            '${start.month}月${start.day}日 ~ ${end.month}月${end.day}日',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
          ),
          actions: [
            if (!_isReadOnly) ...[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: () => context.push('/period_book/history'),
                  icon: const Icon(Icons.history_rounded),
                  color: appTheme.earth,
                  iconSize: 20,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: () => context.push('/period_book/edit/${_period!.id}'),
                  icon: const Icon(Icons.edit_outlined),
                  color: appTheme.earth,
                  iconSize: 20,
                ),
              ),
            ],
          ],
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
                            label: '第${stage.sortOrder}周追加',
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
                                      '¥${a.amount.toStringAsFixed(2)}',
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
              '¥0.00',
              style: TextStyle(
                fontFamily: GoogleFonts.dmSans().fontFamily,
                fontSize: isTotal ? 16 : 14,
                fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
                color: appTheme.earthMedium.withValues(alpha: 0.4),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            )
          else
            Text(
              '¥${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontFamily: GoogleFonts.dmSans().fontFamily,
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
        .where((e) => e.stageId == stageId && e.category != 'other')
        .toList();
    final map = <String, double>{};
    for (final e in stageExpenses) {
      final display = _categoryDisplayName(e.category);
      map[display] = (map[display] ?? 0) + e.amount;
    }
    return map;
  }

  String _categoryDisplayName(String? dbValue) {
    const map = {
      'shopping': '购物',
      '生活': '生活',
      '购物': '购物',
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
    final appTheme = Theme.of(context).appTheme;
    final currentBalanceText = stage.balance?.toStringAsFixed(2);
    final controller = TextEditingController();

    final stageIndex = _stages.indexWhere((s) => s.id == stage.id);
    final stageCalc = stageIndex >= 0 ? _calc!.stages[stageIndex] : null;
    final maxBalance = stageCalc?.baseAmount ?? 0;

    showDialog(
      context: context,
      barrierColor: appTheme.surfaceOverlay,
      builder: (ctx) => AlertDialog(
        backgroundColor: appTheme.cream,
        title: Text(
          '编辑余额',
          style: TextStyle(
            fontFamily: GoogleFonts.playfairDisplay().fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: appTheme.earth,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最大余额: ¥${maxBalance.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 13,
                color: appTheme.earthMedium.withValues(alpha: 0.6),
              ),
            ),
            AppSpacing.h12,
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: TextStyle(
                fontFamily: GoogleFonts.dmSans().fontFamily,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: appTheme.earth,
              ),
              decoration: InputDecoration(
                prefixText: '¥ ',
                prefixStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: appTheme.earthMedium.withValues(alpha: 0.6),
                ),
                hintText: currentBalanceText ?? '未设置',
                hintStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: appTheme.earthMedium.withValues(alpha: 0.4),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(appTheme.radiusMd),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
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
              final val = double.tryParse(controller.text.trim());
              if (val != null && val > maxBalance) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('余额不能超过本金 ¥${maxBalance.toStringAsFixed(2)}'),
                    backgroundColor: appTheme.rose,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(appTheme.radiusSm),
                    ),
                  ),
                );
                return;
              }
              await _service.updateStageBalance(
                stage.id!,
                val,
              );
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
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Text('确定', style: TextStyle(color: appTheme.primary)),
          ),
        ],
      ),
    );
  }
}
