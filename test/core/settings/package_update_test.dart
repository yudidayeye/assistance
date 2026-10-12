import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:my_assistant/core/settings/update_service.dart';

String hash(List<int> bytes) => SHA256Digest()
    .process(Uint8List.fromList(bytes))
    .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
    .join();

void main() {
  group('同版本按平台构建检查', () {
    Future<UpdateInfo> check({
      String platform = 'android',
      int androidBuild = 43,
      int windowsBuild = 44,
      String currentBuild = '30042',
      bool inconsistent = false,
      int metadataStatus = 200,
      bool invalidMetadata = false,
    }) async {
      final digest = hash([1, 2, 3]);
      final packages = {
        'android': 'app-arm64-v8a-release.apk',
        'windows': 'my_assistant_setup_1.2.13.exe',
      };
      final release = {
        'tag_name': 'v1.2.13',
        'body': '完整发布说明',
        'assets': [
          for (final entry in packages.entries) ...[
            {
              'id': entry.key == 'android' ? 101 : 102,
              'name': entry.value,
              'size': inconsistent ? 2 : 3,
              'digest': 'sha256:$digest',
              'updated_at': '2026-10-12T01:02:03Z',
              'browser_download_url': 'https://example.com/${entry.value}',
            },
            {
              'id': entry.key == 'android' ? 201 : 202,
              'name': 'update-${entry.key}.json',
              'size': 200,
              'browser_download_url':
                  'https://example.com/update-${entry.key}.json',
            },
          ],
        ],
      };
      final requested = <String>[];
      final client = MockClient((request) async {
        requested.add(request.url.path);
        if (request.url.host == 'api.github.com') {
          return http.Response(jsonEncode(release), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        expect(request.url.queryParameters['revision'], isNotNull);
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'schema': invalidMetadata ? 2 : 1,
            'platform': platform,
            'version': '1.2.13',
            'build': platform == 'android' ? androidBuild : windowsBuild,
            'notes': '优化小功能',
            'files': [
              {'name': packages[platform], 'size': 3, 'sha256': digest}
            ],
          })),
          metadataStatus,
          headers: {'content-type': 'application/octet-stream'},
        );
      });
      final info = await UpdateService(
        client: client,
        platform: platform,
        supportedAbisLoader: () async => ['arm64-v8a'],
        packageInfoLoader: () async => PackageInfo(
          appName: '理解',
          packageName: 'example.app',
          version: '1.2.13',
          buildNumber: currentBuild,
        ),
      ).checkForUpdate();
      expect(requested, [
        '/repos/yudidayeye/assistance/releases/latest',
        '/update-$platform.json'
      ]);
      return info;
    }

    test('Android ABI 构建号归一化，同版本补发返回更新和中文说明', () async {
      final info = await check();
      expect(info.hasUpdate, isTrue);
      expect(info.isPackageUpdate, isTrue);
      expect(info.currentBuildNumber, 42);
      expect(info.latestBuildNumber, 43);
      expect(info.currentLabel, 'V1.2.13+42');
      expect(info.latestLabel, 'V1.2.13+43');
      expect(info.statusMessage, contains('同版本安装包更新'));
      expect(info.releaseNotes, '优化小功能');
      expect(info.packageUpdatedAt, DateTime.utc(2026, 10, 12, 1, 2, 3));
    });

    test('Windows 同版本补发可检查到', () async {
      final info = await check(platform: 'windows', currentBuild: '42');
      expect(info.hasUpdate, isTrue);
      expect(info.latestBuildNumber, 44);
    });

    test('只补 Windows 不影响 Android，同构建和旧构建都不提示更新', () async {
      for (final build in [41, 42]) {
        final info = await check(androidBuild: build, windowsBuild: 99);
        expect(info.hasUpdate, isFalse);
        expect(info.error, isNull);
      }
    });

    test('元数据和安装包不一致明确提示正在更新', () async {
      expect((await check(inconsistent: true)).error, contains('正在更新'));
    });

    test('元数据下载失败和格式错误不会显示已是最新版本', () async {
      expect((await check(metadataStatus: 503)).error, contains('HTTP 503'));
      expect((await check(invalidMetadata: true)).error, contains('格式异常'));
    });

    test('无法读出本机构建号明确提示', () async {
      expect((await check(currentBuild: '')).error, contains('构建号'));
    });
  });

  group('安装包缓存与完整性', () {
    late Directory dir;
    late HttpServer server;
    late List<int> response;
    late int requests;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('package-update-test-');
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      response = [1, 2, 3];
      requests = 0;
      server.listen((request) async {
        requests++;
        request.response.add(response);
        await request.response.close();
      });
    });
    tearDown(() async {
      await server.close(force: true);
      await dir.delete(recursive: true);
    });

    ReleaseAsset asset({int id = 101, int size = 3}) => ReleaseAsset(
          id: id,
          name: 'app-arm64-v8a-release.apk',
          size: size,
          sha256: hash([1, 2, 3]),
          downloadUrl: 'http://127.0.0.1:${server.port}/app.apk',
        );
    Future<String?> download(ReleaseAsset package) => UpdateService(
          downloadDirectoryLoader: () async => dir,
        ).downloadUpdate(asset: package, version: '1.2.13');

    test('同版本同大小旧包不复用，新包通过哈希后才复用', () async {
      final package = asset();
      final file = File(
          '${dir.path}/${UpdateService.downloadFileName(package, '1.2.13')}');
      await file.writeAsBytes([4, 5, 6]);
      expect(await download(package), file.path);
      expect(requests, 1);
      expect(await file.readAsBytes(), [1, 2, 3]);
      expect(await download(package), file.path);
      expect(requests, 1);
    });

    test('同版本资产替换后使用新的缓存路径', () {
      expect(UpdateService.downloadFileName(asset(id: 101), '1.2.13'),
          isNot(UpdateService.downloadFileName(asset(id: 102), '1.2.13')));
    });

    test('错误哈希的下载包删除并提示校验失败', () async {
      response = [4, 5, 6];
      await expectLater(download(asset()), throwsA(isA<UpdateException>()));
      expect(dir.listSync(), isEmpty);
    });

    test('未知大小仍可下载，使用哈希验证', () async {
      expect(await download(asset(size: 0)), isNotNull);
    });
  });
}
