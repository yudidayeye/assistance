import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// 更新检查服务
///
/// 查询 GitHub Release 获取最新版本，与当前应用版本比较。
class UpdateService {
  UpdateService._();
  static final instance = UpdateService._();

  /// GitHub 仓库信息
  static const _owner = 'yudidayeye';
  static const _repo = 'assistance';

  /// 检查更新
  ///
  /// 返回 [UpdateInfo]，包含是否有更新、当前版本、最新版本等信息。
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

/// 更新信息
class UpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String? latestVersion;
  final String? releaseName;
  final String? releaseUrl;
  final String? releaseNotes;
  final String? error;

  const UpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    this.latestVersion,
    this.releaseName,
    this.releaseUrl,
    this.releaseNotes,
    this.error,
  });
}
