import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/widgets/pinned_header_delegate.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../shared/foundation/app_spacing.dart';
import '../services/period_book_service.dart';
import '../services/period_book_settings.dart';

/// 新建周期页
class NewPeriodPage extends StatefulWidget {
  const NewPeriodPage({super.key});

  @override
  State<NewPeriodPage> createState() => _NewPeriodPageState();
}

class _NewPeriodPageState extends State<NewPeriodPage> {
  final _service = PeriodBookService.instance;
  final _settings = PeriodBookSettings.instance;

  DateTime? _startDate;
  DateTime? _endDate;
  String _baseAmount = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initDefaults();
  }

  Future<void> _initDefaults() async {
    // 检查是否有当前周期
    final ongoingPeriod = await _service.getOngoingPeriod();
    DateTime start;
    DateTime end;

    if (ongoingPeriod != null) {
      // 如果有当前周期，默认从当前周期结束日期的下一天开始
      final currentEnd = DateTime.parse(ongoingPeriod.endDate);
      start = currentEnd.add(const Duration(days: 1));
      end = start.add(const Duration(days: 29)); // 默认一个月
    } else {
      // 没有当前周期，使用默认值
      start = await _settings.getDefaultStartDate();
      end = await _settings.getDefaultEndDate();
    }

    if (mounted) {
      setState(() {
        _startDate = start;
        _endDate = end;
      });
    }
  }

  String _fmt(DateTime dt) {
    return '${dt.month.toString().padLeft(2, '0')}月${dt.day.toString().padLeft(2, '0')}日';
  }

  String _toIso(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  // ═══════════════════════════════════════════════════════════
  // 构建
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    return AppScrollScaffold(
      slivers: [
        AppHeader.simple(title: '新建周期'),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: [
                AppSpacing.h16,
                // 日期选择
                _buildDateCard(appTheme),
                AppSpacing.h16,
                // 初始本金
                _buildAmountCard(
                  appTheme: appTheme,
                  label: '初始本金',
                  icon: Icons.account_balance_wallet_outlined,
                  value: _baseAmount,
                  onTap: () => _showAmountKeyboard(),
                ),
                AppSpacing.h32,
                // 保存按钮
                _buildSaveButton(appTheme),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }


  // ═══════════════════════════════════════════════════════════
  // 日期选择卡片
  // ══════════════════════════════════════════════════════════

  Widget _buildDateCard(AppThemeExtension appTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusXl),
        boxShadow: appTheme.cardShadow,
        border: Border.all(color: appTheme.cardBorder, width: 0.5),
      ),
      child: Column(
        children: [
          _buildDateRow(
            appTheme: appTheme,
            label: '开始日期',
            icon: Icons.event_available_rounded,
            iconColor: appTheme.primary,
            date: _startDate,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _startDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() => _startDate = picked);
                // 如果结束日期早于开始日期，自动调整
                if (_endDate != null && _endDate!.isBefore(picked)) {
                  setState(
                      () => _endDate = picked.add(const Duration(days: 29)));
                }
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.only(left: 78),
            child: Divider(
              height: 1,
              color: appTheme.earthMedium.withValues(alpha: 0.07),
            ),
          ),
          _buildDateRow(
            appTheme: appTheme,
            label: '结束日期',
            icon: Icons.event_rounded,
            iconColor: appTheme.sage,
            date: _endDate,
            required: true,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _endDate ?? DateTime.now(),
                firstDate: _startDate ?? DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() => _endDate = picked);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow({
    required AppThemeExtension appTheme,
    required String label,
    required IconData icon,
    required Color iconColor,
    required DateTime? date,
    required VoidCallback onTap,
    bool required = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(appTheme.radiusMd),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: appTheme.earth,
                    ),
                  ),
                  if (required)
                    Text(
                      '必填',
                      style: TextStyle(
                        fontSize: 11,
                        color: appTheme.earthMedium.withValues(alpha: 0.4),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              date != null ? _fmt(date) : '请选择',
              style: TextStyle(
                fontFamily: GoogleFonts.dmSans().fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: date != null
                    ? appTheme.earth
                    : appTheme.earthMedium.withValues(alpha: 0.5),
              ),
            ),
            AppSpacing.w8,
            Icon(Icons.chevron_right_rounded,
                size: 18, color: appTheme.earthMedium.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // 金额输入卡片
  // ═══════════════════════════════════════════════════════════

  Widget _buildAmountCard({
    required AppThemeExtension appTheme,
    required String label,
    required String value,
    required VoidCallback onTap,
    required IconData icon,
    String? subtitle,
    bool isOptional = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: appTheme.cardBackground,
          borderRadius: BorderRadius.circular(appTheme.radiusXl),
          boxShadow: appTheme.cardShadow,
          border: Border.all(color: appTheme.cardBorder, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: appTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(appTheme.radiusMd),
                ),
                child: Icon(icon, color: appTheme.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: appTheme.earth,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: appTheme.earthMedium.withValues(alpha: 0.4),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                value.isEmpty ? '0' : '¥$value',
                style: TextStyle(
                  fontFamily: GoogleFonts.dmSans().fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: value.isEmpty && !isOptional
                      ? appTheme.earthMedium.withValues(alpha: 0.4)
                      : appTheme.earth,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              AppSpacing.w8,
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: appTheme.earthMedium.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 保存按钮
  // ═══════════════════════════════════════════════════════════

  Widget _buildSaveButton(AppThemeExtension appTheme) {
    final canSave = _startDate != null &&
        _endDate != null &&
        _baseAmount.isNotEmpty &&
        !_saving;

    return GestureDetector(
      onTap: canSave ? _savePeriod : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: canSave
              ? LinearGradient(
                  colors: [appTheme.primary, appTheme.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: canSave ? null : appTheme.creamDark,
          borderRadius: BorderRadius.circular(appTheme.radiusMd),
          boxShadow: canSave
              ? [
                  BoxShadow(
                    color: appTheme.primary.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: _saving
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  '创建周期',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: canSave
                        ? Colors.white
                        : appTheme.earthMedium.withValues(alpha: 0.4),
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 金额键盘弹窗
  // ═══════════════════════════════════════════════════════════

  void _showAmountKeyboard() {
    final appTheme = Theme.of(context).appTheme;
    final controller = TextEditingController(text: _baseAmount);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: appTheme.cream,
        title: Text(
          '初始本金',
          style: TextStyle(
            fontFamily: GoogleFonts.playfairDisplay().fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: appTheme.earth,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: TextStyle(
            fontFamily: GoogleFonts.dmSans().fontFamily,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: appTheme.earth,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            prefixText: '¥ ',
            prefixStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: appTheme.earthMedium.withValues(alpha: 0.6),
            ),
            hintStyle: TextStyle(
              color: appTheme.earthMedium.withValues(alpha: 0.4),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(appTheme.radiusMd),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: appTheme.earthMedium)),
          ),
          TextButton(
            onPressed: () {
              setState(() => _baseAmount = controller.text.trim());
              Navigator.pop(ctx);
            },
            child: Text('确定', style: TextStyle(color: appTheme.primary)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // 保存
  // ═══════════════════════════════════════════════════════════

  Future<void> _savePeriod() async {
    if (_startDate == null || _endDate == null || _baseAmount.isEmpty) return;

    setState(() => _saving = true);
    try {
      await _service.createPeriod(
        startDate: _toIso(_startDate!),
        endDate: _toIso(_endDate!),
        baseAmount: double.parse(_baseAmount),
      );
      if (mounted) {
        context.pop(); // 返回上一页（详情页会自动刷新）
      }
    } catch (e) {
      if (mounted) {
        // 显示错误提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('日期与已有周期重叠，请调整'),
            backgroundColor: Theme.of(context).appTheme.rose,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Theme.of(context).appTheme.radiusSm),
            ),
          ),
        );
      }
      debugPrint('Save period error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

