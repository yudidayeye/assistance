import 'package:flutter/material.dart';
import '../../../shared/foundation/app_spacing.dart';
import '../../../core/theme/theme_extension.dart';

/// 历史记录筛选栏 — 标签选择器风格
class HistoryFilterBar extends StatelessWidget {
  final int? selectedYear;
  final int? selectedMonth;
  final int? selectedStage;
  final List<int> availableYears;
  final List<int> availableMonths;
  final List<int> availableStages;
  final ValueChanged<int?> onYearChanged;
  final ValueChanged<int?> onMonthChanged;
  final ValueChanged<int?> onStageChanged;

  const HistoryFilterBar({
    super.key,
    this.selectedYear,
    this.selectedMonth,
    this.selectedStage,
    required this.availableYears,
    required this.availableMonths,
    required this.availableStages,
    required this.onYearChanged,
    required this.onMonthChanged,
    required this.onStageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // 年份筛选
          _buildChipRow(
            appTheme: appTheme,
            label: '年份',
            items: availableYears.map((year) => _FilterChipItem(
              value: year,
              label: '$year年',
            )).toList(),
            selectedValue: selectedYear,
            onChanged: onYearChanged,
          ),
          AppSpacing.h8,
          // 月份筛选（仅选中年份时显示）
          if (selectedYear != null)
            _buildChipRow(
              appTheme: appTheme,
              label: '月份',
              items: availableMonths.map((month) => _FilterChipItem(
                value: month,
                label: '$month月',
              )).toList(),
              selectedValue: selectedMonth,
              onChanged: onMonthChanged,
            ),
          // 阶段筛选（仅在选中月份时显示）
          if (selectedMonth != null) ...[
            AppSpacing.h8,
            _buildChipRow(
              appTheme: appTheme,
              label: '阶段',
              items: availableStages.map((stage) => _FilterChipItem(
                value: stage,
                label: '第$stage阶段',
              )).toList(),
              selectedValue: selectedStage,
              onChanged: onStageChanged,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChipRow({
    required AppThemeExtension appTheme,
    required String label,
    required List<_FilterChipItem> items,
    required int? selectedValue,
    required ValueChanged<int?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 标签文字
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: appTheme.earthMedium,
              ),
            ),
          ),
          AppSpacing.w8,
          // 标签列表
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // "全部"标签
                  _buildChip(
                    appTheme: appTheme,
                    label: '全部',
                    isSelected: selectedValue == null,
                    onTap: () => onChanged(null),
                  ),
                  AppSpacing.w4,
                  // 其他标签
                  ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _buildChip(
                      appTheme: appTheme,
                      label: item.label,
                      isSelected: selectedValue == item.value,
                      onTap: () => onChanged(item.value),
                    ),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required AppThemeExtension appTheme,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? appTheme.primary.withValues(alpha: 0.15)
              : appTheme.cream,
          borderRadius: BorderRadius.circular(appTheme.radiusLg),
          border: Border.all(
            color: isSelected
                ? appTheme.primary.withValues(alpha: 0.4)
                : appTheme.creamDark,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? appTheme.primary : appTheme.earthMedium,
          ),
        ),
      ),
    );
  }
}

class _FilterChipItem {
  final int value;
  final String label;

  const _FilterChipItem({
    required this.value,
    required this.label,
  });
}
