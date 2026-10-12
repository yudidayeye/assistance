import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:pointycastle/digests/sha256.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

/// 更新检查服务
///
/// 查询 GitHub Release 获取最新版本，与当前应用版本比较；
/// 支持按设备 CPU 架构匹配 APK、应用内下载与唤起系统安装器。
class UpdateService {
  UpdateService({
    http.Client? client,
    Future<PackageInfo> Function()? packageInfoLoader,
    Duration checkTimeout = const Duration(seconds: 10),
    String? platform,
    Future<List<String>> Function()? supportedAbisLoader,
    Future<Directory> Function()? downloadDirectoryLoader,
  })  : _client = client,
        _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
        _checkTimeout = checkTimeout,
        _platform = platform ??
            (Platform.isAndroid
                ? 'android'
                : Platform.isWindows
                    ? 'windows'
                    : 'other'),
        _supportedAbisLoader = supportedAbisLoader,
        _downloadDirectoryLoader = downloadDirectoryLoader;

  static final instance = UpdateService();
  final http.Client? _client;
  final Future<PackageInfo> Function() _packageInfoLoader;
  final Duration _checkTimeout;
  final String _platform;
  final Future<List<String>> Function()? _supportedAbisLoader;
  final Future<Directory> Function()? _downloadDirectoryLoader;

  /// GitHub 仓库信息
  static const _owner = 'yudidayeye';
  static const _repo = 'assistance';

  /// 下载用 Dio 实例（放宽超时：GitHub 下载波动大，
  /// receiveTimeout 限制的是数据块之间的最大间隔）
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
    ),
  );

  /// 已知的 ABI 标识（长令牌在前，用于排除前缀误配）
  static const List<String> _knownAbiTokens = [
    'arm64-v8a',
    'armeabi-v7a',
    'x86_64',
    'armeabi',
    'x86',
  ];

  /// 检查更新
  ///
  /// 返回 [UpdateInfo]，包含是否有更新、当前版本、最新版本、产物列表等信息。
  Future<UpdateInfo> checkForUpdate() async {
    String currentVersion;
    int? currentBuild;
    try {
      final packageInfo = await _packageInfoLoader().timeout(_checkTimeout);
      currentVersion = packageInfo.version;
      currentBuild = normalizeBuildNumber(packageInfo.buildNumber, _platform);
      if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(currentVersion)) {
        throw const FormatException('Invalid local version');
      }
    } catch (_) {
      return const UpdateInfo(
        hasUpdate: false,
        currentVersion: '',
        error: '无法读取当前应用版本，请重启应用后重试',
      );
    }

    UpdateInfo failure(String message) => UpdateInfo(
          hasUpdate: false,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuild,
          error: message,
        );
    try {
      final url = Uri.parse(
        'https://api.github.com/repos/$_owner/$_repo/releases/latest',
      ).replace(queryParameters: {
        'check': '${DateTime.now().millisecondsSinceEpoch}'
      });
      final response =
          await (_client?.get(url) ?? http.get(url)).timeout(_checkTimeout);
      if (response.statusCode != 200) {
        final code = response.statusCode;
        if (code == 429 ||
            (code == 403 && response.headers['x-ratelimit-remaining'] == '0')) {
          return failure('GitHub 请求次数已达上限（$code），请稍后重试或切换网络');
        }
        if (code == 404) {
          return failure('未找到已发布版本（404），请前往 GitHub 发布页确认');
        }
        if (code == 403) {
          return failure('GitHub 拒绝访问（403），请检查网络或代理设置后重试');
        }
        if (code >= 500) {
          return failure('GitHub 服务暂时不可用（$code），请稍后重试');
        }
        return failure('检查更新失败（HTTP $code），请稍后重试');
      }

      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final tagName = json['tag_name'] as String? ?? '';
      final remoteVersion = tagName.replaceFirst(RegExp(r'^[vV]'), '');
      if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(remoteVersion)) {
        throw const FormatException('Invalid release version');
      }
      final assets = _parseAssets(json['assets']);
      int? latestBuild;
      var notes = json['body'] as String? ?? '';
      DateTime? packageUpdatedAt;
      final metadataAssets =
          assets.where((asset) => asset.name == 'update-$_platform.json');
      if (metadataAssets.isNotEmpty) {
        final metadataAsset = metadataAssets.first;
        final metadataUrl = Uri.parse(metadataAsset.downloadUrl);
        final requestUrl = metadataUrl.replace(queryParameters: {
          ...metadataUrl.queryParameters,
          'revision':
              '${metadataAsset.id ?? metadataAsset.updatedAt?.millisecondsSinceEpoch ?? metadataAsset.size}',
        });
        final metadataResponse =
            await (_client?.get(requestUrl) ?? http.get(requestUrl))
                .timeout(_checkTimeout);
        if (metadataResponse.statusCode != 200) {
          throw UpdateException(
              '安装包更新信息读取失败（HTTP ${metadataResponse.statusCode}），请稍后重试');
        }
        final metadata = jsonDecode(utf8.decode(metadataResponse.bodyBytes))
            as Map<String, dynamic>;
        if (metadata['schema'] != 1 ||
            metadata['platform'] != _platform ||
            metadata['version'] != remoteVersion) {
          throw const FormatException('Invalid package metadata');
        }
        latestBuild = metadata['build'] as int;
        if (latestBuild < 1 || latestBuild > 999) {
          throw const FormatException('Invalid build number');
        }
        final files = metadata['files'] as List;
        for (final raw in files) {
          final file = raw as Map<String, dynamic>;
          final name = file['name'] as String;
          final expected = file['sha256'] as String;
          if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(expected)) {
            throw const FormatException('Invalid digest');
          }
          final index = assets.indexWhere((asset) => asset.name == name);
          if (index < 0 ||
              assets[index].size != file['size'] ||
              (assets[index].sha256 != null &&
                  assets[index].sha256 != expected)) {
            throw const UpdateException('安装包正在更新，请稍后重新检查');
          }
          assets[index] = assets[index].withDigest(expected);
        }
        final selected = _platform == 'android'
            ? selectAsset(
                assets,
                await (_supportedAbisLoader?.call() ?? getSupportedAbis())
                    .timeout(_checkTimeout))
            : selectWindowsAsset(assets);
        if (selected == null ||
            !files.any((file) => file['name'] == selected.name)) {
          throw const UpdateException('未找到适合当前设备的安装包，请前往发布页确认');
        }
        packageUpdatedAt = selected.updatedAt;
        final packageNotes = metadata['notes'] as String? ?? '';
        if (packageNotes.isNotEmpty) notes = packageNotes;
        if (currentBuild == null) {
          throw const UpdateException('无法读取当前安装包构建号，请重启应用后重试');
        }
      }
      final comparison = _compareVersions(currentVersion, remoteVersion);
      return UpdateInfo(
        hasUpdate: comparison < 0 ||
            (comparison == 0 &&
                latestBuild != null &&
                currentBuild != null &&
                latestBuild > currentBuild),
        currentVersion: currentVersion,
        currentBuildNumber: currentBuild,
        latestVersion: remoteVersion,
        latestBuildNumber: latestBuild,
        packageUpdatedAt: packageUpdatedAt,
        releaseName: json['name'] as String? ?? '',
        releaseUrl: json['html_url'] as String? ?? '',
        releaseNotes: notes,
        assets: assets,
      );
    } on UpdateException catch (error) {
      return failure(error.message);
    } on TimeoutException {
      return failure('检查更新超时，请检查网络或代理设置后重试');
    } on HandshakeException {
      return failure('安全连接失败，请检查设备时间、网络或代理设置');
    } on SocketException {
      return failure('无法连接 GitHub，请检查网络或代理设置后重试');
    } on http.ClientException {
      return failure('无法连接 GitHub，请检查网络或代理设置后重试');
    } on FormatException {
      return failure('GitHub 返回的版本信息格式异常，请稍后重试');
    } on TypeError {
      return failure('GitHub 返回的版本信息格式异常，请稍后重试');
    } catch (_) {
      return failure('检查更新失败，请稍后重试');
    }
  }

  /// 解析 Release 产物列表
  List<ReleaseAsset> _parseAssets(dynamic raw) {
    if (raw is! List) return const [];
    final result = <ReleaseAsset>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final name = (item['name'] as String?) ?? '';
      final downloadUrl = (item['browser_download_url'] as String?) ?? '';
      if (name.isEmpty || downloadUrl.isEmpty) continue;
      result.add(ReleaseAsset(
        name: name,
        downloadUrl: downloadUrl,
        size: (item['size'] as num?)?.toInt() ?? 0,
        id: (item['id'] as num?)?.toInt(),
        sha256: parseDigest(item['digest'] as String?),
        updatedAt: DateTime.tryParse(item['updated_at'] as String? ?? ''),
      ));
    }
    return result;
  }

  static int? normalizeBuildNumber(String raw, String platform) {
    final value = int.tryParse(raw);
    if (value == null || value < 0) return null;
    return platform == 'android' ? value % 1000 : value;
  }

  static String? parseDigest(String? raw) {
    if (raw == null || !RegExp(r'^sha256:[a-f0-9]{64}$').hasMatch(raw)) {
      return null;
    }
    return raw.substring(7);
  }

  static String downloadFileName(ReleaseAsset asset, String version) {
    final identity = asset.id?.toString() ?? asset.sha256 ?? 'legacy';
    return 'update_v${version}_$identity${p.extension(asset.name).toLowerCase()}';
  }

  Future<bool> _isComplete(File target, ReleaseAsset asset,
      {bool allowUnknownSize = false}) async {
    if (!await target.exists()) return false;
    final length = await target.length();
    if (length == 0 || (asset.size > 0 && length != asset.size)) return false;
    if (asset.sha256 == null) return asset.size > 0 || allowUnknownSize;
    final digest = SHA256Digest();
    await for (final bytes in target.openRead()) {
      digest.update(bytes is Uint8List ? bytes : Uint8List.fromList(bytes), 0,
          bytes.length);
    }
    final result = Uint8List(32);
    digest.doFinal(result, 0);
    return result
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join() ==
        asset.sha256;
  }

  /// 按设备架构匹配最合适的 APK（纯函数，便于单元测试）
  ///
  /// [supportedAbis] 为设备支持的 ABI 优先级列表（如
  /// `['arm64-v8a', 'armeabi-v7a', 'armeabi']`），按顺序匹配：
  /// L1 精确 ABI → L2 universal 包 → L3 无架构标识 apk → null。
  /// 返回 null 表示没有可信的匹配（宁可降级跳浏览器，也不下载可能不兼容的包），
  /// 调用方应降级为跳转 Release 页面。
  static ReleaseAsset? selectAsset(
    List<ReleaseAsset> assets,
    List<String> supportedAbis,
  ) {
    final apks =
        assets.where((a) => a.name.toLowerCase().endsWith('.apk')).toList();
    if (apks.isEmpty) return null;

    // L1：按设备 ABI 优先级顺序匹配（arm64 设备优先命中 arm64-v8a）
    for (final abi in supportedAbis) {
      final target = abi.toLowerCase();
      for (final asset in apks) {
        if (_fileNameMatchesAbi(asset.name, target)) return asset;
      }
    }

    // L2：universal 通用包
    for (final asset in apks) {
      if (asset.name.toLowerCase().contains('universal')) return asset;
    }

    // L3：无架构标识的 APK（release 结构变化时的保险）
    for (final asset in apks) {
      final name = asset.name.toLowerCase();
      if (!_knownAbiTokens.any(name.contains)) return asset;
    }

    // 其余 APK 均带有与设备不匹配的架构标识，下载也装不上，
    // 返回 null 让调用方降级为跳转 Release 页面手动选择。
    return null;
  }

  /// 判断 APK 文件名是否匹配指定 ABI
  ///
  /// 排除长令牌误配：`armeabi` 不应命中 `app-armeabi-v7a-release.apk`。
  static bool _fileNameMatchesAbi(String fileName, String abi) {
    final name = fileName.toLowerCase();
    if (!name.contains(abi)) return false;
    return !_knownAbiTokens.any((other) =>
        other != abi &&
        other.length > abi.length &&
        other.contains(abi) &&
        name.contains(other));
  }

  /// 获取设备支持的 ABI 列表（按优先级排序）
  /// 挑选最适合 Windows 桌面的安装包（纯函数，便于单元测试）
  ///
  /// 匹配规则：
  /// - 仅考虑扩展名为 .exe 的安装包
  /// - 优先名称含 setup / installer 的安装包
  /// - 忽略调试符号等非安装产物（如含 debug / symbols / pdb）
  /// - 多个候选时取体积最大的（安装包通常最大且最完整）
  /// 返回 null 表示没有可用的 Windows 安装包。
  static ReleaseAsset? selectWindowsAsset(List<ReleaseAsset> assets) {
    final candidates = assets.where((a) {
      final name = a.name.toLowerCase();
      return name.endsWith('.exe') &&
          !name.contains('debug') &&
          !name.contains('symbols') &&
          !name.contains('.pdb');
    }).toList();
    if (candidates.isEmpty) return null;

    final preferred = candidates.where((a) {
      final name = a.name.toLowerCase();
      return name.contains('setup') || name.contains('installer');
    }).toList();
    final pool = preferred.isNotEmpty ? preferred : candidates;

    pool.sort((a, b) => b.size.compareTo(a.size));
    return pool.first;
  }

  Future<List<String>> getSupportedAbis() async {
    if (!Platform.isAndroid) return const [];
    final info = await DeviceInfoPlugin().androidInfo;
    return info.supportedAbis;
  }

  /// 下载更新安装包到本地，返回本地路径；用户取消时返回 null
  ///
  /// [onProgress] 的 total 在服务端未返回 Content-Length 时回退为 asset.size。
  /// 已存在且大小、哈希一致的当前安装包会被直接复用。
  Future<String?> downloadUpdate({
    required ReleaseAsset asset,
    required String version,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await _getDownloadDir();
    final savePath = p.join(dir.path, downloadFileName(asset, version));
    final target = File(savePath);

    // 已存在完整安装包则直接复用
    if (await _isComplete(target, asset)) {
      onProgress?.call(asset.size, asset.size);
      return savePath;
    }

    // 清理历史残留更新包（含上次未完成的部分文件）
    _cleanupUpdateFiles(dir);

    const maxAttempts = 2; // 首次 + 1 次重试
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await _dio.download(
          asset.downloadUrl,
          savePath,
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            onProgress?.call(received, total > 0 ? total : asset.size);
          },
        );

        // 下载完成后校验大小和可用的 SHA-256，避免同版本旧包被复用
        if (!await _isComplete(target, asset, allowUnknownSize: true)) {
          await _deleteQuietly(target);
          throw const UpdateException('安装包校验失败，请重新下载');
        }
        return savePath;
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) {
          await _deleteQuietly(target);
          return null; // 用户主动取消，不视为失败
        }
        lastError = e;
        // 404/403 等响应错误没有重试价值
        if (e.type == DioExceptionType.badResponse) break;
      } on UpdateException {
        rethrow;
      } on FileSystemException catch (e) {
        throw UpdateException(
          '文件写入失败，存储空间可能不足'
          '${e.osError?.message != null ? '（${e.osError!.message}）' : ''}',
        );
      }
    }
    throw _mapDownloadError(lastError);
  }

  /// 获取本次更新下载的存储目录（按平台选择）
  Future<Directory> _getDownloadDir() async {
    final loader = _downloadDirectoryLoader;
    if (loader != null) return loader();
    if (Platform.isAndroid) {
      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        throw const UpdateException('无法访问应用存储目录');
      }
      return dir;
    }
    // Windows / 其他桌面平台：应用支持目录
    final dir = await getApplicationSupportDirectory();
    return dir;
  }

  void _cleanupUpdateFiles(Directory dir) {
    try {
      for (final entity in dir.listSync()) {
        final name = p.basename(entity.path);
        if (entity is File &&
            name.startsWith('update_') &&
            (name.endsWith('.apk') || name.endsWith('.exe'))) {
          entity.deleteSync();
        }
      }
    } catch (_) {
      // 清理失败不阻断下载流程
    }
  }

  /// 静默删除文件
  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// 将下载异常映射为面向用户的提示
  UpdateException _mapDownloadError(Object? error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
          return const UpdateException('网络连接超时，请检查网络后重试');
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.transformTimeout:
          return const UpdateException('下载超时，请稍后重试');
        case DioExceptionType.connectionError:
          return const UpdateException('网络连接失败，请检查网络后重试');
        case DioExceptionType.badResponse:
          final code = error.response?.statusCode;
          return UpdateException(
            code == null ? '下载失败，请稍后重试' : '下载失败（$code），可前往 GitHub 发布页手动下载',
          );
        case DioExceptionType.cancel:
          return const UpdateException('下载已取消');
        case DioExceptionType.badCertificate:
          return const UpdateException('证书校验失败，请检查网络环境');
        case DioExceptionType.unknown:
          return const UpdateException('下载失败，请检查网络后重试');
      }
    }
    return const UpdateException('下载失败，请稍后重试');
  }

  /// 检查并申请"安装未知应用"权限
  ///
  /// Android 7.x 及以下没有按应用的开关，直接视为已授权（由系统安装器拦截）；
  /// Android 8+ 通过 permission_handler 检测/申请。
  Future<InstallPermissionResult> ensureInstallPermission() async {
    if (!Platform.isAndroid) return InstallPermissionResult.granted;

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt < 26) {
      return InstallPermissionResult.granted;
    }

    var status = await Permission.requestInstallPackages.status;
    if (status.isGranted) return InstallPermissionResult.granted;

    status = await Permission.requestInstallPackages.request();
    if (status.isGranted) return InstallPermissionResult.granted;
    if (status.isPermanentlyDenied) {
      return InstallPermissionResult.permanentlyDenied;
    }
    return InstallPermissionResult.denied;
  }

  /// 唤起系统安装器安装更新包，返回是否成功唤起
  Future<bool> installUpdate(String filePath) async {
    // Windows：直接启动安装程序（.exe），进入系统安装向导
    if (Platform.isWindows) {
      try {
        await Process.start(filePath, const [], runInShell: true);
        return true;
      } catch (_) {
        return false;
      }
    }
    // 其他平台：通过系统打开方式唤起安装器
    final result = await OpenFilex.open(filePath);
    return result.type == ResultType.done;
  }

  /// 打开 Release 页面
  Future<void> openReleasePage(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// 比较两个版本号
  ///
  /// 返回 -1 表示 v1 < v2，0 表示相等，1 表示 v1 > v2。
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();

    // 补齐长度
    while (parts1.length < 3) {
      parts1.add(0);
    }
    while (parts2.length < 3) {
      parts2.add(0);
    }

    for (var i = 0; i < 3; i++) {
      if (parts1[i] < parts2[i]) return -1;
      if (parts1[i] > parts2[i]) return 1;
    }
    return 0;
  }
}

/// 安装权限检查结果
enum InstallPermissionResult {
  granted,
  denied,
  permanentlyDenied,
}

/// 更新过程中的业务异常（message 为面向用户的中文提示）
class UpdateException implements Exception {
  final String message;
  const UpdateException(this.message);

  @override
  String toString() => message;
}

/// Release 产物信息
class ReleaseAsset {
  final String name;
  final String downloadUrl;
  final int size;
  final int? id;
  final String? sha256;
  final DateTime? updatedAt;

  ReleaseAsset withDigest(String digest) => ReleaseAsset(
      name: name,
      downloadUrl: downloadUrl,
      size: size,
      id: id,
      sha256: digest,
      updatedAt: updatedAt);

  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
    this.id,
    this.sha256,
    this.updatedAt,
  });
}

/// 更新信息
class UpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String? latestVersion;
  final int? currentBuildNumber;
  final int? latestBuildNumber;
  final DateTime? packageUpdatedAt;
  final String? releaseName;
  final String? releaseUrl;
  final String? releaseNotes;
  final String? error;
  final List<ReleaseAsset> assets;

  bool get isPackageUpdate => hasUpdate && currentVersion == latestVersion;
  String get currentLabel =>
      'V$currentVersion${currentBuildNumber == null ? '' : '+$currentBuildNumber'}';
  String get latestLabel =>
      'V${latestVersion ?? '未知'}${latestBuildNumber == null ? '' : '+$latestBuildNumber'}';
  String get statusMessage =>
      error ??
      (hasUpdate
          ? isPackageUpdate
              ? '发现同版本安装包更新（构建 $currentBuildNumber → $latestBuildNumber）'
              : '发现新版本 V$latestVersion'
          : '当前已是最新版本（V$currentVersion）');

  const UpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    this.latestVersion,
    this.currentBuildNumber,
    this.latestBuildNumber,
    this.packageUpdatedAt,
    this.releaseName,
    this.releaseUrl,
    this.releaseNotes,
    this.error,
    this.assets = const [],
  });
}
