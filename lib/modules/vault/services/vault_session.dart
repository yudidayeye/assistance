import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'vault_crypto_service.dart';

/// 密码保险箱会话管理
///
/// - 持有主密码与主密钥（仅内存，永不落盘），用于按条目盐派生各条目密钥
/// - 缓存已派生出的条目密钥，避免重复派生
/// - 退出模块 / 退出后台 / 退出分类详情页 时自动锁定
/// - 提供 lock / unlock / isLocked / keyForEntry
class VaultSession {
  static final VaultSession instance = VaultSession._();
  VaultSession._();

  String? _masterPassword;
  String? _masterSalt;
  Uint8List? _masterKey;
  final Map<String, Uint8List> _keyCache = {};

  /// 当前是否已锁定
  bool get isLocked => _masterKey == null;

  /// 获取主密钥（锁定状态返回 null）
  ///
  /// 兼容旧调用：为主盐派生的密钥，用于旧格式（Argon2）条目
  Uint8List? get key => _masterKey;

  /// 初始化：监听 App 生命周期
  void init() {
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  /// 释放资源
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
  }

  /// 解锁：验证主密码并缓存主密码、主盐与主密钥
  ///
  /// 返回 true 表示解锁成功，false 表示密码错误
  bool unlock({
    required String masterPassword,
    required String saltHex,
    required String verifyCipherHex,
    required String verifyIvHex,
  }) {
    final key = VaultCryptoService.instance.verifyAndDeriveKey(
      masterPassword,
      saltHex,
      verifyCipherHex,
      verifyIvHex,
    );
    if (key == null) return false;

    _setCredentials(
      masterPassword: masterPassword,
      saltHex: saltHex,
      key: key,
    );
    return true;
  }

  /// 直接写入会话（首次设置主密码或 Isolate 解锁成功后调用）
  void setCredentials({
    required String masterPassword,
    required String saltHex,
    required Uint8List key,
  }) {
    _setCredentials(masterPassword: masterPassword, saltHex: saltHex, key: key);
  }

  void _setCredentials({
    required String masterPassword,
    required String saltHex,
    required Uint8List key,
  }) {
    _masterPassword = masterPassword;
    _masterSalt = saltHex;
    _masterKey = key;
    _keyCache[saltHex] = key;
  }

  /// 获取解/加密某条目密码所需的密钥（方案 C：每条记录独立盐）
  ///
  /// 有效盐 = 条目盐（缺省用主盐），用「主密码 + 有效盐」做 Argon2 派生。
  /// 命中主盐时直接复用已缓存的主密钥，避免重复派生。
  /// 未解锁返回 null。
  Uint8List? keyForEntry(String? saltHex) {
    if (_masterKey == null || _masterSalt == null) return null;
    final salt = (saltHex == null || saltHex.isEmpty) ? null : saltHex;
    final effectiveSalt = salt ?? _masterSalt!;
    if (effectiveSalt == _masterSalt) return _masterKey;
    final cached = _keyCache[effectiveSalt];
    if (cached != null) return cached;
    final derived =
        VaultCryptoService.instance.deriveKey(_masterPassword!, effectiveSalt);
    _keyCache[effectiveSalt] = derived;
    return derived;
  }

  /// 锁定：清除内存中的主密码与所有密钥
  void lock() {
    _masterPassword = null;
    _masterSalt = null;
    for (final k in _keyCache.values) {
      k.fillRange(0, k.length, 0);
    }
    _keyCache.clear();
    if (_masterKey != null) {
      _masterKey!.fillRange(0, _masterKey!.length, 0);
      _masterKey = null;
    }
  }

  // ─── App 生命周期监听 ───

  final _lifecycleObserver = _VaultLifecycleObserver();

  /// 处理 App 生命周期变化：进入后台立即锁定
  void _onAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      lock();
    }
  }
}

/// App 生命周期观察者
class _VaultLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    VaultSession.instance._onAppLifecycleState(state);
  }
}
