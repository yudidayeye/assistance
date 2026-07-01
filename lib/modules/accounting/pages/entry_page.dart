import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../services/transaction_service.dart';
import '../services/category_service.dart';
import '../widgets/transaction_item.dart';
import '../../../shared/widgets/month_selector.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/utils/date_utils.dart';
import '../../../core/theme/theme_extension.dart';

/// 记账模块主页 — 柔和风格
class AccountingEntryPage extends StatefulWidget {
  const AccountingEntryPage({super.key});

  @override
  State<AccountingEntryPage> createState() => _AccountingEntryPageState();
}

class _AccountingEntryPageState extends State<AccountingEntryPage> {
  DateTime _selectedMonth = DateTime.now();
  List<Transaction> _transactions = [];
  Map<String, Category> _categoryCache = {};
  double _monthExpense = 0;
  double _monthIncome = 0;
  bool _loading = true;
  int _loadVersion = 0; // 5.4: 异步竞态防护

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final version = ++_loadVersion;
    setState(() => _loading = true);

    final cats = await CategoryService.instance.getAllCategories();
    final txns = await TransactionService.instance
        .getTransactionsByMonth(_selectedMonth);
    final expense =
        await TransactionService.instance.getMonthExpenseTotal(_selectedMonth);
    final income =
        await TransactionService.instance.getMonthIncomeTotal(_selectedMonth);

    final cache = <String, Category>{};
    for (final c in cats) {
      cache[c.id] = c;
    }

    if (!mounted || version != _loadVersion) return;
    setState(() {
      _categoryCache = cache;
      _transactions = txns;
      _monthExpense = expense;
      _monthIncome = income;
      _loading = false;
    });
  }

  void _onMonthChanged(DateTime month) {
    setState(() => _selectedMonth = month);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;

    return Scaffold(
      backgroundColor: appTheme.cream,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 头部区域
          SliverToBoxAdapter(
            child: _buildHeader(context, appTheme),
          ),

          // 月份选择器
          SliverToBoxAdapter(
            child: MonthSelector(
              selectedMonth: _selectedMonth,
              onMonthChanged: _onMonthChanged,
            ),
          ),

          // 月度摘要卡片
          SliverToBoxAdapter(
            child: _buildSummaryCard(context, appTheme),
          ),

          // 交易列表
          _loading
              ? SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: appTheme.primary,
                    ),
                  ),
                )
              : _transactions.isEmpty
                  ? SliverFillRemaining(
                      child: _buildEmptyState(appTheme),
                    )
                  : _buildTransactionSliver(appTheme),
        ],
      ),
      floatingActionButton: _buildFAB(context, appTheme),
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
                    color: appTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(appTheme.radiusMd),
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
                '记账',
                style: TextStyle(
                  fontFamily: GoogleFonts.dmSans().fontFamily,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: appTheme.earth,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),

          // 操作按钮
          Row(
            children: [
              _buildHeaderButton(
                context,
                appTheme,
                icon: Icons.bar_chart_rounded,
                onTap: () => context.push('/accounting/stats'),
              ),
              const SizedBox(width: 10),
              _buildHeaderButton(
                context,
                appTheme,
                icon: Icons.settings_outlined,
                onTap: () => context.push('/accounting/categories'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton(
    BuildContext context,
    AppThemeExtension appTheme, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: appTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(appTheme.radiusMd),
        ),
        child: Icon(
          icon,
          color: appTheme.earthMedium,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, AppThemeExtension appTheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusLg),
        boxShadow: appTheme.cardShadow,
      ),
      child: Column(
        children: [
          // 支出
          Column(
            children: [
              Text(
                '本月支出',
                style: TextStyle(
                  fontSize: 13,
                  color: appTheme.earthMedium,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                FormatUtils.formatAmount(_monthExpense),
                style: TextStyle(
                  fontFamily: GoogleFonts.dmSans().fontFamily,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: appTheme.earth,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),

          // 分隔线
          Container(
            margin: const EdgeInsets.symmetric(vertical: 20),
            height: 1,
            color: appTheme.earthMedium.withValues(alpha: 0.12),
          ),

          // 收入和结余
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  appTheme,
                  label: '收入',
                  amount: _monthIncome,
                  color: appTheme.sage,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: appTheme.earthMedium.withValues(alpha: 0.12),
              ),
              Expanded(
                child: _buildSummaryItem(
                  appTheme,
                  label: '结余',
                  amount: _monthIncome - _monthExpense,
                  color: _monthIncome - _monthExpense >= 0
                      ? appTheme.sage
                      : appTheme.rose,
                  isBalance: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    AppThemeExtension appTheme, {
    required String label,
    required double amount,
    required Color color,
    bool isBalance = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: appTheme.earthMedium,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isBalance
              ? FormatUtils.formatBalance(amount)
              : FormatUtils.formatAmount(amount),
          style: TextStyle(
            fontFamily: GoogleFonts.dmSans().fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(AppThemeExtension appTheme) {
    return EmptyStateWidget(
      icon: Icons.receipt_long_outlined,
      title: '暂无记录',
      subtitle: '点击下方按钮开始记账',
      iconColor: appTheme.primary,
    );
  }

  Widget _buildTransactionSliver(AppThemeExtension appTheme) {
    // 按日期分组
    final Map<String, List<Transaction>> grouped = {};
    for (final t in _transactions) {
      final dateStr = AppDateUtils.formatFullDate(t.date);
      grouped.putIfAbsent(dateStr, () => []).add(t);
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final dateStr = grouped.keys.elementAt(index);
          final dayTxns = grouped[dateStr]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 日期标题
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  children: [
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 13,
                        color: appTheme.earthMedium,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _getDayTotal(dayTxns),
                      style: TextStyle(
                        fontSize: 12,
                        color: appTheme.earthMedium.withAlpha(180),
                      ),
                    ),
                  ],
                ),
              ),

              // 交易项
              ...dayTxns.map((t) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TransactionItem(
                      transaction: t,
                      category: _categoryCache[t.categoryId],
                      onChanged: _loadData,
                    ),
                  )),

              // 分隔线
              if (index < grouped.length - 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Divider(
                    color: appTheme.earthMedium.withAlpha(20),
                    height: 1,
                  ),
                ),
            ],
          );
        },
        childCount: grouped.length,
      ),
    );
  }

  Widget _buildFAB(BuildContext context, AppThemeExtension appTheme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            appTheme.primary,
            appTheme.primaryDark,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: appTheme.primary.withAlpha(80),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () async {
          final result = await context.push<bool>('/accounting/add');
          if (result == true) _loadData();
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  String _getDayTotal(List<Transaction> dayTxns) {
    final expense = dayTxns
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount);
    final income = dayTxns
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);

    if (expense > 0 && income > 0) {
      return '支出 ${FormatUtils.formatAmount(expense)} · 收入 ${FormatUtils.formatAmount(income)}';
    }
    if (expense > 0) return '支出 ${FormatUtils.formatAmount(expense)}';
    return '收入 ${FormatUtils.formatAmount(income)}';
  }
}
