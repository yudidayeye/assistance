import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../shared/foundation/app_spacing.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/utils/format_utils.dart';
import 'expense_category_helper.dart';

/// 历史记录与阶段详情共用的分类占比图、图例和选中提示。
class ExpenseCategoryBreakdown extends StatelessWidget {
  final Map<String, double> data;
  final String? selectedCategory;
  final ValueChanged<String?>? onCategorySelected;
  final EdgeInsetsGeometry padding;

  const ExpenseCategoryBreakdown(
      {super.key,
      required this.data,
      this.selectedCategory,
      this.onCategorySelected,
      this.padding = AppSpacing.pageH});

  static const double _pieBaseRadius = 40;
  static const double _pieSelectedRadius = _pieBaseRadius + 6;

  @override
  Widget build(BuildContext context) =>
      _buildExpensePie(Theme.of(context).appTheme);

  /// 分类显示顺序和颜色映射
  static const _categoryOrder = [
    '购物',
    '生活',
    '工作',
    '娱乐',
    '大餐',
    '杂项',
    '其他',
    'balance'
  ];

  Color _categoryColor(String key, AppThemeExtension appTheme) {
    switch (key) {
      case '购物':
        return const Color(0xFF8B7EC8).withValues(alpha: 0.72);
      case '生活':
        return appTheme.sage.withValues(alpha: 0.72);
      case '工作':
        return const Color(0xFF3E6FA0).withValues(alpha: 0.72);
      case '娱乐':
        return const Color(0xFFE88D67).withValues(alpha: 0.72);
      case '大餐':
        return appTheme.rose.withValues(alpha: 0.72);
      case '杂项':
        return const Color(0xFFD4A76A).withValues(alpha: 0.72);
      case '其他':
        return const Color(0xFF4DB6AC).withValues(alpha: 0.72);
      default:
        return appTheme.earthMedium.withValues(alpha: 0.72);
    }
  }

  String _categoryLabel(String key) {
    return key == 'balance' ? '杂项' : key;
  }

  /// 分类显示名在扇区数组中的下标；未筛选或该分类当前无金额时为 null
  int? _indexOfCategory(
      List<MapEntry<String, double>> entries, String? category) {
    if (category == null) return null;
    for (var i = 0; i < entries.length; i++) {
      if (_categoryLabel(entries[i].key) == category) return i;
    }
    return null;
  }

  /// 派发一次点击意图。与当前选中项一致时不派发，避免页面侧无谓重建；
  /// 取消（传 null）与选中走的是同一条路径（契约 C1-4 / C1-5 / C1-6）
  void _dispatchCategory(String? category) {
    if (category == selectedCategory) return;
    onCategorySelected?.call(category);
  }

  /// 构建支出占比图
  Widget _buildExpensePie(AppThemeExtension appTheme) {
    // 选中阶段时使用阶段维度的数据，否则使用全局汇总

    // 筛选有数据的分类（排除 balance），按金额从大到小排序
    final entries = _categoryOrder
        .where((k) => k != 'balance' && (data[k] ?? 0) > 0)
        .map((k) => MapEntry(k, data[k]!))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return _buildEmptyState(appTheme, '暂无支出数据');
    }

    final total = entries.fold(0.0, (sum, e) => sum + e.value);
    // 选中项的定位每次都按分类名重算：排序、范围、阶段任一变化都会换掉下标
    final selectedIndex = _indexOfCategory(entries, selectedCategory);

    return Padding(
      padding: padding,
      child: Row(
        children: [
          // 饼图
          Expanded(
            flex: 4,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: PieChart(
                    PieChartData(
                      sections: entries.asMap().entries.map((indexed) {
                        final pct =
                            total > 0 ? indexed.value.value / total : 0.0;
                        return _buildPieSection(
                          value: indexed.value.value,
                          color: _categoryColor(indexed.value.key, appTheme),
                          title: _categoryLabel(indexed.value.key),
                          pct: pct,
                          isSelected: indexed.key == selectedIndex,
                        );
                      }).toList(),
                      centerSpaceRadius: 28,
                      sectionsSpace: 2,
                      startDegreeOffset: -90,
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          // 只响应点击事件，忽略悬浮（契约 C1-8）
                          if (event is! FlTapDownEvent) return;
                          final touched = pieTouchResponse?.touchedSection;
                          if (touched == null) {
                            // 点中扇区之外的空白 = 取消（契约 C1-6）
                            _dispatchCategory(null);
                            return;
                          }
                          final index = touched.touchedSectionIndex;
                          if (index < 0 || index >= entries.length) {
                            _dispatchCategory(null);
                            return;
                          }
                          final label = _categoryLabel(entries[index].key);
                          // 再点当前分类则取消，点其他分类则直接替换（FR-003 / FR-004）
                          _dispatchCategory(
                              label == selectedCategory ? null : label);
                        },
                      ),
                    ),
                  ),
                ),
                if (selectedIndex != null)
                  Positioned(
                    bottom: -8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _buildPieTooltip(
                        appTheme,
                        _categoryLabel(entries[selectedIndex].key),
                        entries[selectedIndex].value,
                        total > 0 ? entries[selectedIndex].value / total : 0,
                        _categoryColor(entries[selectedIndex].key, appTheme),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          AppSpacing.w16,
          // 图例
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: entries.asMap().entries.map((indexed) {
                final e = indexed.value;
                final pct = total > 0 ? e.value / total : 0.0;
                final label = _categoryLabel(e.key);
                return _buildLegend(
                  appTheme: appTheme,
                  label: label,
                  color: _categoryColor(e.key, appTheme),
                  value: e.value,
                  pct: pct,
                  isSelected: indexed.key == selectedIndex,
                  // 图例与扇区派发同一个回调，两者完全等价（FR-001）
                  onTap: () => _dispatchCategory(
                    label == selectedCategory ? null : label,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(AppThemeExtension appTheme, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 32,
              color: appTheme.earthMedium.withValues(alpha: 0.3),
            ),
            AppSpacing.h8,
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PieChartSectionData _buildPieSection({
    required double value,
    required Color color,
    required String title,
    required double pct,
    bool isSelected = false,
  }) {
    final icon = ExpenseCategoryHelper.categoryIcon(title);
    final showBadge = icon != null && pct >= 0.05;
    return PieChartSectionData(
      value: value > 0 ? value : 0.001,
      // 选中扇区半径外扩；其余扇区半径不变、MUST NOT 淡化（FR-006 / 契约 C1-3）
      radius: isSelected ? _pieSelectedRadius : _pieBaseRadius,
      color: color,
      title: '',

      badgeWidget: showBadge
          ? Container(
              padding: EdgeInsets.all(isSelected ? 3 : 2),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                // 占比极小的分类没有徽标，选中态此时全靠半径外扩表达
                border:
                    isSelected ? Border.all(color: color, width: 1.5) : null,
              ),
              child: Icon(
                icon,
                size: isSelected ? 12 : 10,
                color: color,
              ),
            )
          : null,
      badgePositionPercentageOffset: 0.65,
    );
  }

  Widget _buildPieTooltip(
    AppThemeExtension appTheme,
    String label,
    double amount,
    double pct,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusSm),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$label ${(pct * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: appTheme.earth,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '¥${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend({
    required AppThemeExtension appTheme,
    required String label,
    required Color color,
    required double value,
    required double pct,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final icon = ExpenseCategoryHelper.categoryIcon(label);
    return GestureDetector(
      key: ValueKey('expense-category-$label'),
      onTap: onTap,
      // 点击区域即整行，不依赖图标的命中范围
      behavior: HitTestBehavior.opaque,
      child: Container(
        // 紧凑图例保持整行可点击，选中背景随行高收紧。
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          // 选中态用整行底色表达，与扇区的半径外扩不同形（契约 C1-2）。
          // 未选中行保持透明，MUST NOT 淡化（契约 C1-3）
          color: isSelected
              ? appTheme.primaryLight.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(appTheme.radiusSm),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: color),
                AppSpacing.w6,
              ],
              Text(
                label,
                style: AppTypography.bodySm.copyWith(color: appTheme.earth),
              ),
              AppSpacing.w4,
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  color: appTheme.earth,
                ),
              ),
              AppSpacing.w8,
              Text(
                FormatUtils.formatAmount(value),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
