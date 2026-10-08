import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_assistant/core/storage/database_service.dart';
import 'package:my_assistant/core/theme/app_theme.dart';
import 'package:my_assistant/core/theme/theme_provider.dart';
import 'package:my_assistant/modules/vault/pages/vault_entry_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// ⚠️ 本文件必须用 `tester.runAsync` 驱动所有真实 IO，否则会**挂死**。
///
/// `testWidgets` 的测试体跑在 FakeAsync 时区里：sqflite 的调用要等真实事件循环
/// （ffi 后端走独立 isolate 收发消息）才会完成，而 FakeAsync 只推进假时钟。
/// 两者不交汇 → `await prepareDb()` 永不返回，表现为 `did not complete [E]`
/// 直到 pumpAndSettle 那 10 分钟默认超时（实测卡死 2 分钟以上仍无输出）。
///
/// 正确姿势是**交替推进**：`pump` 排空假时区的微任务，`runAsync` 让真实 IO 前进。
/// 见下方 `_settleRealIo`。改这个文件时请勿退回裸 `pumpAndSettle`。
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

  /// 交替推进假时钟与真实事件循环，直到 [until] 出现（或轮次用尽）
  Future<void> settleRealIo(WidgetTester tester, Finder until,
      {int rounds = 20}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (until.evaluate().isNotEmpty) return;
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
  }

  /// 推进若干帧，让弹窗的入场动画走完
  Future<void> pumpFrames(WidgetTester tester, {int frames = 8}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('新增分类弹窗：紧凑图标网格可打开并可选中图标', (tester) async {
    await tester.runAsync(prepareDb);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.getTheme(AppThemeType.softNight),
        home: const Scaffold(body: VaultEntryPage()),
      ),
    );
    // 等 initState 里的真实 DB 读取返回（_loading 置 false、FAB 出现）
    await settleRealIo(tester, find.byIcon(Icons.add_rounded));
    await pumpFrames(tester);

    // 打开新增分类弹窗（FAB）
    await tester.tap(find.byIcon(Icons.add_rounded));
    await pumpFrames(tester);

    // 弹窗简洁：标题 + 分组网格
    expect(find.text('选择图标'), findsOneWidget);
    expect(find.text('常用'), findsWidgets); // 分组标题
    expect(find.text('技术开发'), findsWidgets);

    // 图标以紧凑 tile 展示（纯图标，无 Tooltip 悬浮提示）
    expect(find.byTooltip('文件夹'), findsNothing);
    expect(find.byIcon(Icons.dns_rounded), findsOneWidget); // 服务器
    expect(find.byIcon(Icons.folder_rounded), findsWidgets); // 常用-文件夹（含实时预览）

    // 点击图标选择，弹窗不应崩溃、标题保持
    //
    // 服务器图标在 160px 高的分组滚动区内，初始不可见：直接 tap 会因未命中
    // 而**空点**（只报 warnIfMissed 警告，断言照样过），等于没测。先滚到可见。
    await tester.ensureVisible(find.byIcon(Icons.dns_rounded));
    await pumpFrames(tester);
    await tester.tap(find.byIcon(Icons.dns_rounded));
    await pumpFrames(tester);
    expect(find.text('选择图标'), findsOneWidget);
    // 选中已生效：实时预览也跟着换成服务器图标（网格 + 预览 = 2）
    expect(find.byIcon(Icons.dns_rounded), findsNWidgets(2));
  });
}
