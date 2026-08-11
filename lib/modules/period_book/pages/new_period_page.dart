import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../shared/foundation/app_spacing.dart';
import '../../../shared/widgets/app_snack_bar.dart';
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
      // 如果有当前周期，新周期从当前周期结束日之后的下一个发薪日开始，
      // 结束日期为再下一个发薪日前一天（跟随发薪日设置）
      final currentEnd = DateTime.parse(ongoingPeriod.endDate);
      start = await _settings.getNextPayday(currentEnd);
      end = await _settings.getPeriodEndDate(start);
    } else {
      // 没有当前周期，使用发薪日计算的默认值
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
        SliverAppBar(
          pinned: true,
          backgroundColor: appTheme.cream,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 0,
          automaticallyImplyLeading: true,
          title: Text(
            '新建周期',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: AppSpacing.pageH,
            child: Column(
              children: [
                // 日期选择
                _buildDateCard(appTheme),
                AppSpacing.h14,
                // 初始本金
                _buildAmountCard(
                  appTheme: appTheme,
                  label: '初始本金',
                  icon: Icons.account_balance_wallet_outlined,
                  value: _baseAmount,
                  onTap: () => _showAmountKeyboard(),
                ),
                AppSpacing.h20,
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
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
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
                ],
              ),
            ),
            Text(
              date != null ? _fmt(date) : '请选择',
              style: TextStyle(
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
        decoration: BoxDecoration(
          color: appTheme.cardBackground,
          borderRadius: BorderRadius.circular(appTheme.radiusMd),
          boxShadow: appTheme.cardShadow,
          border: Border.all(color: appTheme.cardBorder, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
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
                  fontSize: 16,
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

    return SizedBox(
      width: double.infinity,
      height: 38,
      child: FilledButton(
        onPressed: canSave ? _savePeriod : null,
        style: FilledButton.styleFrom(
          backgroundColor: canSave ? appTheme.primary : appTheme.creamDark,
          foregroundColor: Colors.white,
          disabledBackgroundColor: appTheme.creamDark,
          disabledForegroundColor: appTheme.earthMedium.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(appTheme.radiusMd),
          )
        ),
        child: _saving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('创建周期'),
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
        AppSnackBar.show(context, '日期与已有周期重叠，请调整',
            type: AppSnackBarType.error);
      }
      debugPrint('Save period error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
