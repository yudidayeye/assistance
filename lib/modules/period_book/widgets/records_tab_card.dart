import 'package:flutter/material.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/foundation/app_spacing.dart';
import '../../../shared/widgets/app_segmented_tab.dart';

/// 记录分组 Tab 卡片（阶段编辑页与大额记录编辑页共用）
///
/// Tab 顺序固定为「个人支出 → 其他支出 → 追加记录」，
/// 内部自管理选中状态，各页面只需传入三个分区内容。
/// 需要外部控制时（如阶段详情页随饼图切换 tab），可传 [selectedIndex]
/// + [onSelectedIndexChanged] 进入受控模式。
class RecordsTabCard extends StatefulWidget {
  /// 追加记录 Tab 标签（阶段页为「追加记录」，大额页为「大额追加」）
  final String additionLabel;

  /// 个人支出分区
  final Widget personalSection;

  /// 其他支出分区
  final Widget otherSection;

  /// 追加记录分区
  final Widget additionSection;

  /// 受控模式的当前选中索引；不传则使用内部状态
  final int? selectedIndex;

  /// 受控模式下点击 Tab 时的回调
  final ValueChanged<int>? onSelectedIndexChanged;

  const RecordsTabCard({
    super.key,
    required this.additionLabel,
    required this.personalSection,
    required this.otherSection,
    required this.additionSection,
    this.selectedIndex,
    this.onSelectedIndexChanged,
  });

  @override
  State<RecordsTabCard> createState() => _RecordsTabCardState();
}

class _RecordsTabCardState extends State<RecordsTabCard> {
  // Tab 切换（0=个人支出, 1=其他支出, 2=追加记录）
  int _currentTabIndex = 0;

  /// 生效的选中索引：受控模式取外部值，否则用内部状态
  int get _index => widget.selectedIndex ?? _currentTabIndex;

  void _handleTabChanged(int index) {
    if (widget.selectedIndex != null) {
      widget.onSelectedIndexChanged?.call(index);
    } else {
      setState(() => _currentTabIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSegmentedTab(
          items: [
            const AppSegmentedTabItem(label: '个人支出'),
            const AppSegmentedTabItem(label: '其他支出'),
            AppSegmentedTabItem(label: widget.additionLabel),
          ],
          selectedIndex: _index,
          onChanged: _handleTabChanged,
        ),
        AppSpacing.h12,
        Container(
          decoration: BoxDecoration(
            color: appTheme.cardBackground,
            borderRadius: BorderRadius.circular(appTheme.radiusMd),
            border: Border.all(color: appTheme.cardBorder, width: 1),
          ),
          child: switch (_index) {
            0 => widget.personalSection,
            1 => widget.otherSection,
            _ => widget.additionSection,
          },
        ),
      ],
    );
  }
}
