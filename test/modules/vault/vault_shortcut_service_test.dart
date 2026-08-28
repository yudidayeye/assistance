import 'package:flutter_test/flutter_test.dart';
import 'package:my_assistant/modules/vault/services/vault_shortcut_service.dart';

void main() {
  group('VaultShortcutService.categoryIdFromArguments', () {
    test('读取有效的分类启动参数', () {
      expect(
        VaultShortcutService.categoryIdFromArguments([
          '--trace-startup',
          '--vault-category=42',
        ]),
        42,
      );
    });

    test('忽略无效的分类启动参数', () {
      expect(
        VaultShortcutService.categoryIdFromArguments([
          '--vault-category=0',
          '--vault-category=invalid',
        ]),
        isNull,
      );
    });
  });
}
