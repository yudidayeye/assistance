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

/// 生理期日历视图主页 — 柔和健康陪伴风格
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _displayedMonth = DateTime.now();
  DateTime? _selectedDate;
  List<PeriodRecord> _records = [];
  PredictionResult? _prediction;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
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
                color: appTheme.primary,
              ),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildHeader(context, appTheme),
                if (_prediction != null)
                  SliverToBoxAdapter(
                    child: _buildPredictionCard(appTheme),
                  )
                else if (!_loading)
                  SliverToBoxAdapter(
                    child: _buildEmptyPrediction(appTheme),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
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
                ),
                if (_selectedDate != null)
                  SliverToBoxAdapter(
                    child: DateDetailPanel(
                      selectedDate: _selectedDate!,
                      records: _records,
                      prediction: _prediction,
                      onChanged: _loadData,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }

  Widget _buildHeader(BuildContext context, AppThemeExtension appTheme) {
    final safeTop = MediaQuery.of(context).padding.top;
    final headerHeight = safeTop + 58;

    return SliverPersistentHeader(
      pinned: true,
      delegate: _PinnedHeaderDelegate(
        height: headerHeight,
        child: Container(
          color: appTheme.cream,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, safeTop + 12, 16, 6),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: SizedBox(
                    width: 28,
                    height: 40,
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        color: appTheme.earth, size: 20),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    '生理期记录',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: GoogleFonts.dmSans().fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: appTheme.earth,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/period_tracker/stats'),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: appTheme.earthMedium.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.bar_chart_rounded,
                      color: appTheme.earth,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPredictionCard(AppThemeExtension appTheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusLg),
        boxShadow: appTheme.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '预测信息',
            style: TextStyle(
              fontSize: 14,
              color: appTheme.earthMedium,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildPredictionMetric(
                appTheme,
                icon: Icons.event_rounded,
                label: '下次经期',
                value: AppDateUtils.formatDate(_prediction!.nextStartDate),
              ),
              Container(
                width: 1,
                height: 40,
                color: appTheme.earthMedium.withValues(alpha: 0.12),
              ),
              _buildPredictionMetric(
                appTheme,
                icon: Icons.timelapse_rounded,
                label: '当前周期',
                value: '第${_prediction!.currentDayInCycle}天',
              ),
              Container(
                width: 1,
                height: 40,
                color: appTheme.earthMedium.withValues(alpha: 0.12),
              ),
              _buildPredictionMetric(
                appTheme,
                icon: Icons.repeat_rounded,
                label: '平均周期',
                value: '${_prediction!.avgCycleLength}天',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionMetric(
    AppThemeExtension appTheme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: appTheme.primary.withAlpha(180)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: appTheme.earth,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: appTheme.earthMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPrediction(AppThemeExtension appTheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusLg),
        boxShadow: appTheme.cardShadow,
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: appTheme.primary.withAlpha(140)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '暂无预测数据，请先记录经期',
              style: TextStyle(
                fontSize: 13,
                color: appTheme.earthMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  const _PinnedHeaderDelegate({
    required this.height,
    required this.child,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(height: height, child: child);
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}
