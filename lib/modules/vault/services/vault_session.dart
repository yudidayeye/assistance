import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'vault_crypto_service.dart';

/// 密码保险箱会话管理
///
/// - 持有派生密钥（仅内存，永不落盘）
/// - 退出模块 / 退出后台 / 退出分类详情页 时自动锁定
/// - 提供 lock / unlock / isLocked / key
class VaultSession {
  static final VaultSession instance = VaultSession._();
  VaultSession._();

  Uint8List? _derivedKey;

  /// 当前是否已锁定
  bool get isLocked => _derivedKey == null;

  /// 获取派生密钥（锁定状态返回 null）
  Uint8List? get key => _derivedKey;

  /// 初始化：监听 App 生命周期
  void init() {
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  /// 释放资源
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
  }

  /// 解锁：验证主密码并缓存派生密钥
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

    _derivedKey = key;
    return true;
  }

  /// 直接设置密钥（首次设置主密码后调用，无需验证）
  void setKey(Uint8List key) {
    _derivedKey = key;
  }

  /// 锁定：清除内存中的密钥
  void lock() {
    if (_derivedKey != null) {
      _derivedKey!.fillRange(0, _derivedKey!.length, 0);
      _derivedKey = null;
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
