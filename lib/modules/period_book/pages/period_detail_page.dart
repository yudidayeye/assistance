import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../models/period_record.dart';
import '../models/stage_record.dart';
import '../models/addition_record.dart';
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

  PeriodRecord? _period;
  PeriodCalculations? _calc;
  List<StageRecord> _stages = [];
  List<List<AdditionRecord>> _stageAdditions = [];
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

  // 设计稿颜色
  static const Color _bgColor = Color(0xFFF5F5F5);
  static const Color _darkText = Color(0xFF333333);
  static const Color _subText = Color(0xFF999999);
  static const Color _btnBg = Color(0xFFE8E8E8);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_period == null) {
      return Scaffold(
        backgroundColor: _bgColor,
        body: Column(
          children: [
            _buildEmptyHeader(),
            Expanded(
              child: EmptyStateWidget(
                icon: Icons.account_balance_wallet_outlined,
                title: '还没有记账周期',
                subtitle: '创建第一个周期，开始记录你的收支',
                actionLabel: '新建周期',
                onAction: () async {
                  await context.push('/period_book/new');
                  if (mounted) _loadData();
                },
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: const SizedBox(height: 8)),
                SliverToBoxAdapter(child: _buildSummarySection()),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(child: _buildSectionTitle('阶段明细')),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                _buildStagesSection(),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 空状态头部
  // ═══════════════════════════════════════════════════════════

  Widget _buildEmptyHeader() {
    final safeTop = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, safeTop + 10, 16, 12),
      child: SizedBox(
        height: 44,
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
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: _darkText, size: 22),
              ),
            ),
            const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 头部 — 无居中大标题，仅日期行
  // ═══════════════════════════════════════════════════════════

  Widget _buildHeader() {
    final safeTop = MediaQuery.of(context).padding.top;
    final start = DateTime.parse(_period!.startDate);
    final end = DateTime.parse(_period!.endDate);
    final days = _period!.totalDays;
    final dateLabel =
        '${start.month}月${start.day}日 – ${end.month}月${end.day}日';

    return Padding(
      padding: EdgeInsets.fromLTRB(16, safeTop + 10, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 筛选 + 标题行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.tune_rounded,
                      color: _darkText, size: 22),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        dateLabel,
                        style: TextStyle(
                          fontFamily: GoogleFonts.dmSans().fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _darkText,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          size: 16, color: _subText),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '共 $days 天',
                    style: TextStyle(
                      fontSize: 12,
                      color: _subText,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => context.push('/period_book/history'),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: _btnBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.calendar_today_rounded,
                          color: _darkText, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () =>
                        context.push('/period_book/edit/${_period!.id}'),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: _btnBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.more_horiz,
                          color: _darkText, size: 22),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 区域标题
  // ═══════════════════════════════════════════════════════════

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: _darkText,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 汇总卡片
  // ═════════════════════════════════════════════════════════

  Widget _buildSummarySection() {
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
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
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
                '总本金构成',
                style: TextStyle(
                  fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: appTheme.earth,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 24),
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
                    final total = additions.fold<double>(
                        0, (sum, a) => sum + a.amount);

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
                          ...additions.map((a) => Padding(
                                padding: const EdgeInsets.only(
                                    left: 16, bottom: 4),
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
                                    const SizedBox(width: 4),
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
                              )),
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
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 总支出详情浮层
  // ═══════════════════════════════════════════════════════════

  void _showTotalExpenseDetail() {
    final appTheme = Theme.of(context).appTheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
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
                '总支出构成',
                style: TextStyle(
                  fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: appTheme.earth,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 24),
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
      ),
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
                color: color ??
                    (isTotal ? appTheme.primary : appTheme.earth),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 阶段列表
  // ══════════════════════════════════════════════════════════

  Widget _buildStagesSection() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final stage = _stages[index];
            final stageCalc = _calc!.stages[index];

            return StageCard(
              stage: stage,
              stageCalc: stageCalc,
              service: _service,
              onTap: _isReadOnly ? null : () async {
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
}
