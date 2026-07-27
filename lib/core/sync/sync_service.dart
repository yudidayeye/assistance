import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../settings/import_export_service.dart';

/// 同步结果
class SyncResult {
  final bool isSuccess;
  final String? error;

  const SyncResult._({required this.isSuccess, this.error});

  factory SyncResult.success() => const SyncResult._(isSuccess: true);
  factory SyncResult.error(String message) =>
      SyncResult._(isSuccess: false, error: message);
}

/// 收到的同步请求（等待 UI 层确认）
class SyncRequest {
  final ImportPreviewResult preview;
  final String tempFilePath;
  final Completer<bool> _completer = Completer<bool>();

  SyncRequest({required this.preview, required this.tempFilePath});

  /// UI 层调用：用户确认导入
  void confirm() => _completer.complete(true);

  /// UI 层调用：用户取消
  void reject() => _completer.complete(false);

  Future<bool> get result => _completer.future;
}

/// 同步服务 — 收发两端对等
class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  final ImportExportService _importExport = ImportExportService.instance;

  // ── 接收端 ──
  HttpServer? _server;
  bool get isRunning => _server != null;

  final StreamController<SyncRequest> _requestController =
      StreamController<SyncRequest>.broadcast();

  /// 收到同步请求的流（UI 层监听，弹确认框）
  Stream<SyncRequest> get onRequest => _requestController.stream;

  /// 启动 HTTP 服务，返回端口号
  Future<int> startServer() async {
    if (_server != null) await stopServer();

    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(_handleRequest);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
    debugPrint('Sync server started on port ${_server!.port}');
    return _server!.port;
  }

  /// 停止 HTTP 服务
  Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
  }

  /// 获取本机局域网 IP
  Future<String?> getLocalIp() async {
    try {
      for (final iface in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      )) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('Get local IP error: $e');
    }
    return null;
  }

  /// 处理 HTTP 请求
  Future<shelf.Response> _handleRequest(shelf.Request request) async {
    if (request.method != 'POST' || request.url.path != 'sync/upload') {
      return shelf.Response.notFound('Not found');
    }

    try {
      final body = await request.readAsString();

      // 写入临时文件
      final tempDir = Directory.systemTemp;
      final tempFile = File(
          '${tempDir.path}/sync_${DateTime.now().millisecondsSinceEpoch}.json');
      await tempFile.writeAsString(body, encoding: utf8);

      // 校验
      final preview = _importExport.previewImportFromPath(tempFile.path);
      if (!preview.isReady) {
        await tempFile.delete();
        return shelf.Response.badRequest(
            body: jsonEncode({'error': preview.error}));
      }

      // 发送给 UI 层等待确认
      final request_ =
          SyncRequest(preview: preview, tempFilePath: tempFile.path);
      _requestController.add(request_);

      // 等待用户确认（超时 5 分钟）
      final confirmed = await request_.result
          .timeout(const Duration(minutes: 5), onTimeout: () => false);

      if (!confirmed) {
        await tempFile.delete();
        return shelf.Response.forbidden(
            jsonEncode({'error': '用户拒绝了导入请求'}));
      }

      // 执行导入
      final result = await _importExport.executeImport(tempFile.path);
      await tempFile.delete();

      if (result.isSuccess) {
        return shelf.Response.ok(jsonEncode({
          'success': true,
          'settingsCount': result.settingsCount,
          'periodRecordsCount': result.periodRecordsCount,
        }));
      } else {
        return shelf.Response.internalServerError(
            body: jsonEncode({'error': result.error}));
      }
    } catch (e) {
      debugPrint('Sync receive error: $e');
      return shelf.Response.internalServerError(
          body: jsonEncode({'error': e.toString()}));
    }
  }

  // ── 发送端 ──

  /// 发送备份数据到目标地址
  Future<SyncResult> sendData(String targetIp, int port) async {
    try {
      final bytes = await _importExport.generateExportBytes();
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final request =
          await client.postUrl(Uri.parse('http://$targetIp:$port/sync/upload'));
      request.headers.contentType = ContentType.json;
      request.add(bytes);

      final response = await request.close().timeout(
            const Duration(seconds: 30),
          );

      final responseBody = await response.transform(utf8.decoder).join();
      client.close(force: true);

      if (response.statusCode == 200) {
        return SyncResult.success();
      } else {
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        return SyncResult.error(json['error']?.toString() ?? '未知错误');
      }
    } catch (e) {
      return SyncResult.error('连接失败：$e');
    }
  }

  void dispose() {
    _requestController.close();
    _server?.close(force: true);
  }
}
