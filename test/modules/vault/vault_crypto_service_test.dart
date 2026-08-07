import 'package:flutter_test/flutter_test.dart';
import 'package:my_assistant/modules/vault/services/vault_crypto_service.dart';

void main() {
  final crypto = VaultCryptoService.instance;

  test('verifyAndDeriveKey：正确密码返回派生密钥且与 deriveKey 一致', () {
    const password = 'test-password-123';
    final (salt, verifyCipher, verifyIv) =
        crypto.setupMasterPassword(password);

    final key = crypto.verifyAndDeriveKey(
      password,
      salt,
      verifyCipher,
      verifyIv,
    );

    expect(key, isNotNull);
    expect(key!.length, 32);
    expect(key, crypto.deriveKey(password, salt));
  });

  test('verifyAndDeriveKey：错误密码返回 null', () {
    const password = 'test-password-123';
    final (salt, verifyCipher, verifyIv) =
        crypto.setupMasterPassword(password);

    final key = crypto.verifyAndDeriveKey(
      'wrong-password',
      salt,
      verifyCipher,
      verifyIv,
    );

    expect(key, isNull);
  });
}
