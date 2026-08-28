import 'dart:io';

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

  /// 在 Windows 桌面创建或更新指定分类的快捷方式。
  ///
  /// 返回生成的 `.lnk` 文件完整路径。
  Future<String> createDesktopShortcut({
    required int categoryId,
    required String categoryName,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('仅 Windows 支持创建桌面快捷方式');
    }
    if (categoryId <= 0) {
      throw ArgumentError.value(categoryId, 'categoryId', '分类 ID 无效');
    }

    final shortcutPath = await _channel.invokeMethod<String>(
      'createDesktopShortcut',
      {
        'categoryId': categoryId,
        'categoryName': categoryName,
      },
    );
    if (shortcutPath == null || shortcutPath.isEmpty) {
      throw StateError('创建桌面快捷方式失败');
    }
    return shortcutPath;
  }
}
