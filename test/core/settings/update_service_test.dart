import 'package:flutter_test/flutter_test.dart';
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
        name: 'my_assistant_setup_1.2.1.msi',
        downloadUrl: 'https://example.com/my_assistant_setup_1.2.1.msi',
        size: 55000000,
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

    test('支持 msi 安装包（无 setup 命名时）', () {
      const assets = [
        ReleaseAsset(
          name: 'my-assistant.msi',
          downloadUrl: 'https://example.com/my-assistant.msi',
          size: 50000000,
        ),
      ];
      final asset = UpdateService.selectWindowsAsset(assets);
      expect(asset, isNotNull);
      expect(asset!.name, 'my-assistant.msi');
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

    test('无 exe/msi 资产返回 null', () {
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
