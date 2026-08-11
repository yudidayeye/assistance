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

  void confirm() => _completer.complete(true);
  void reject() => _completer.complete(false);
  Future<bool> get result => _completer.future;
}

/// 已发现的局域网设备
class DiscoveredDevice {
  final String name;
  final String ip;
  final int port;
  DateTime lastSeen;

  DiscoveredDevice({
    required this.name,
    required this.ip,
    required this.port,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  String get address => '$ip:$port';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredDevice && ip == other.ip && port == other.port;

  @override
  int get hashCode => ip.hashCode ^ port.hashCode;
}

/// 同步服务 — 收发两端对等，支持局域网设备自动发现
class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  final ImportExportService _importExport = ImportExportService.instance;

  // ── 接收端（HTTP Server）──
  HttpServer? _server;
  int _httpPort = 0;
  bool get isRunning => _server != null;

  final StreamController<SyncRequest> _requestController =
      StreamController<SyncRequest>.broadcast();
  Stream<SyncRequest> get onRequest => _requestController.stream;

  // ── 设备发现（UDP 广播）──
  static const int _discoveryPort = 12346;
  static const Duration _broadcastInterval = Duration(seconds: 2);
  static const Duration _deviceTimeout = Duration(seconds: 10);

  RawDatagramSocket? _broadcastSocket;
  RawDatagramSocket? _listenSocket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;
  String? _localIp;

  final Map<String, DiscoveredDevice> _devices = {};
  final StreamController<List<DiscoveredDevice>> _devicesController =
      StreamController<List<DiscoveredDevice>>.broadcast();

  /// 已发现设备列表的流
  Stream<List<DiscoveredDevice>> get discoveredDevices =>
      _devicesController.stream;

  List<DiscoveredDevice> get devices => _devices.values.toList();

  // ═══════════════════════════════════════════════════════════
  // 公共方法
  // ═══════════════════════════════════════════════════════════

  /// 启动接收服务 + 广播自身存在
  Future<int> startServer() async {
    if (_server != null) await stopServer();

    // 启动 HTTP 服务
    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(_handleRequest);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
    _httpPort = _server!.port;
    _localIp = await getLocalIp();
    debugPrint('Sync server started on port $_httpPort');

    // 开始 UDP 广播
    await _startBroadcast();

    return _httpPort;
  }

  /// 停止接收服务
  Future<void> stopServer() async {
    await _stopBroadcast();
    await _server?.close(force: true);
    _server = null;
    _httpPort = 0;
    _localIp = null;
  }

  /// 开始发现局域网设备
  Future<void> startDiscovery() async {
    if (_listenSocket != null) return;

    try {
      _listenSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _discoveryPort,
        reuseAddress: true,
      );
      _listenSocket!.listen(_onUdpMessage);

      // 定期清理超时设备
      _cleanupTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _cleanupDevices();
      });

      debugPrint('Discovery started on port $_discoveryPort');
    } catch (e) {
      debugPrint('Discovery start error: $e');
    }
  }

  /// 停止发现
  void stopDiscovery() {
    _listenSocket?.close();
    _listenSocket = null;
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _devices.clear();
    _devicesController.add([]);
  }

  /// 获取本机局域网 IP
  Future<String?> getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      // 1. 优先选择物理网卡（Wi-Fi/以太网）
      for (final iface in interfaces) {
        if (_isPhysicalInterface(iface.name)) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback) {
              return addr.address;
            }
          }
        }
      }

      // 2. 排除虚拟网卡（VPN/虚拟机）后的第一个
      for (final iface in interfaces) {
        if (!_isVirtualInterface(iface.name)) {
           for (final addr in iface.addresses) {
            if (!addr.isLoopback) {
              return addr.address;
            }
          }
        }
      }

      // 3. 兜底
      for (final iface in interfaces) {
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

  bool _isPhysicalInterface(String name) {
    name = name.toLowerCase();
    // 常见物理网卡名称
    final keywords = ['ethernet', 'wi-fi', 'wlan', 'eth', 'en0', 'en1', 'en2', 'en3'];
    return keywords.any((k) => name.contains(k));
  }

  bool _isVirtualInterface(String name) {
    name = name.toLowerCase();
    // 常见虚拟网卡/VPN名称
    final keywords = ['tun', 'tap', 'utun', 'ppp', 'vbox', 'vmware', 'docker', 'br-', 'virbr', 'loopback', 'lo'];
    return keywords.any((k) => name.contains(k));
  }

  /// 发送备份数据到目标设备
  Future<SyncResult> sendData(String targetIp, int port) async {
    try {
      final bytes = await _importExport.generateExportBytes();
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final request =
          await client.postUrl(Uri.parse('http://$targetIp:$port/sync/upload'));
      request.headers.contentType = ContentType.json;
      request.add(bytes);

      final response =
          await request.close().timeout(const Duration(seconds: 30));

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
    stopServer();
    stopDiscovery();
    _requestController.close();
    _devicesController.close();
  }

  // ═══════════════════════════════════════════════════════════
  // UDP 广播
  // ═══════════════════════════════════════════════════════════

  Future<void> _startBroadcast() async {
    try {
      _broadcastSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      _broadcastSocket!.broadcastEnabled = true;

      _broadcastTimer = Timer.periodic(_broadcastInterval, (_) {
        _sendBroadcast();
      });

      // 立即发一次
      _sendBroadcast();
    } catch (e) {
      debugPrint('Broadcast start error: $e');
    }
  }

  Future<void> _stopBroadcast() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;

    // 先发送离线广播，让对端立即移除本设备
    if (_broadcastSocket != null && _httpPort != 0) {
      await _sendOfflineBroadcast();
    }

    _broadcastSocket?.close();
    _broadcastSocket = null;
  }

  Future<void> _sendBroadcast() async {
    if (_broadcastSocket == null || _httpPort == 0) return;

    final ip = await getLocalIp();
    if (ip == null) return;

    final message = jsonEncode({
      'magic': 'my_assistant_sync',
      'name': Platform.localHostname,
      'ip': ip,
      'port': _httpPort,
    });

    final data = utf8.encode(message);
    _broadcastSocket!.send(
      data,
      InternetAddress('255.255.255.255'),
      _discoveryPort,
    );
  }

  Future<void> _sendOfflineBroadcast() async {
    final ip = _localIp ?? await getLocalIp();
    if (ip == null) return;

    final message = jsonEncode({
      'magic': 'my_assistant_sync',
      'name': Platform.localHostname,
      'ip': ip,
      'port': _httpPort,
      'offline': true,
    });

    final data = utf8.encode(message);
    try {
      _broadcastSocket!.send(
        data,
        InternetAddress('255.255.255.255'),
        _discoveryPort,
      );
    } catch (_) {
      // 忽略发送失败
    }

    // 等待消息发出后再关闭 socket
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  // ═══════════════════════════════════════════════════════════
  // UDP 监听（设备发现）
  // ═══════════════════════════════════════════════════════════

  void _onUdpMessage(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _listenSocket!.receive();
    if (datagram == null) return;

    try {
      final json =
          jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
      if (json['magic'] != 'my_assistant_sync') return;

      final ip = json['ip'] as String?;
      final name = json['name'] as String? ?? '未知设备';
      final port = json['port'] as int?;

      if (ip == null || port == null) return;

      // 过滤自己
      if (ip == _localIp && port == _httpPort) return;

      final key = '$ip:$port';

      // 离线消息：立即移除该设备
      if (json['offline'] == true) {
        if (_devices.containsKey(key)) {
          _devices.remove(key);
          _devicesController.add(devices);
        }
        return;
      }

      if (_devices.containsKey(key)) {
        _devices[key]!.lastSeen = DateTime.now();
      } else {
        _devices[key] = DiscoveredDevice(
          name: name,
          ip: ip,
          port: port,
        );
        _devicesController.add(devices);
      }
    } catch (_) {
      // 忽略无效数据
    }
  }

  void _cleanupDevices() {
    final now = DateTime.now();
    final before = _devices.length;
    _devices.removeWhere((_, device) {
      return now.difference(device.lastSeen) > _deviceTimeout;
    });
    if (_devices.length != before) {
      _devicesController.add(devices);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // HTTP 请求处理
  // ═══════════════════════════════════════════════════════════

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
      final syncRequest =
          SyncRequest(preview: preview, tempFilePath: tempFile.path);
      _requestController.add(syncRequest);

      // 等待用户确认（超时 5 分钟）
      final confirmed = await syncRequest.result
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
}
