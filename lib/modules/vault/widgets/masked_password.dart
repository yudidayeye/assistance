import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/theme_extension.dart';

/// 密码遮罩显示组件
///
/// 默认显示 `••••••`，点击眼睛图标可切换明文显示，
/// 点击复制图标可复制到剪贴板。
class MaskedPassword extends StatefulWidget {
  final String plainText;

  const MaskedPassword({super.key, required this.plainText});

  @override
  State<MaskedPassword> createState() => _MaskedPasswordState();
}

class _MaskedPasswordState extends State<MaskedPassword> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 密码文字
        Flexible(
          child: Text(
            _visible ? widget.plainText : '••••••',
            style: TextStyle(
              fontSize: 15,
              color: _visible ? appTheme.earth : appTheme.earthMedium,
              letterSpacing: _visible ? 0.5 : 3,
              fontFamily: _visible ? 'monospace' : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        // 可见性切换
        GestureDetector(
          onTap: () => setState(() => _visible = !_visible),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              _visible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 18,
              color: appTheme.earthMedium,
            ),
          ),
        ),
        // 复制
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: widget.plainText));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('密码已复制'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.copy_rounded,
              size: 18,
              color: appTheme.earthMedium,
            ),
          ),
        ),
      ],
    );
  }
}
