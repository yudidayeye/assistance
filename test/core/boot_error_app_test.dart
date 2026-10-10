import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_assistant/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('启动错误页复制诊断信息到剪贴板', (tester) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        calls.add(call);
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      BootErrorApp(
        error: StateError('clipboard error'),
        stackTrace: StackTrace.fromString('clipboard stack'),
        args: const [],
        bootloader: (_) async => throw StateError('unused'),
      ),
    );
    await tester.tap(find.text('复制诊断信息'));
    await tester.pump();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'Clipboard.setData');
    expect(calls.single.arguments['text'], contains('clipboard error'));
    expect(calls.single.arguments['text'], contains('clipboard stack'));
  });

  testWidgets('启动错误页无需业务依赖即可渲染诊断信息', (tester) async {
    await tester.pumpWidget(
      BootErrorApp(
        error: StateError('database failed'),
        stackTrace: StackTrace.fromString('stack trace'),
        args: const [],
        bootloader: (_) async => throw StateError('unused'),
      ),
    );

    expect(find.text('应用启动失败'), findsOneWidget);
    expect(find.textContaining('database failed'), findsOneWidget);
    expect(find.textContaining('stack trace'), findsOneWidget);
    expect(find.text('复制诊断信息'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('重试失败时更新诊断信息', (tester) async {
    await tester.pumpWidget(
      BootErrorApp(
        error: StateError('first failure'),
        stackTrace: StackTrace.fromString('first stack'),
        args: const [],
        bootloader: (_) async => throw StateError('retry failure'),
      ),
    );

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.textContaining('retry failure'), findsOneWidget);
    expect(find.textContaining('first failure'), findsNothing);
  });

  testWidgets('重试成功后切换到主应用', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const SizedBox.shrink()),
      ],
    );

    await tester.pumpWidget(
      BootErrorApp(
        error: StateError('first failure'),
        stackTrace: StackTrace.fromString('first stack'),
        args: const [],
        bootloader: (_) async => router,
      ),
    );

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.byType(ToolboxApp), findsOneWidget);
  });
}
