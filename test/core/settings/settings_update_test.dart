import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:my_assistant/core/settings/settings_page.dart';
import 'package:my_assistant/core/settings/update_service.dart';
import 'package:my_assistant/core/theme/theme_provider.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: '理解',
      packageName: 'example.app',
      version: '1.2.10',
      buildNumber: '39',
      buildSignature: '',
    );
  });

  Future<void> showSettings(WidgetTester tester, UpdateService service) async {
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeProvider.instance.themeData,
      home: SettingsPage(updateService: service),
    ));
  }

  testWidgets('点击版本可离线展示应用版本和构建号，不触发更新检查', (tester) async {
    var calls = 0;
    final service = UpdateService(client: MockClient((_) async {
      calls++;
      return http.Response('', 403);
    }));
    await showSettings(tester, service);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('版本'));
    await tester.tap(find.text('版本'));
    await tester.pumpAndSettle();
    expect(find.text('当前版本信息'), findsOneWidget);
    expect(find.textContaining('版本：1.2.10'), findsOneWidget);
    expect(find.textContaining('构建号：39'), findsOneWidget);
    expect(find.textContaining('应用包名：example.app'), findsOneWidget);
    expect(calls, 1);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(find.text('当前版本信息'), findsNothing);
  });

  testWidgets('自动检查失败可见，手动重试显示检查中和最新版本提示', (tester) async {
    var calls = 0;
    final response = Completer<http.Response>();
    final service = UpdateService(client: MockClient((_) async {
      calls++;
      if (calls == 1) return http.Response('', 403);
      return response.future;
    }));
    await showSettings(tester, service);
    await tester.pumpAndSettle();
    expect(find.textContaining('GitHub 拒绝访问（403）'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    await tester.ensureVisible(find.text('检查更新'));
    final versionHeight = tester
        .getSize(
            find.ancestor(of: find.text('版本'), matching: find.byType(Row)).last)
        .height;
    await tester.tap(find.text('检查更新'));
    await tester.pump();
    expect(
        tester
            .getSize(find
                .ancestor(of: find.text('版本'), matching: find.byType(Row))
                .last)
            .height,
        versionHeight);
    expect(find.byTooltip('正在检查更新…'), findsOneWidget);
    expect(find.textContaining('GitHub 拒绝访问'), findsNothing);
    expect(find.text('检查更新'), findsNothing);
    response.complete(http.Response('{"tag_name":"v1.2.10","assets":[]}', 200));
    await tester.pumpAndSettle();
    expect(find.text('当前已是最新版本'), findsNothing);
    expect(find.text('当前已是最新版本（V1.2.10）'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手动网络失败显示错误提示且恢复重试按钮', (tester) async {
    var calls = 0;
    final service = UpdateService(client: MockClient((_) async {
      calls++;
      if (calls == 1) return http.Response('{"tag_name":"v1.2.10"}', 200);
      throw http.ClientException('offline');
    }));
    await showSettings(tester, service);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('检查更新'));
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('无法连接 GitHub'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('当前已是最新版本'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
