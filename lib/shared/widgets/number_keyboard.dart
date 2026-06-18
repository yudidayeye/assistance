import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/theme_extension.dart';

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

  void _onKey(String key) {
    String newVal = currentValue;

    if (key == '.') {
      if (newVal.contains('.')) return;
      if (newVal.isEmpty) newVal = '0';
      newVal += '.';
    } else if (key == 'del') {
      if (newVal.isNotEmpty) {
        newVal = newVal.substring(0, newVal.length - 1);
      }
    } else if (key == '00') {
      if (newVal.isEmpty || newVal == '0') return;
      if (newVal.contains('.') && newVal.split('.')[1].length >= 2) return;
      newVal += '00';
    } else {
      if (newVal == '0' && key != '.') newVal = '';
      if (newVal.contains('.')) {
        final decimalPart = newVal.split('.')[1];
        if (decimalPart.length >= 2) return;
      }
      newVal += key;
    }

    onValueChanged(newVal);
  }

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
      onTap: () => _onKey(key),
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
      onTap: () => _onKey(key),
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
