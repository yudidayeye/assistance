import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:my_assistant/core/settings/update_service.dart';

/// 构造与真实 GitHub Release 一致的产物列表
List<ReleaseAsset> _realReleaseAssets() => const [
      ReleaseAsset(
        name: 'app-arm64-v8a-release.apk',
        downloadUrl: 'https://example.com/app-arm64-v8a-release.apk',
        size: 20115189,
      ),
      ReleaseAsset(
        name: 'app-armeabi-v7a-release.apk',
        downloadUrl: 'https://example.com/app-armeabi-v7a-release.apk',
        size: 17822599,
      ),
      ReleaseAsset(
        name: 'app-x86_64-release.apk',
        downloadUrl: 'https://example.com/app-x86_64-release.apk',
        size: 21572548,
      ),
    ];

void main() {
  group('UpdateService.checkForUpdate', () {
    Future<PackageInfo> localVersion() async => PackageInfo(
          appName: '理解',
          packageName: 'example.app',
          version: '1.2.9',
          buildNumber: '38',
        );

    UpdateService service(
      Future<http.Response> Function(http.Request) handler,
    ) =>
        UpdateService(
          client: MockClient(handler),
          packageInfoLoader: localVersion,
          checkTimeout: const Duration(milliseconds: 50),
        );

    test('同版本明确返回无更新，保留最新版本信息', () async {
      final info = await service((_) async =>
              http.Response('{"tag_name":"v1.2.9","assets":[]}', 200))
          .checkForUpdate();
      expect(info.hasUpdate, isFalse);
      expect(info.latestVersion, '1.2.9');
      expect(info.error, isNull);
    });

    test('新版本保留更新信息和安装包', () async {
      final info = await service((_) async => http.Response(
          '{"tag_name":"v1.2.10","assets":[{"name":"app.apk",'
          '"browser_download_url":"https://example.com/app.apk","size":10}]}',
          200)).checkForUpdate();
      expect(info.hasUpdate, isTrue);
      expect(info.assets.single.name, 'app.apk');
      expect(info.error, isNull);
    });

    for (final status in [403, 404, 429, 500, 502, 401]) {
      test('HTTP $status 提示原因，不伪装为最新版本', () async {
        final info = await service((_) async => http.Response('', status))
            .checkForUpdate();
        expect(info.hasUpdate, isFalse);
        expect(info.error, contains('$status'));
        expect(info.latestVersion, isNull);
      });
    }

    test('403 限流与普通拒绝访问区分', () async {
      final info = await service((_) async =>
              http.Response('', 403, headers: {'x-ratelimit-remaining': '0'}))
          .checkForUpdate();
      expect(info.error, contains('请求次数已达上限'));
    });

    test('请求无响应时有超时提示', () async {
      final info = await service((_) => Completer<http.Response>().future)
          .checkForUpdate();
      expect(info.error, contains('超时'));
    });

    test('网络连接失败给出网络及代理建议', () async {
      final info =
          await service((_) async => throw http.ClientException('offline'))
              .checkForUpdate();
      expect(info.error, contains('无法连接 GitHub'));
    });

    test('TLS 错误提示检查设备时间', () async {
      final info = await service((_) async => throw const HandshakeException())
          .checkForUpdate();
      expect(info.error, contains('设备时间'));
    });

    for (final body in [
      'invalid json',
      '[]',
      '{"tag_name":"preview"}',
      '{}',
      '{"tag_name":123}'
    ]) {
      test('无效响应 $body 提示格式异常', () async {
        final info = await service((_) async => http.Response(body, 200))
            .checkForUpdate();
        expect(info.error, contains('格式异常'));
      });
    }

    test('读取本地版本异常不会向页面抛出', () async {
      final info = await UpdateService(
        packageInfoLoader: () async => throw StateError('unavailable'),
      ).checkForUpdate();
      expect(info.error, contains('无法读取当前应用版本'));
    });

    test('读取本地版本卡住时有界返回', () async {
      final info = await UpdateService(
        packageInfoLoader: () => Completer<PackageInfo>().future,
        checkTimeout: const Duration(milliseconds: 10),
      ).checkForUpdate();
      expect(info.error, contains('无法读取当前应用版本'));
    });
  });

  group('UpdateService.selectAsset', () {
    test('arm64 设备优先命中 arm64-v8a', () {
      final asset = UpdateService.selectAsset(
        _realReleaseAssets(),
        const ['arm64-v8a', 'armeabi-v7a', 'armeabi'],
      );
      expect(asset, isNotNull);
      expect(asset!.name, 'app-arm64-v8a-release.apk');
    });

    test('32 位 arm 设备命中 armeabi-v7a', () {
      final asset = UpdateService.selectAsset(
        _realReleaseAssets(),
        const ['armeabi-v7a', 'armeabi'],
      );
      expect(asset, isNotNull);
      expect(asset!.name, 'app-armeabi-v7a-release.apk');
    });

    test('x86_64 模拟器命中 x86_64', () {
      final asset = UpdateService.selectAsset(
        _realReleaseAssets(),
        const ['x86_64', 'arm64-v8a', 'x86', 'armeabi-v7a', 'armeabi'],
      );
      expect(asset, isNotNull);
      expect(asset!.name, 'app-x86_64-release.apk');
    });

    test('空产物列表返回 null（降级跳浏览器）', () {
      expect(
        UpdateService.selectAsset(const [], const ['arm64-v8a']),
        isNull,
      );
    });

    test('无 APK 产物返回 null', () {
      const assets = [
        ReleaseAsset(
          name: 'source-code.tar.gz',
          downloadUrl: 'https://example.com/source-code.tar.gz',
          size: 1024,
        ),
      ];
      expect(
        UpdateService.selectAsset(assets, const ['arm64-v8a']),
        isNull,
      );
    });

    test('长令牌优先：armeabi 设备不误配 armeabi-v7a 包', () {
      const assets = [
        ReleaseAsset(
          name: 'app-armeabi-v7a-release.apk',
          downloadUrl: 'https://example.com/app-armeabi-v7a-release.apk',
          size: 17822599,
        ),
      ];
      // 仅支持 armeabi 的古老设备不应在 L1 误命中 v7a 包
      expect(
        UpdateService.selectAsset(assets, const ['armeabi']),
        isNull,
      );
    });

    test('设备不支持任何可用架构时返回 null', () {
      const assets = [
        ReleaseAsset(
          name: 'app-x86_64-release.apk',
          downloadUrl: 'https://example.com/app-x86_64-release.apk',
          size: 21572548,
        ),
      ];
      expect(
        UpdateService.selectAsset(assets, const ['arm64-v8a', 'armeabi-v7a']),
        isNull,
      );
    });

    test('无精确 ABI 包时回退 universal 包', () {
      const assets = [
        ReleaseAsset(
          name: 'app-universal-release.apk',
          downloadUrl: 'https://example.com/app-universal-release.apk',
          size: 30000000,
        ),
      ];
      final asset = UpdateService.selectAsset(assets, const ['arm64-v8a']);
      expect(asset, isNotNull);
      expect(asset!.name, 'app-universal-release.apk');
    });

    test('无架构标识的 APK 作为兜底', () {
      const assets = [
        ReleaseAsset(
          name: 'my-assistant-release.apk',
          downloadUrl: 'https://example.com/my-assistant-release.apk',
          size: 30000000,
        ),
      ];
      final asset = UpdateService.selectAsset(assets, const ['arm64-v8a']);
      expect(asset, isNotNull);
      expect(asset!.name, 'my-assistant-release.apk');
    });

    test('忽略大小写匹配', () {
      const assets = [
        ReleaseAsset(
          name: 'App-ARM64-V8A-Release.APK',
          downloadUrl: 'https://example.com/a.apk',
          size: 100,
        ),
      ];
      final asset = UpdateService.selectAsset(assets, const ['arm64-v8a']);
      expect(asset, isNotNull);
    });

    test('ABI 顺序优先：设备首选 ABI 先命中', () {
      final asset = UpdateService.selectAsset(
        _realReleaseAssets(),
        const ['armeabi-v7a', 'arm64-v8a'],
      );
      expect(asset!.name, 'app-armeabi-v7a-release.apk');
    });
    group('UpdateService.selectWindowsAsset', () {
      const windowsAssets = [
        ReleaseAsset(
          name: 'my_assistant_setup_1.2.1.exe',
          downloadUrl: 'https://example.com/my_assistant_setup_1.2.1.exe',
          size: 60000000,
        ),
        ReleaseAsset(
          name: 'my_assistant-debug.exe',
          downloadUrl: 'https://example.com/my_assistant-debug.exe',
          size: 10000000,
        ),
        ReleaseAsset(
          name: 'source-code.tar.gz',
          downloadUrl: 'https://example.com/source-code.tar.gz',
          size: 1024,
        ),
      ];

      test('优先匹配 setup 命名的 exe 安装包', () {
        final asset = UpdateService.selectWindowsAsset(windowsAssets);
        expect(asset, isNotNull);
        expect(asset!.name, endsWith('.exe'));
        expect(asset.name, contains('setup'));
      });

      test('忽略 debug 等非安装产物', () {
        const assets = [
          ReleaseAsset(
            name: 'my-assistant-debug.exe',
            downloadUrl: 'https://example.com/debug.exe',
            size: 10000000,
          ),
        ];
        expect(UpdateService.selectWindowsAsset(assets), isNull);
      });

      test('多个候选时取体积最大的', () {
        const assets = [
          ReleaseAsset(
            name: 'a.exe',
            downloadUrl: 'https://example.com/a.exe',
            size: 100,
          ),
          ReleaseAsset(
            name: 'b.exe',
            downloadUrl: 'https://example.com/b.exe',
            size: 200,
          ),
        ];
        final asset = UpdateService.selectWindowsAsset(assets);
        expect(asset, isNotNull);
        expect(asset!.name, 'b.exe');
      });

      test('无 exe 资产返回 null', () {
        const assets = [
          ReleaseAsset(
            name: 'app-release.apk',
            downloadUrl: 'https://example.com/app.apk',
            size: 100,
          ),
        ];
        expect(UpdateService.selectWindowsAsset(assets), isNull);
      });

      test('空资产返回 null', () {
        expect(UpdateService.selectWindowsAsset(const []), isNull);
      });
    });
  });
}
