import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

/// 更新检查服务
///
/// 查询 GitHub Release 获取最新版本，与当前应用版本比较；
/// 支持按设备 CPU 架构匹配 APK、应用内下载与唤起系统安装器。
class UpdateService {
  UpdateService._();
  static final instance = UpdateService._();

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
    // 获取当前应用版本
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    try {
      // 请求 GitHub API 获取最新 Release
      final url = Uri.parse(
        'https://api.github.com/repos/$_owner/$_repo/releases/latest',
      );
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) {
        return UpdateInfo(
          hasUpdate: false,
          currentVersion: currentVersion,
          error: '检查更新失败（${response.statusCode}）',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = json['tag_name'] as String? ?? '';
      final releaseName = json['name'] as String? ?? '';
      final htmlUrl = json['html_url'] as String? ?? '';
      final body = json['body'] as String? ?? '';

      // 解析远程版本号（去掉可能的 'v' 前缀）
      final remoteVersion = tagName.replaceFirst(RegExp(r'^[vV]'), '');

      // 比较版本
      final hasUpdate = _compareVersions(currentVersion, remoteVersion) < 0;

      final info = UpdateInfo(
        hasUpdate: hasUpdate,
        currentVersion: currentVersion,
        latestVersion: remoteVersion,
        releaseName: releaseName,
        releaseUrl: htmlUrl,
        releaseNotes: body,
        assets: _parseAssets(json['assets']),
      );

      return info;
    } catch (e) {
      return UpdateInfo(
        hasUpdate: false,
        currentVersion: currentVersion,
        error: '网络异常，请稍后重试',
      );
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
      ));
    }
    return result;
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
    final apks = assets
        .where((a) => a.name.toLowerCase().endsWith('.apk'))
        .toList();
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
  /// - 仅考虑扩展名为 .exe / .msi 的安装包
  /// - 优先名称含 setup / installer 的安装包
  /// - 忽略调试符号等非安装产物（如含 debug / symbols / pdb）
  /// - 多个候选时取体积最大的（安装包通常最大且最完整）
  /// 返回 null 表示没有可用的 Windows 安装包。
  static ReleaseAsset? selectWindowsAsset(List<ReleaseAsset> assets) {
    final candidates = assets.where((a) {
      final name = a.name.toLowerCase();
      return (name.endsWith('.exe') || name.endsWith('.msi')) &&
          !name.contains('debug') &&
          !name.contains('symbols') &&
          !name.contains('.pdb');
    }).toList();
    if (candidates.isEmpty) return null;

    final preferred = candidates
        .where((a) {
          final name = a.name.toLowerCase();
          return name.contains('setup') || name.contains('installer');
        })
        .toList();
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
  /// 已存在且大小一致的完整安装包会被直接复用。
  Future<String?> downloadUpdate({
    required ReleaseAsset asset,
    required String version,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await _getDownloadDir();
    final ext = p.extension(asset.name).toLowerCase();
    final savePath = p.join(dir.path, 'update_v$version$ext');
    final target = File(savePath);

    // 已存在完整安装包则直接复用
    if (target.existsSync() &&
        asset.size > 0 &&
        target.lengthSync() == asset.size) {
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

        // 下载完成后按大小校验文件完整性
        if (asset.size > 0 && target.lengthSync() != asset.size) {
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
            (name.endsWith('.apk') ||
                name.endsWith('.exe') ||
                name.endsWith('.msi'))) {
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
            code == null
                ? '下载失败，请稍后重试'
                : '下载失败（$code），可前往 GitHub 发布页手动下载',
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
    // Windows：直接启动安装程序（.exe / .msi），进入系统安装向导
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

  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });
}

/// 更新信息
class UpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String? latestVersion;
  final String? releaseName;
  final String? releaseUrl;
  final String? releaseNotes;
  final String? error;
  final List<ReleaseAsset> assets;

  const UpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    this.latestVersion,
    this.releaseName,
    this.releaseUrl,
    this.releaseNotes,
    this.error,
    this.assets = const [],
  });
}
