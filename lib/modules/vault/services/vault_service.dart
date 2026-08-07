import 'package:flutter/foundation.dart';
import '../../../core/storage/database_service.dart';
import '../models/vault_category.dart';
import '../models/vault_entry.dart';
import 'vault_crypto_service.dart';
import 'vault_session.dart';

/// 密码保险箱数据服务 — CRUD 操作
class VaultService extends ChangeNotifier {
  static final VaultService instance = VaultService._();
  VaultService._();

  final _db = DatabaseService.instance;

  void _notifyChanged() => notifyListeners();

  /// 外部通知数据已变更（如清除业务数据后刷新首页卡片）
  void notifyChanged() => notifyListeners();

  // ─── 主密码 ───

  /// 是否已设置主密码
  Future<bool> hasMasterPassword() async {
    final rows = await _db.query('mod_vault_master', limit: 1);
    return rows.isNotEmpty;
  }

  /// 获取主密码验证数据（盐 + 验证密文）
  Future<Map<String, dynamic>?> getMasterPasswordData() async {
    final rows = await _db.query('mod_vault_master', limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }

  /// 首次设置主密码
  Future<void> setupMasterPassword(String masterPassword) async {
    final (salt, verifyCipher, verifyIv) =
        VaultCryptoService.instance.setupMasterPassword(masterPassword);
    final now = DateTime.now().toIso8601String();

    await _db.insert('mod_vault_master', {
      'id': 1,
      'salt': salt,
      'verify_cipher': verifyCipher,
      'verify_iv': verifyIv,
      'created_at': now,
    });

    // 设置会话密钥
    final key = VaultCryptoService.instance.deriveKey(masterPassword, salt);
    VaultSession.instance.setKey(key);
    _notifyChanged();
  }

  /// 验证主密码并解锁
  Future<bool> unlockWithPassword(String masterPassword) async {
    final data = await getMasterPasswordData();
    if (data == null) return false;

    return VaultSession.instance.unlock(
      masterPassword: masterPassword,
      saltHex: data['salt'] as String,
      verifyCipherHex: data['verify_cipher'] as String,
      verifyIvHex: data['verify_iv'] as String,
    );
  }

  // ─── 分类 CRUD ───

  /// 获取所有分类
  Future<List<VaultCategory>> getAllCategories() async {
    final rows = await _db.query(
      'mod_vault_categories',
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(VaultCategory.fromMap).toList();
  }

  /// 获取单个分类
  Future<VaultCategory?> getCategory(int categoryId) async {
    final rows = await _db.query(
      'mod_vault_categories',
      where: 'id = ?',
      whereArgs: [categoryId],
      limit: 1,
    );
    return rows.isNotEmpty ? VaultCategory.fromMap(rows.first) : null;
  }

  /// 新增分类
  Future<int> insertCategory(VaultCategory category) async {
    final id = await _db.insert('mod_vault_categories', category.toMap());
    _notifyChanged();
    return id;
  }

  /// 更新分类
  Future<void> updateCategory(VaultCategory category) async {
    final old = await getCategory(category.id!);
    final oldIsEncrypted = old?.isEncrypted ?? true;

    await _db.update(
      'mod_vault_categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );

    // 加密状态变化时，迁移已有条目的密码存储格式
    if (oldIsEncrypted != category.isEncrypted) {
      await _migrateEntriesEncryption(category.id!,
          fromEncrypted: oldIsEncrypted, toEncrypted: category.isEncrypted);
    }
    _notifyChanged();
  }

  /// 分类加密状态变化时，迁移该分类下条目的密码存储格式
  ///
  /// 加密 → 非加密：解密后明文存储；非加密 → 加密：明文加密后存储。
  /// 会话未解锁导致无法解密时跳过对应条目。
  Future<void> _migrateEntriesEncryption(
    int categoryId, {
    required bool fromEncrypted,
    required bool toEncrypted,
  }) async {
    final entries = await getEntriesByCategory(categoryId);
    if (entries.isEmpty) return;
    for (final entry in entries) {
      final String plain;
      if (fromEncrypted) {
        final key = VaultSession.instance.key;
        if (key == null) continue;
        try {
          plain = VaultCryptoService.instance
              .decryptAesGcm(entry.encryptedPassword, entry.passwordIv, key);
        } catch (_) {
          continue;
        }
      } else {
        plain = entry.encryptedPassword;
      }

      final String newCipher;
      final String newIv;
      if (toEncrypted) {
        final key = VaultSession.instance.key;
        if (key == null) continue;
        final (cipher, iv) =
            VaultCryptoService.instance.encryptAesGcm(plain, key);
        newCipher = cipher;
        newIv = iv;
      } else {
        newCipher = plain;
        newIv = '';
      }

      await _db.update(
        'mod_vault_entries',
        {
          'encrypted_password': newCipher,
          'password_iv': newIv,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [entry.id],
      );
    }
  }

  /// 删除分类（级联删除条目）
  Future<void> deleteCategory(int categoryId) async {
    await _db.delete(
      'mod_vault_entries',
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
    await _db.delete(
      'mod_vault_categories',
      where: 'id = ?',
      whereArgs: [categoryId],
    );
    _notifyChanged();
  }

  /// 获取分类下条目数量
  Future<int> getCategoryEntryCount(int categoryId) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM mod_vault_entries WHERE category_id = ?',
      [categoryId],
    );
    return result.first['cnt'] as int;
  }

  // ─── 条目 CRUD ───

  /// 获取某分类下的所有条目（密码仍为密文）
  Future<List<VaultEntry>> getEntriesByCategory(int categoryId) async {
    final rows = await _db.query(
      'mod_vault_entries',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'created_at ASC',
    );
    return rows.map(VaultEntry.fromMap).toList();
  }

  /// 获取单个条目
  Future<VaultEntry?> getEntry(int entryId) async {
    final rows = await _db.query(
      'mod_vault_entries',
      where: 'id = ?',
      whereArgs: [entryId],
      limit: 1,
    );
    return rows.isNotEmpty ? VaultEntry.fromMap(rows.first) : null;
  }

  /// 解密条目的密码字段
  ///
  /// 加密分类需要会话已解锁；未加密分类直接返回明文存储的密码
  String? decryptEntryPassword(VaultEntry entry,
      {required bool isEncrypted}) {
    if (!isEncrypted) return entry.encryptedPassword;
    final key = VaultSession.instance.key;
    if (key == null) return null;
    try {
      return VaultCryptoService.instance
          .decryptAesGcm(entry.encryptedPassword, entry.passwordIv, key);
    } catch (_) {
      return null;
    }
  }

  /// 新增条目（加密分类自动加密密码字段，未加密分类明文保存）
  Future<int> insertEntry({
    required int categoryId,
    required String title,
    required String plainPassword,
    String? username,
    String? note,
  }) async {
    final category = await getCategory(categoryId);
    final isEncrypted = category?.isEncrypted ?? true;

    final now = DateTime.now().toIso8601String();
    final String encryptedPassword;
    final String passwordIv;
    if (isEncrypted) {
      final key = VaultSession.instance.key;
      if (key == null) throw StateError('Vault is locked');
      final (cipher, iv) =
          VaultCryptoService.instance.encryptAesGcm(plainPassword, key);
      encryptedPassword = cipher;
      passwordIv = iv;
    } else {
      encryptedPassword = plainPassword;
      passwordIv = '';
    }

    final id = await _db.insert('mod_vault_entries', {
      'category_id': categoryId,
      'title': title,
      'username': username,
      'encrypted_password': encryptedPassword,
      'password_iv': passwordIv,
      'note': note,
      'created_at': now,
      'updated_at': now,
    });
    _notifyChanged();
    return id;
  }

  /// 更新条目（加密分类自动加密密码字段，未加密分类明文保存）
  Future<void> updateEntry({
    required int entryId,
    required int categoryId,
    required String title,
    required String plainPassword,
    String? username,
    String? note,
  }) async {
    final category = await getCategory(categoryId);
    final isEncrypted = category?.isEncrypted ?? true;

    final now = DateTime.now().toIso8601String();
    final String encryptedPassword;
    final String passwordIv;
    if (isEncrypted) {
      final key = VaultSession.instance.key;
      if (key == null) throw StateError('Vault is locked');
      final (cipher, iv) =
          VaultCryptoService.instance.encryptAesGcm(plainPassword, key);
      encryptedPassword = cipher;
      passwordIv = iv;
    } else {
      encryptedPassword = plainPassword;
      passwordIv = '';
    }

    await _db.update(
      'mod_vault_entries',
      {
        'category_id': categoryId,
        'title': title,
        'username': username,
        'encrypted_password': encryptedPassword,
        'password_iv': passwordIv,
        'note': note,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [entryId],
    );
    _notifyChanged();
  }

  /// 删除条目
  Future<void> deleteEntry(int entryId) async {
    await _db.delete(
      'mod_vault_entries',
      where: 'id = ?',
      whereArgs: [entryId],
    );
    _notifyChanged();
  }

  /// 获取所有条目数量（用于摘要）
  Future<int> getTotalEntryCount() async {
    final result = await _db.rawQuery('''
      SELECT COUNT(*) as cnt FROM mod_vault_entries
      WHERE category_id IN (SELECT id FROM mod_vault_categories)
    ''');
    return result.first['cnt'] as int;
  }

  /// 获取系统中已使用过的备注标题（用于下拉选择，去重排序）
  Future<List<String>> getNoteTitles() async {
    final rows = await _db.query('mod_vault_entries');
    final titles = <String>{};
    for (final row in rows) {
      final note = row['note'] as String?;
      if (note == null || note.isEmpty) continue;
      for (final item in VaultEntry.fromMap(row).noteItems) {
        final title = item.title.trim();
        if (title.isNotEmpty) titles.add(title);
      }
    }
    final list = titles.toList()..sort();
    return list;
  }
}
