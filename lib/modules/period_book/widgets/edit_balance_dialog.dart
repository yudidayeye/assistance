import 'package:flutter/material.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/widgets/app_snack_bar.dart';

/// 编辑余额弹窗组件
/// 用于阶段编辑页和周期详情页的编辑余额功能
class EditBalanceDialog extends StatefulWidget {
  /// 当前余额值
  final double? currentBalance;
  
  /// 最大余额（本金）
  final double maxBalance;
  
  /// 保存回调
  final Future<void> Function(double value) onSave;

  const EditBalanceDialog({
    super.key,
    this.currentBalance,
    required this.maxBalance,
    required this.onSave,
  });

  /// 显示编辑余额弹窗
  static Future<void> show({
    required BuildContext context,
    double? currentBalance,
    required double maxBalance,
    required Future<void> Function(double value) onSave,
  }) async {
    await showDialog(
      context: context,
      barrierColor: Theme.of(context).appTheme.surfaceOverlay,
      builder: (ctx) => EditBalanceDialog(
        currentBalance: currentBalance,
        maxBalance: maxBalance,
        onSave: onSave,
      ),
    );
  }

  @override
  State<EditBalanceDialog> createState() => _EditBalanceDialogState();
}

class _EditBalanceDialogState extends State<EditBalanceDialog> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentBalance?.toStringAsFixed(2) ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    
    return AlertDialog(
      backgroundColor: appTheme.cream,
      title: Text(
        '编辑余额',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: appTheme.earth,
        ),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: appTheme.earth,
            ),
            decoration: InputDecoration(
              prefixText: '¥ ',
              prefixStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: appTheme.earthMedium.withValues(alpha: 0.6),
              ),
              hintText: widget.currentBalance != null 
                  ? widget.currentBalance!.toStringAsFixed(2) 
                  : '未设置',
              hintStyle: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: appTheme.earthMedium.withValues(alpha: 0.4),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(appTheme.radiusMd),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, 
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '最大余额: ¥${widget.maxBalance.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              color: appTheme.earthMedium.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('取消', style: TextStyle(color: appTheme.earthMedium)),
        ),
        TextButton(
          onPressed: _saving ? null : _handleSave,
          child: _saving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: appTheme.primary,
                  ),
                )
              : Text('确定', style: TextStyle(color: appTheme.primary)),
        ),
      ],
    );
  }

  Future<void> _handleSave() async {

    final val = double.tryParse(_controller.text.trim());
    
    if (val != null && val > widget.maxBalance) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        '余额不能超过本金 ¥${widget.maxBalance.toStringAsFixed(2)}',
        type: AppSnackBarType.error,
      );
      return;
    }
    
    if (val == null || val < 0) {
      if (!mounted) return;
      AppSnackBar.show(
        context, 
        '请输入有效的余额金额',
        type: AppSnackBarType.error,
      );
      return;
    }
    
    setState(() => _saving = true);
    
    try {
      await widget.onSave(val);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context, 
          '保存失败: $e',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
