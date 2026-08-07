import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

/// 密码保险箱核心加密服务
///
/// 加密链：主密码 + Argon2id 盐 → 256-bit 派生密钥（仅驻留内存）
///         派生密钥 → AES-256-GCM 加密「密码字段」
///         标题、备注 → 明文存储
class VaultCryptoService {
  static final VaultCryptoService instance = VaultCryptoService._();
  VaultCryptoService._();

  // Argon2id 参数（安全 + 移动端友好）
  static const int _argon2Memory = 65536; // 64 MB
  static const int _argon2Iterations = 3;
  static const int _argon2Parallelism = 1;
  static const int _argon2KeyLength = 32; // 256-bit

  /// 验证固定明文字符串
  static const String _verifyPlaintext = 'VAULT_VERIFIED_OK';

  // ─── 工具方法 ───

  /// 生成随机字节（hex 编码）
  String generateSalt([int length = 32]) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return _bytesToHex(Uint8List.fromList(bytes));
  }

  /// hex 字符串 → Uint8List
  Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  /// Uint8List → hex 字符串
  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // ─── Argon2id 密钥派生 ───

  /// 主密码 + 盐 → 256-bit 派生密钥
  ///
  /// 使用 Argon2id（混合模式），参数：
  /// - memory: 64MB, iterations: 3, parallelism: 1
  /// - 输出 32 字节（256-bit）对称密钥
  Uint8List deriveKey(String masterPassword, String saltHex) {
    final salt = _hexToBytes(saltHex);
    final passwordBytes = Uint8List.fromList(utf8.encode(masterPassword));

    final params = Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      salt,
      desiredKeyLength: _argon2KeyLength,
      version: Argon2Parameters.ARGON2_VERSION_13,
      iterations: _argon2Iterations,
      memory: _argon2Memory,
      lanes: _argon2Parallelism,
    );

    final generator = Argon2BytesGenerator();
    generator.init(params);

    final result = generator.process(passwordBytes);

    return result;
  }

  // ─── AES-256-GCM 加解密 ───

  /// AES-256-GCM 加密
  ///
  /// 返回 (密文hex, ivHex)
  (String, String) encryptAesGcm(String plaintext, Uint8List key) {
    final iv = _generateIv();
    final encrypter = encrypt.Encrypter(
      encrypt.AES(
        encrypt.Key(key),
        mode: encrypt.AESMode.gcm,
      ),
    );
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return (encrypted.base16, _bytesToHex(iv.bytes));
  }

  /// AES-256-GCM 解密
  String decryptAesGcm(String cipherHex, String ivHex, Uint8List key) {
    final iv = encrypt.IV(_hexToBytes(ivHex));
    final encrypter = encrypt.Encrypter(
      encrypt.AES(
        encrypt.Key(key),
        mode: encrypt.AESMode.gcm,
      ),
    );
    final encrypted = encrypt.Encrypted.fromBase16(cipherHex);
    return encrypter.decrypt(encrypted, iv: iv);
  }

  /// 生成 12 字节随机 IV（GCM 推荐长度）
  encrypt.IV _generateIv() {
    final random = Random.secure();
    final bytes = List<int>.generate(12, (_) => random.nextInt(256));
    return encrypt.IV(Uint8List.fromList(bytes));
  }

  // ─── 验证主密码 ───

  /// 首次设置主密码：生成盐 + 验证密文
  ///
  /// 返回 (saltHex, verifyCipherHex, verifyIvHex)
  (String, String, String) setupMasterPassword(String masterPassword) {
    final salt = generateSalt();
    final key = deriveKey(masterPassword, salt);
    final (verifyCipher, verifyIv) = encryptAesGcm(_verifyPlaintext, key);
    return (salt, verifyCipher, verifyIv);
  }

  /// 验证主密码是否正确
  ///
  /// 用主密码派生密钥，尝试解密 verifyCipher，
  /// 解密结果 == _verifyPlaintext 则正确
  bool verifyMasterPassword(
    String masterPassword,
    String saltHex,
    String verifyCipherHex,
    String verifyIvHex,
  ) {
    try {
      final key = deriveKey(masterPassword, saltHex);
      final result = decryptAesGcm(verifyCipherHex, verifyIvHex, key);
      return result == _verifyPlaintext;
    } catch (_) {
      return false;
    }
  }

  /// 验证主密码并返回派生密钥（只派生一次）
  ///
  /// 验证成功返回派生密钥，失败返回 null。
  /// 相比「verifyMasterPassword + deriveKey」可避免重复派生，解锁更快。
  Uint8List? verifyAndDeriveKey(
    String masterPassword,
    String saltHex,
    String verifyCipherHex,
    String verifyIvHex,
  ) {
    try {
      final key = deriveKey(masterPassword, saltHex);
      final result = decryptAesGcm(verifyCipherHex, verifyIvHex, key);
      if (result != _verifyPlaintext) return null;
      return key;
    } catch (_) {
      return null;
    }
  }
}
