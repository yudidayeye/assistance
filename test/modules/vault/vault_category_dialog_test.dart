import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_assistant/core/storage/database_service.dart';
import 'package:my_assistant/core/theme/app_theme.dart';
import 'package:my_assistant/core/theme/theme_provider.dart';
import 'package:my_assistant/modules/vault/pages/vault_entry_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    if (Platform.isWindows) {
      DynamicLibrary.open(r'windows\runner\sqlite3.dll');
    }
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database testDb;

  /// 准备已设置主密码、且无任何分类的数据库
  Future<void> prepareDb() async {
    testDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    DatabaseService.instance.useDatabaseForTesting(testDb);
    await DatabaseService.instance.createSchemaForTesting(testDb);
    await testDb.insert('mod_vault_master', {
      'id': 1,
      'salt': 'salt',
      'verify_cipher': 'cipher',
      'verify_iv': 'iv',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  testWidgets('新增分类弹窗：紧凑图标网格可打开并可选中图标', (tester) async {
    await prepareDb();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.getTheme(AppThemeType.softNight),
        home: const Scaffold(body: VaultEntryPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 打开新增分类弹窗（FAB）
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    // 弹窗简洁：标题 + 分组网格
    expect(find.text('选择图标'), findsOneWidget);
    expect(find.text('常用'), findsWidgets); // 分组标题
    expect(find.text('技术开发'), findsWidgets);

    // 图标以紧凑 tile 展示（纯图标，无 Tooltip 悬浮提示）
    expect(find.byTooltip('文件夹'), findsNothing);
    expect(find.byIcon(Icons.dns_rounded), findsOneWidget); // 服务器
    expect(find.byIcon(Icons.folder_rounded), findsWidgets); // 常用-文件夹（含实时预览）

    // 点击图标选择，弹窗不应崩溃、标题保持
    await tester.tap(find.byIcon(Icons.dns_rounded));
    await tester.pumpAndSettle();
    expect(find.text('选择图标'), findsOneWidget);
  });
}