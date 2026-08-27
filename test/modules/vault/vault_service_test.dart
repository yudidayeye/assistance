import 'dart:typed_data';
import 'dart:io';
import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_assistant/core/storage/database_service.dart';
import 'package:my_assistant/modules/vault/models/vault_category.dart';
import 'package:my_assistant/modules/vault/services/vault_service.dart';
import 'package:my_assistant/modules/vault/services/vault_session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    if (Platform.isWindows) {
      // flutter test 环境下 sqlite3 走 system 查找（sqlite3.dll），先按路径预加载
      DynamicLibrary.open(r'windows\runner\sqlite3.dll');
    }
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database testDb;
  bool dbInitialized = false;

  /// 仅创建密码保险箱相关表（绕过 createSchemaForTesting 的事务建表）
  Future<void> createVaultSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mod_vault_master (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        salt TEXT NOT NULL,
        verify_cipher TEXT NOT NULL,
        verify_iv TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mod_vault_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL DEFAULT 'folder',
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_encrypted INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mod_vault_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        username TEXT,
        encrypted_password TEXT NOT NULL,
        password_iv TEXT NOT NULL,
        note TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES mod_vault_categories(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_vault_entries_category ON mod_vault_entries(category_id)',
    );
  }

  Future<VaultService> setUpVault() async {
    // 关闭上一个内存库，避免 sqflite 按路径缓存导致测试间数据残留
    if (dbInitialized) {
      await testDb.close();
    }
    testDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dbInitialized = true;
    DatabaseService.instance.useDatabaseForTesting(testDb);
    await createVaultSchema(testDb);
    return VaultService.instance;
  }

  String now() => DateTime.now().toIso8601String();

  void unlockSession() {
    // 仅用于测试：直接注入 32 字节密钥，绕过 Argon2 派生耗时
    VaultSession.instance.setKey(Uint8List(32));
  }

  test('删除分类时同时清理该分类下的条目，统计归零', () async {
    final vault = await setUpVault();
    unlockSession();

    final catId = await vault.insertCategory(VaultCategory(
      name: '测试分类',
      createdAt: now(),
      updatedAt: now(),
    ));
    await vault.insertEntry(
        categoryId: catId, title: '条目A', plainPassword: 'p1');
    await vault.insertEntry(
        categoryId: catId, title: '条目B', plainPassword: 'p2');
    expect(await vault.getTotalEntryCount(), 2);

    await vault.deleteCategory(catId);

    expect(await vault.getTotalEntryCount(), 0);
    expect(await vault.getAllCategories(), isEmpty);
  });

  test('历史遗留的孤儿条目不计入首页统计', () async {
    final vault = await setUpVault();
    unlockSession();

    final catId = await vault.insertCategory(VaultCategory(
      name: '测试分类',
      createdAt: now(),
      updatedAt: now(),
    ));
    await vault.insertEntry(
        categoryId: catId, title: '有效条目', plainPassword: 'p1');

    // 模拟旧版本外键级联失效时残留的孤儿条目（所属分类已不存在）
    await testDb.insert('mod_vault_entries', {
      'category_id': 999,
      'title': '孤儿条目',
      'encrypted_password': 'abc',
      'password_iv': 'def',
      'created_at': now(),
      'updated_at': now(),
    });

    expect(await vault.getTotalEntryCount(), 1);
  });

  test('插入带用户名的条目，读取后用户名保持一致', () async {
    final vault = await setUpVault();
    unlockSession();

    final catId = await vault.insertCategory(VaultCategory(
      name: '测试分类',
      createdAt: now(),
      updatedAt: now(),
    ));
    final entryId = await vault.insertEntry(
      categoryId: catId,
      title: '条目A',
      username: 'admin@example.com',
      plainPassword: 'p1',
    );

    final entry = await vault.getEntry(entryId);
    expect(entry, isNotNull);
    expect(entry!.username, 'admin@example.com');
  });

  test('用户名可选：不传 username 也可正常新增', () async {
    final vault = await setUpVault();
    unlockSession();

    final catId = await vault.insertCategory(VaultCategory(
      name: '测试分类',
      createdAt: now(),
      updatedAt: now(),
    ));
    final entryId = await vault.insertEntry(
      categoryId: catId,
      title: '条目B',
      plainPassword: 'p1',
    );

    final entry = await vault.getEntry(entryId);
    expect(entry, isNotNull);
    expect(entry!.username, isNull);
  });

  test('未加密分类的密码明文存储，锁定后仍可读取', () async {
    final vault = await setUpVault();
    unlockSession();

    final catId = await vault.insertCategory(VaultCategory(
      name: '明文分类',
      isEncrypted: false,
      createdAt: now(),
      updatedAt: now(),
    ));
    final entryId = await vault.insertEntry(
      categoryId: catId,
      title: '普通网站',
      plainPassword: 'plain-123',
    );

    final entry = await vault.getEntry(entryId);
    if (entry == null) {
      fail('条目不存在');
    }
    expect(entry.encryptedPassword, 'plain-123');

    // 锁定会话后仍能直接读取明文
    VaultSession.instance.lock();
    final category = await vault.getCategory(catId);
    if (category == null) {
      fail('分类不存在');
    }
    final plain =
        vault.decryptEntryPassword(entry, isEncrypted: category.isEncrypted);
    expect(plain, 'plain-123');
  });

  test('加密分类的密码密文存储并可解密', () async {
    final vault = await setUpVault();
    unlockSession();

    final catId = await vault.insertCategory(VaultCategory(
      name: '加密分类',
      isEncrypted: true,
      createdAt: now(),
      updatedAt: now(),
    ));
    final entryId = await vault.insertEntry(
      categoryId: catId,
      title: '银行',
      plainPassword: 'secret',
    );

    final entry = await vault.getEntry(entryId);
    if (entry == null) {
      fail('条目不存在');
    }
    expect(entry.encryptedPassword, isNot('secret'));
    expect(entry.passwordIv, isNotNull);

    final category = await vault.getCategory(catId);
    if (category == null) {
      fail('分类不存在');
    }
    expect(
      vault.decryptEntryPassword(entry, isEncrypted: category.isEncrypted),
      'secret',
    );
  });

  test('分类从加密切换为不加密时，已有条目迁移为明文存储', () async {
    final vault = await setUpVault();
    unlockSession();

    final catId = await vault.insertCategory(VaultCategory(
      name: '加密分类',
      isEncrypted: true,
      createdAt: now(),
      updatedAt: now(),
    ));
    final entryId = await vault.insertEntry(
      categoryId: catId,
      title: '银行',
      plainPassword: 'secret',
    );

    await vault.updateCategory(VaultCategory(
      id: catId,
      name: '加密分类',
      isEncrypted: false,
      createdAt: now(),
      updatedAt: now(),
    ));

    final entry = await vault.getEntry(entryId);
    if (entry == null) {
      fail('条目不存在');
    }
    expect(entry.encryptedPassword, 'secret');
    expect(entry.passwordIv, '');
  });

  test('分类从不加密切换为加密时，已有条目迁移为密文存储', () async {
    final vault = await setUpVault();
    unlockSession();

    final catId = await vault.insertCategory(VaultCategory(
      name: '明文分类',
      isEncrypted: false,
      createdAt: now(),
      updatedAt: now(),
    ));
    final entryId = await vault.insertEntry(
      categoryId: catId,
      title: '普通网站',
      plainPassword: 'plain-123',
    );

    await vault.updateCategory(VaultCategory(
      id: catId,
      name: '明文分类',
      isEncrypted: true,
      createdAt: now(),
      updatedAt: now(),
    ));

    final entry = await vault.getEntry(entryId);
    if (entry == null) {
      fail('条目不存在');
    }
    expect(entry.encryptedPassword, isNot('plain-123'));
    expect(entry.passwordIv, isNotEmpty);

    final category = await vault.getCategory(catId);
    if (category == null) {
      fail('分类不存在');
    }
    expect(
      vault.decryptEntryPassword(entry, isEncrypted: category.isEncrypted),
      'plain-123',
    );
  });
  test('updateEntriesOrder 批量更新条目排序顺序并持久化', () async {
    final vault = await setUpVault();
    unlockSession();

    final catId = await vault.insertCategory(VaultCategory(
      name: '测试分类',
      createdAt: now(),
      updatedAt: now(),
    ));
    await vault.insertEntry(
        categoryId: catId, title: '条目A', plainPassword: 'p1');
    await vault.insertEntry(
        categoryId: catId, title: '条目B', plainPassword: 'p2');
    await vault.insertEntry(
        categoryId: catId, title: '条目C', plainPassword: 'p3');

    // 初始按 sort_order 排序
    expect(
      (await vault.getEntriesByCategory(catId)).map((e) => e.title).toList(),
      ['条目A', '条目B', '条目C'],
    );

    // 打乱顺序并批量持久化
    final reordered = await vault.getEntriesByCategory(catId);
    await vault.updateEntriesOrder(
        [reordered[2], reordered[0], reordered[1]]);

    final after = await vault.getEntriesByCategory(catId);
    expect(after.map((e) => e.title).toList(), ['条目C', '条目A', '条目B']);
    expect(after.map((e) => e.sortOrder).toList(), [0, 1, 2]);
  });

  test('updateCategoriesOrder 批量更新分类排序顺序并持久化', () async {
    final vault = await setUpVault();
    unlockSession();

    await vault.insertCategory(VaultCategory(
      name: '分类A',
      sortOrder: 0,
      createdAt: now(),
      updatedAt: now(),
    ));
    await vault.insertCategory(VaultCategory(
      name: '分类B',
      sortOrder: 1,
      createdAt: now(),
      updatedAt: now(),
    ));
    await vault.insertCategory(VaultCategory(
      name: '分类C',
      sortOrder: 2,
      createdAt: now(),
      updatedAt: now(),
    ));

    // 初始按 sort_order 排序
    expect(
      (await vault.getAllCategories()).map((c) => c.name).toList(),
      ['分类A', '分类B', '分类C'],
    );

    // 打乱顺序并批量持久化
    final reordered = await vault.getAllCategories();
    await vault.updateCategoriesOrder(
        [reordered[2], reordered[0], reordered[1]]);

    final after = await vault.getAllCategories();
    expect(after.map((c) => c.name).toList(), ['分类C', '分类A', '分类B']);
    expect(after.map((c) => c.sortOrder).toList(), [0, 1, 2]);
  });
}
