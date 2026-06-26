import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/theme_extension.dart';

/// 金额输入纯函数 reducer：当前字符串 + 按键 -> 新字符串
/// 规则：最多两位小数、前导零替换、'00' 处理、退格、小数点
String reduceAmountText(String current, String key) {
  if (key == 'del') {
    if (current.isEmpty) return current;
    return current.substring(0, current.length - 1);
  }

  if (key == '.') {
    if (current.contains('.')) return current;
    if (current.isEmpty) return '0.';
    return '$current.';
  }

  if (key == '00') {
    if (current.isEmpty || current == '0') return current;
    // 有小数点时不允许添加 '00'，避免产生三位以上小数
    if (current.contains('.')) return current;
    return '${current}00';
  }

  // 数字键 0-9
  if (current == '0') return key;
  if (current.contains('.')) {
    final decimalPart = current.split('.')[1];
    if (decimalPart.length >= 2) return current;
  }
  return '$current$key';
}

/// 自定义数字键盘 — 奢华自然主义风格
class NumberKeyboard extends StatelessWidget {
  final String currentValue;
  final ValueChanged<String> onValueChanged;
  final VoidCallback? onDone;
  final String doneText;
  final Color doneColor;

  const NumberKeyboard({
    super.key,
    required this.currentValue,
    required this.onValueChanged,
    this.onDone,
    this.doneText = '完成',
    this.doneColor = const Color(0xFFD4AF37),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;

    final keys = [
      ['7', '8', '9'],
      ['4', '5', '6'],
      ['1', '2', '3'],
      ['.', '0', '00'],
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 数字键
          ...keys.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: row
                      .map((key) => Expanded(
                            child: _buildKey(key, appTheme),
                          ))
                      .toList(),
                ),
              )),

          // 功能键行
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildSpecialKey('del', Icons.backspace_outlined, appTheme),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: _buildDoneKey(appTheme),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String key, AppThemeExtension appTheme) {
    return GestureDetector(
      onTap: () => onValueChanged(reduceAmountText(currentValue, key)),
      child: Container(
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: appTheme.creamDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: appTheme.earthMedium.withAlpha(15),
          ),
        ),
        child: Center(
          child: Text(
            key,
            style: TextStyle(
              fontFamily: GoogleFonts.playfairDisplay().fontFamily,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: appTheme.earth,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey(
      String key, IconData icon, AppThemeExtension appTheme) {
    return GestureDetector(
      onTap: () => onValueChanged(reduceAmountText(currentValue, key)),
      child: Container(
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: appTheme.creamDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: appTheme.earthMedium.withAlpha(15),
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 22,
            color: appTheme.earthMedium,
          ),
        ),
      ),
    );
  }

  Widget _buildDoneKey(AppThemeExtension appTheme) {
    return GestureDetector(
      onTap: onDone,
      child: Container(
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              doneColor,
              doneColor.withAlpha(200),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: doneColor.withAlpha(60),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            doneText,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
