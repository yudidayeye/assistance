import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extension.dart';
import '../models/stage_record.dart';
import '../models/addition_record.dart';
import '../services/period_book_service.dart';

/// 阶段卡片组件 — 纯汇总展示，当前阶段（今日所在区间）边框强调
class StageCard extends StatelessWidget {
  final StageRecord stage;
  final StageCalculations stageCalc;
  final double previousBalance;
  final List<AdditionRecord> additions;
  final VoidCallback? onEditBalance;
  final VoidCallback? onEdit;

  const StageCard({
    super.key,
    required this.stage,
    required this.stageCalc,
    required this.previousBalance,
    required this.additions,
    this.onEditBalance,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    final start = DateTime.parse(stage.startDate);
    final end = DateTime.parse(stage.endDate);

    // 判断是否为当前阶段（今天落在 [start, end] 区间内）
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    final isCurrentStage =
        today.difference(startDate).inDays >= 0 &&
        endDate.difference(today).inDays >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: appTheme.cardShadow,
        border: Border.all(
          color: isCurrentStage ? appTheme.primary : appTheme.cardBorder,
          width: isCurrentStage ? 1.5 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：阶段序号 + 标题 + 进行中徽章 + 右边箭头（整行可点）
          GestureDetector(
            onTap: onEdit,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  // 阶段序号
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          appTheme.primary.withValues(alpha: 0.15),
                          appTheme.primary.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${stage.sortOrder}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: appTheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 阶段标题 + 时间
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          '第${stage.sortOrder}阶段',
                          style: TextStyle(
                            fontFamily: GoogleFonts.dmSans().fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: appTheme.earth,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${start.month}.${start.day.toString().padLeft(2, '0')} ~ ${end.month}.${end.day.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: appTheme.earthMedium.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 进行中徽章
                  if (isCurrentStage) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: appTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '进行中',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: appTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // 右边箭头
                  if (onEdit != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: appTheme.earthMedium.withValues(alpha: 0.4),
                    ),
                ],
              ),
            ),
          ),
          // 简要信息
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              children: [
                // 本金行：上阶段余额（+追加金额=真实本金）
                Row(
                  children: [
                    Text(
                      '本金',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: appTheme.earthMedium.withValues(alpha: 0.7),
                      ),
                    ),
                    const Spacer(),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: GoogleFonts.dmSans().fontFamily,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: appTheme.earth,
                        ),
                        children: [
                          if (stageCalc.additionsTotal > 0) ...[
                            TextSpan(text: '¥${previousBalance.toStringAsFixed(2)}'),
                            TextSpan(
                              text: '+¥${stageCalc.additionsTotal.toStringAsFixed(2)}',
                              style: TextStyle(color: appTheme.sage),
                            ),
                            TextSpan(text: '=¥${(previousBalance + stageCalc.additionsTotal).toStringAsFixed(2)}'),
                          ] else
                            TextSpan(text: '¥${previousBalance.toStringAsFixed(2)}'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // 购物支出
                Row(
                  children: [
                    Text(
                      '购物',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: appTheme.earthMedium.withValues(alpha: 0.7),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '-¥${stageCalc.shoppingTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: GoogleFonts.dmSans().fontFamily,
                        color: appTheme.rose,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // 其他支出
                Row(
                  children: [
                    Text(
                      '其他',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: appTheme.earthMedium.withValues(alpha: 0.7),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '-¥${stageCalc.otherTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: GoogleFonts.dmSans().fontFamily,
                        color: appTheme.rose,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '生活',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: appTheme.earthMedium.withValues(alpha: 0.7),
                      ),
                    ),
                    const Spacer(),
                    if (stageCalc.livingTotal != null && stageCalc.livingDailyAvg != null)
                      Text(
                        '-¥${stageCalc.livingDailyAvg!.abs().toStringAsFixed(2)}/天 * ${stage.livingDays}天 = -¥${stageCalc.livingTotal!.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: GoogleFonts.dmSans().fontFamily,
                          color: appTheme.rose,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      )
                    else
                      Text(
                        '-¥0.00',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: GoogleFonts.dmSans().fontFamily,
                          color: appTheme.rose,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(
                  height: 10,
                  color: appTheme.earthMedium.withValues(alpha: 0.08),
                ),
                const SizedBox(height: 14),
                // 余额行：编辑按钮放在金额前面，点击金额和编辑按钮都触发编辑
                GestureDetector(
                  onTap: onEditBalance,
                  child: Row(
                    children: [
                      Text(
                        '余额',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: appTheme.earthMedium.withValues(alpha: 0.7),
                        ),
                      ),
                      const Spacer(),
                      if (onEditBalance != null) ...[
                        Icon(
                          Icons.create_outlined,
                          size: 16,
                          color: appTheme.primary.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        stageCalc.balance != null
                            ? '¥${stageCalc.balance!.toStringAsFixed(2)}'
                            : '¥0.00',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: GoogleFonts.dmSans().fontFamily,
                          color: stageCalc.balance != null ? appTheme.primary : appTheme.earthMedium.withValues(alpha: 0.4),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
