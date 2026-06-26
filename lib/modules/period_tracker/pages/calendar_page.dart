import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/period_record.dart';
import '../services/period_service.dart';
import '../services/prediction_service.dart';
import '../widgets/period_calendar.dart';
import '../widgets/date_detail_panel.dart';
import '../../../shared/utils/date_utils.dart';
import '../../../core/theme/theme_extension.dart';

/// 生理期日历视图主页 — 奢华自然主义风格
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage>
    with SingleTickerProviderStateMixin {
  DateTime _displayedMonth = DateTime.now();
  DateTime? _selectedDate;
  List<PeriodRecord> _records = [];
  PredictionResult? _prediction;
  bool _loading = true;
  late AnimationController _headerController;
  late Animation<double> _headerFadeAnim;
  late Animation<Offset> _headerSlideAnim;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _headerFadeAnim = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOut,
    );
    _headerSlideAnim = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    ));

    _loadData();
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final records = await PeriodService.instance.getAllRecords();
    final prediction = PredictionService.instance.predict(records);

    if (mounted) {
      setState(() {
        _records = records;
        _prediction = prediction;
        _loading = false;
      });
      _headerController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;

    return Scaffold(
      backgroundColor: appTheme.cream,
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: appTheme.rose,
              ),
            )
          : Column(
              children: [
                // 头部区域
                FadeTransition(
                  opacity: _headerFadeAnim,
                  child: SlideTransition(
                    position: _headerSlideAnim,
                    child: _buildHeader(context, appTheme),
                  ),
                ),

                // 可滚动内容区
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        // 日历 card（内含月份切换）
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                          child: PeriodCalendar(
                            displayedMonth: _displayedMonth,
                            records: _records,
                            prediction: _prediction,
                            onMonthChanged: (month) {
                              setState(() => _displayedMonth = month);
                            },
                            selectedDate: _selectedDate,
                            onDateSelected: (date) {
                              setState(() => _selectedDate = date);
                            },
                          ),
                        ),

                        // 日期详情面板
                        if (_selectedDate != null)
                          DateDetailPanel(
                            selectedDate: _selectedDate!,
                            records: _records,
                            prediction: _prediction,
                            onChanged: _loadData,
                          ),

                        // 预测信息
                        if (_prediction != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                            child: _buildPredictionCard(appTheme),
                          )
                        else if (!_loading)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                            child: _buildEmptyPrediction(appTheme),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
                '生理期记录',
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

          // 统计按钮
          GestureDetector(
            onTap: () => context.push('/period_tracker/stats'),
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
                Icons.bar_chart_rounded,
                color: appTheme.earthMedium,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionCard(AppThemeExtension appTheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            appTheme.rose.withAlpha(40),
            appTheme.roseLight.withAlpha(20),
          ],
        ),
        border: Border.all(
          color: appTheme.rose.withAlpha(40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: appTheme.rose.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_today_rounded,
                  color: appTheme.rose,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '预测信息',
                style: TextStyle(
                  fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: appTheme.earth,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 预测详情
          _buildPredictionItem(
            appTheme,
            icon: Icons.event_rounded,
            label: '下次经期',
            value:
                '${AppDateUtils.formatFullDate(_prediction!.nextStartDate)} - ${AppDateUtils.formatFullDate(_prediction!.nextStartDate.add(const Duration(days: 4)))}',
          ),
          const SizedBox(height: 12),
          _buildPredictionItem(
            appTheme,
            icon: Icons.timelapse_rounded,
            label: '当前周期',
            value: '第${_prediction!.currentDayInCycle}天',
          ),
          const SizedBox(height: 12),
          _buildPredictionItem(
            appTheme,
            icon: Icons.repeat_rounded,
            label: '平均周期',
            value: '${_prediction!.avgCycleLength}天',
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionItem(
    AppThemeExtension appTheme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: appTheme.rose.withAlpha(180),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: appTheme.earthMedium,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: appTheme.earth,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPrediction(AppThemeExtension appTheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: appTheme.earthMedium.withAlpha(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: appTheme.rose.withAlpha(15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              color: appTheme.rose.withAlpha(120),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '暂无预测数据',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: appTheme.earth,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '请先记录经期以获取预测',
                  style: TextStyle(
                    fontSize: 13,
                    color: appTheme.earthMedium,
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
