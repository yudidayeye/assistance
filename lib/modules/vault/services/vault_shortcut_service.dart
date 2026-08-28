import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 密码保险箱 Windows 桌面快捷方式服务。
///
/// 快捷方式会以 `--vault-category=<id>` 参数启动应用，应用启动后直接
/// 进入对应分类；密码内容仍需按原有规则解锁后才能显示。
class VaultShortcutService {
  VaultShortcutService._();

  static final VaultShortcutService instance = VaultShortcutService._();

  static const _channel = MethodChannel('my_assistant/vault_shortcut');
  static const _categoryArgumentPrefix = '--vault-category=';

  /// 从应用启动参数中读取需要直达的密码保险箱分类 ID。
  static int? categoryIdFromArguments(Iterable<String> arguments) {
    for (final argument in arguments) {
      if (!argument.startsWith(_categoryArgumentPrefix)) continue;
      final categoryId = int.tryParse(
        argument.substring(_categoryArgumentPrefix.length),
      );
      if (categoryId != null && categoryId > 0) return categoryId;
    }
    return null;
  }

  /// 将分类的 Material 图标渲染为 Windows 快捷方式可使用的 PNG 数据。
  static Future<Uint8List> _renderCategoryIcon(IconData icon) async {
    const size = 256;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final background = Paint()..color = const Color(0xFF6B8E7B);
    const radius = Radius.circular(54);

    canvas.drawRRect(
      RRect.fromRectAndCorners(
        const Rect.fromLTWH(12, 12, size - 24, size - 24),
        topLeft: radius,
        topRight: radius,
        bottomLeft: radius,
        bottomRight: radius,
      ),
      background,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: Colors.white,
          fontSize: 148,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2 - 2,
      ),
    );

    final image = await recorder.endRecording().toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw StateError('无法生成分类快捷方式图标');
    }
    return byteData.buffer.asUint8List();
  }

  /// 在 Windows 桌面创建或更新指定分类的快捷方式。
  ///
  /// 返回生成的 `.lnk` 文件完整路径。
  Future<String> createDesktopShortcut({
    required int categoryId,
    required String categoryName,
    required IconData categoryIcon,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('仅 Windows 支持创建桌面快捷方式');
    }
    if (categoryId <= 0) {
      throw ArgumentError.value(categoryId, 'categoryId', '分类 ID 无效');
    }

    final iconBytes = await _renderCategoryIcon(categoryIcon);
    final shortcutPath = await _channel.invokeMethod<String>(
      'createDesktopShortcut',
      {
        'categoryId': categoryId,
        'categoryName': categoryName,
        'iconBytes': iconBytes,
      },
    );
    if (shortcutPath == null || shortcutPath.isEmpty) {
      throw StateError('创建桌面快捷方式失败');
    }
    return shortcutPath;
  }
}
