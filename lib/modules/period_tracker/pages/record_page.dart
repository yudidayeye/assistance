import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../models/period_record.dart';
import '../services/period_service.dart';
import '../../../shared/utils/date_utils.dart';
import '../../../core/theme/theme_extension.dart';

/// 记录经期页 — 奢华自然主义风格
class PeriodRecordPage extends StatefulWidget {
  const PeriodRecordPage({super.key});

  @override
  State<PeriodRecordPage> createState() => _PeriodRecordPageState();
}

class _PeriodRecordPageState extends State<PeriodRecordPage> {
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _endDateSelected = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;

    return Scaffold(
      backgroundColor: appTheme.cream,
      body: Column(
        children: [
          // 头部区域
          _buildHeader(context, appTheme),

          // 内容区域
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 开始日期
                  _buildSectionTitle(appTheme, '开始日期'),
                  const SizedBox(height: 12),
                  _buildDateSelector(
                    appTheme,
                    date: _startDate,
                    onTap: _selectStartDate,
                    isSelected: true,
                  ),
                  const SizedBox(height: 24),

                  // 结束日期
                  _buildSectionTitle(appTheme, '结束日期（可选）'),
                  const SizedBox(height: 8),
                  Text(
                    '经期还在进行中可不选',
                    style: TextStyle(
                      fontSize: 13,
                      color: appTheme.earthMedium,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDateSelector(
                    appTheme,
                    date: _endDate,
                    onTap: _selectEndDate,
                    isSelected: _endDateSelected,
                    placeholder: '未选择',
                  ),

                  // 提示信息
                  if (_endDateSelected &&
                      _endDate != null &&
                      _endDate!.difference(_startDate).inDays < 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: appTheme.rose.withAlpha(15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: appTheme.rose,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '结束日期不能早于开始日期',
                              style: TextStyle(
                                fontSize: 13,
                                color: appTheme.rose,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 40),

                  // 提示卡片
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: appTheme.gold.withAlpha(15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: appTheme.gold.withAlpha(30),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: appTheme.gold.withAlpha(30),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.lightbulb_outline_rounded,
                            color: appTheme.gold,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '小贴士',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: appTheme.earth,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '记录至少2-3个周期后，系统会为你提供更准确的预测。',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: appTheme.earthMedium,
                                  height: 1.4,
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
            ),
          ),

          // 保存按钮
          _buildSaveButton(appTheme),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppThemeExtension appTheme) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.of(context).padding.top + 16, 24, 16),
      child: Row(
        children: [
          // 返回按钮
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: appTheme.creamDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: appTheme.earthMedium.withAlpha(30),
                ),
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
            '记录经期',
            style: TextStyle(
              fontFamily: GoogleFonts.playfairDisplay().fontFamily,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: appTheme.earth,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(AppThemeExtension appTheme, String title) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: GoogleFonts.playfairDisplay().fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: appTheme.earth,
      ),
    );
  }

  Widget _buildDateSelector(
    AppThemeExtension appTheme, {
    required DateTime? date,
    required VoidCallback onTap,
    required bool isSelected,
    String? placeholder,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? appTheme.rose.withAlpha(60)
                : appTheme.earthMedium.withAlpha(30),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? appTheme.rose.withAlpha(20)
                    : appTheme.creamDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                color: isSelected ? appTheme.rose : appTheme.earthMedium,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                date != null
                    ? AppDateUtils.formatFullDate(date)
                    : placeholder ?? '请选择日期',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: date != null ? appTheme.earth : appTheme.earthMedium,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: appTheme.earthMedium.withAlpha(100),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(AppThemeExtension appTheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: appTheme.cream,
        boxShadow: [
          BoxShadow(
            color: appTheme.earth.withAlpha(10),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: _save,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                appTheme.rose,
                appTheme.rose.withAlpha(200),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: appTheme.rose.withAlpha(60),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '保存记录',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectStartDate() {
    final appTheme = Theme.of(context).appTheme;

    showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: appTheme.rose,
                ),
          ),
          child: child!,
        );
      },
    ).then((date) {
      if (date != null) setState(() => _startDate = date);
    });
  }

  void _selectEndDate() {
    final appTheme = Theme.of(context).appTheme;

    showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 4)),
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: appTheme.rose,
                ),
          ),
          child: child!,
        );
      },
    ).then((date) {
      if (date != null) {
        setState(() {
          _endDate = date;
          _endDateSelected = true;
        });
      }
    });
  }

  Future<void> _save() async {
    final appTheme = Theme.of(context).appTheme;

    final record = PeriodRecord(
      id: const Uuid().v4(),
      startDate: _startDate,
      endDate: _endDate,
      createdAt: DateTime.now(),
    );

    await PeriodService.instance.insertRecord(record);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已保存',
          style: TextStyle(
            color: appTheme.earth,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: appTheme.goldLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 1500),
      ),
    );

    context.pop(true);
  }
}
