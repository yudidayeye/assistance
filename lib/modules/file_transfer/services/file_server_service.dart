import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 共享文件数据
class SharedFile {
  final String name;
  final String path;
  final int size;

  const SharedFile({required this.name, required this.path, required this.size});
}

/// 手机端 HTTP 文件服务器服务
class FileServerService extends ChangeNotifier {
  static final FileServerService instance = FileServerService._();
  FileServerService._();

  HttpServer? _server;
  String? _localIp;
  int _port = 8080;
  String? _connectionCode;
  final Set<String> _validTokens = {};
  final List<SharedFile> _sharedFiles = [];
  final List<SharedFile> _receivedFiles = [];

  bool get isRunning => _server != null;
  String? get localIp => _localIp;
  int get port => _port;
  String? get connectionCode => _connectionCode;
  List<SharedFile> get sharedFiles => List.unmodifiable(_sharedFiles);
  List<SharedFile> get receivedFiles => List.unmodifiable(_receivedFiles);

  /// 添加共享文件
  void addSharedFile(String name, String path, int size) {
    // 去重
    _sharedFiles.removeWhere((f) => f.name == name);
    _sharedFiles.add(SharedFile(name: name, path: path, size: size));
    notifyListeners();
  }

  /// 移除共享文件
  void removeSharedFile(String name) {
    _sharedFiles.removeWhere((f) => f.name == name);
    notifyListeners();
  }

  /// 启动 HTTP 服务器
  Future<void> start({int port = 8080}) async {
    if (_server != null) return;

    _port = port;
    _connectionCode = _generateCode();
    _validTokens.clear();
    _localIp = await _getLocalIp();

    final handler = const shelf.Pipeline()
        .addMiddleware(_logMiddleware())
        .addHandler(_handleRequest);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, _port);
    debugPrint('[FileServer] 服务器启动: http://$_localIp:$_port');
    notifyListeners();
  }

  /// 停止 HTTP 服务器
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _connectionCode = null;
    _validTokens.clear();
    debugPrint('[FileServer] 服务器已停止');
    notifyListeners();
  }

  /// 刷新连接码
  void refreshCode() {
    _connectionCode = _generateCode();
    _validTokens.clear();
    notifyListeners();
  }

  // ==================== 请求路由 ====================

  Future<shelf.Response> _handleRequest(shelf.Request request) async {
    final path = request.requestedUri.path;
    final method = request.method;

    // 无需认证
    if (path == '/' && method == 'GET') return _htmlResponse(_loginHtml);
    if (path == '/auth' && method == 'POST') return _handleAuth(request);

    // 需要认证
    if (!_isAuthenticated(request)) {
      if (path.startsWith('/api/')) {
        return shelf.Response(401, body: jsonEncode({'error': '未认证'}));
      }
      return _htmlResponse(_loginHtml);
    }

    // 已认证路由
    if (path == '/home' && method == 'GET') return _htmlResponse(_homeHtml);
    if (path == '/api/upload' && method == 'POST') return _handleUpload(request);
    if (path == '/api/files' && method == 'GET') return _handleListFiles();
    if (path.startsWith('/api/download/') && method == 'GET') return _handleDownload(request);

    return shelf.Response.notFound('页面不存在');
  }

  shelf.Response _htmlResponse(String html) =>
      shelf.Response.ok(html, headers: {'content-type': 'text/html; charset=utf-8'});

  // ==================== 认证 ====================

  bool _isAuthenticated(shelf.Request request) {
    final cookie = request.headers['cookie'] ?? '';
    final tokenMatch = RegExp(r'session_token=([^;]+)').firstMatch(cookie);
    if (tokenMatch != null && _validTokens.contains(tokenMatch.group(1))) return true;
    final token = request.requestedUri.queryParameters['token'];
    return token != null && _validTokens.contains(token);
  }

  Future<shelf.Response> _handleAuth(shelf.Request request) async {
    final body = await request.readAsString();
    final params = Uri.splitQueryString(body);
    if (params['code'] == _connectionCode) {
      final token = _generateToken();
      _validTokens.add(token);
      return shelf.Response.found('/home', headers: {
        'set-cookie': 'session_token=$token; Path=/; HttpOnly',
      });
    }
    return _htmlResponse(_loginHtmlWithError);
  }

  // ==================== 文件操作 ====================

  /// 上传文件到手机（电脑→手机）
  Future<shelf.Response> _handleUpload(shelf.Request request) async {
    try {
      final contentType = request.headers['content-type'] ?? '';
      if (!contentType.contains('multipart/form-data')) {
        return shelf.Response(400, body: jsonEncode({'error': '请求格式错误'}));
      }
      final boundary = _extractBoundary(contentType);
      if (boundary == null) {
        return shelf.Response(400, body: jsonEncode({'error': '无法解析边界'}));
      }

      final bytes = await request.read().fold<List<int>>(<int>[], (prev, chunk) => [...prev, ...chunk]);
      final parsedFiles = _parseMultipart(bytes, boundary);
      if (parsedFiles.isEmpty) {
        return shelf.Response(400, body: jsonEncode({'error': '未找到文件'}));
      }

      final downloadDir = await _getDownloadDir();
      final saved = <String>[];

      for (final file in parsedFiles) {
        final filePath = p.join(downloadDir, file['filename']!);
        await File(filePath).writeAsBytes(file['data'] as List<int>);
        saved.add(file['filename']!);
        // 记录收到的文件
        _receivedFiles.removeWhere((f) => f.name == file['filename']);
        _receivedFiles.insert(0, SharedFile(
          name: file['filename']!,
          path: filePath,
          size: (file['data'] as List<int>).length,
        ));
      }
      notifyListeners();

      return shelf.Response.ok(
        jsonEncode({'message': '上传成功', 'files': saved}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return shelf.Response.internalServerError(body: jsonEncode({'error': '上传失败: $e'}));
    }
  }

  /// 列出手机端共享文件（手机→电脑）
  shelf.Response _handleListFiles() {
    final files = _sharedFiles.map((f) => {
      'name': f.name,
      'size': f.size,
    }).toList();

    return shelf.Response.ok(
      jsonEncode({'files': files}),
      headers: {'content-type': 'application/json'},
    );
  }

  /// 下载手机共享文件
  Future<shelf.Response> _handleDownload(shelf.Request request) async {
    try {
      final fileName = Uri.decodeComponent(
        request.requestedUri.path.replaceFirst('/api/download/', ''),
      );

      // 在共享文件列表中查找
      final shared = _sharedFiles.firstWhere(
        (f) => f.name == fileName,
        orElse: () => const SharedFile(name: '', path: '', size: 0),
      );

      if (shared.path.isEmpty) {
        return shelf.Response.notFound('文件不存在');
      }

      final file = File(shared.path);
      if (!await file.exists()) {
        return shelf.Response.notFound('文件已被删除');
      }

      final bytes = await file.readAsBytes();
      return shelf.Response.ok(bytes, headers: {
        'content-type': 'application/octet-stream',
        'content-disposition': 'attachment; filename="$fileName"',
        'content-length': bytes.length.toString(),
      });
    } catch (e) {
      return shelf.Response.internalServerError(body: jsonEncode({'error': '下载失败: $e'}));
    }
  }

  // ==================== 辅助方法 ====================

  String _generateCode() => List.generate(6, (_) => Random().nextInt(10)).join();

  String _generateToken() =>
      List.generate(32, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  Future<String> _getLocalIp() async {
    try {
      for (final interface in await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLinkLocal: false,
      )) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return '未知';
  }

  Future<String> _getDownloadDir() async {
    if (Platform.isAndroid) {
      final dirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
      if (dirs != null && dirs.isNotEmpty) return dirs.first.path;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final dir = p.join(appDir.path, 'file_transfer');
    await Directory(dir).create(recursive: true);
    return dir;
  }

  String? _extractBoundary(String contentType) =>
      RegExp(r'boundary=(.+)').firstMatch(contentType)?.group(1)?.trim();

  List<Map<String, dynamic>> _parseMultipart(List<int> bytes, String boundary) {
    final result = <Map<String, dynamic>>[];
    final bBytes = utf8.encode('--$boundary');
    final endBytes = utf8.encode('--$boundary--');
    final headerEnd = utf8.encode('\r\n\r\n');

    int pos = 0;
    while (pos < bytes.length) {
      final bIdx = _indexOf(bytes, bBytes, pos);
      if (bIdx == -1) break;
      if (_indexOf(bytes, endBytes, pos) == bIdx) break;

      final hEndIdx = _indexOf(bytes, headerEnd, bIdx + bBytes.length);
      if (hEndIdx == -1) break;

      final header = utf8.decode(bytes.sublist(bIdx + bBytes.length, hEndIdx));
      final nameMatch = RegExp(r'filename="([^"]+)"').firstMatch(header);
      if (nameMatch == null) { pos = hEndIdx + headerEnd.length; continue; }

      final nextBIdx = _indexOf(bytes, bBytes, hEndIdx + headerEnd.length);
      final dataEnd = nextBIdx != -1 ? nextBIdx - 2 : bytes.length;
      result.add({'filename': nameMatch.group(1)!, 'data': bytes.sublist(hEndIdx + headerEnd.length, dataEnd)});
      pos = nextBIdx != -1 ? nextBIdx : bytes.length;
    }
    return result;
  }

  int _indexOf(List<int> h, List<int> n, int start) {
    outer:
    for (int i = start; i <= h.length - n.length; i++) {
      for (int j = 0; j < n.length; j++) { if (h[i + j] != n[j]) continue outer; }
      return i;
    }
    return -1;
  }

  shelf.Middleware _logMiddleware() => (shelf.Handler inner) =>
    (shelf.Request req) async {
      debugPrint('[FileServer] ${req.method} ${req.requestedUri.path}');
      return inner(req);
    };
}

// ==================== 内嵌 HTML ====================

const _loginHtml = '''
<!DOCTYPE html>
<html lang="zh">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>文件互传 - 连接验证</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f5f5f5; min-height: 100vh; display: flex; align-items: center; justify-content: center; }
    .card { background: white; border-radius: 16px; padding: 40px 32px; width: 90%; max-width: 360px; box-shadow: 0 4px 20px rgba(0,0,0,0.08); }
    .icon { text-align: center; font-size: 48px; margin-bottom: 16px; }
    h1 { text-align: center; font-size: 20px; color: #333; margin-bottom: 8px; }
    .desc { text-align: center; font-size: 14px; color: #999; margin-bottom: 24px; }
    input { width: 100%; padding: 14px; font-size: 24px; text-align: center; letter-spacing: 8px; border: 2px solid #e0e0e0; border-radius: 12px; outline: none; transition: border-color 0.2s; }
    input:focus { border-color: #5B9BD5; }
    button { width: 100%; padding: 14px; margin-top: 16px; font-size: 16px; color: white; background: #5B9BD5; border: none; border-radius: 12px; cursor: pointer; transition: background 0.2s; }
    button:hover { background: #4a8bc5; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">📱</div>
    <h1>文件互传</h1>
    <p class="desc">请输入手机端显示的 6 位连接码</p>
    <form method="POST" action="/auth">
      <input type="text" name="code" maxlength="6" pattern="[0-9]{6}" placeholder="000000" autocomplete="off" autofocus>
      <button type="submit">连接</button>
    </form>
  </div>
</body>
</html>
''';

const _loginHtmlWithError = '''
<!DOCTYPE html>
<html lang="zh">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>文件互传 - 连接验证</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f5f5f5; min-height: 100vh; display: flex; align-items: center; justify-content: center; }
    .card { background: white; border-radius: 16px; padding: 40px 32px; width: 90%; max-width: 360px; box-shadow: 0 4px 20px rgba(0,0,0,0.08); }
    .icon { text-align: center; font-size: 48px; margin-bottom: 16px; }
    h1 { text-align: center; font-size: 20px; color: #333; margin-bottom: 8px; }
    .desc { text-align: center; font-size: 14px; color: #999; margin-bottom: 16px; }
    .error { text-align: center; font-size: 13px; color: #e74c3c; margin-bottom: 16px; padding: 10px; background: #fdf0ef; border-radius: 8px; }
    input { width: 100%; padding: 14px; font-size: 24px; text-align: center; letter-spacing: 8px; border: 2px solid #e74c3c; border-radius: 12px; outline: none; }
    input:focus { border-color: #c0392b; }
    button { width: 100%; padding: 14px; margin-top: 16px; font-size: 16px; color: white; background: #5B9BD5; border: none; border-radius: 12px; cursor: pointer; }
    button:hover { background: #4a8bc5; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">📱</div>
    <h1>文件互传</h1>
    <p class="desc">请输入手机端显示的 6 位连接码</p>
    <div class="error">连接码错误，请重试</div>
    <form method="POST" action="/auth">
      <input type="text" name="code" maxlength="6" pattern="[0-9]{6}" placeholder="000000" autocomplete="off" autofocus>
      <button type="submit">连接</button>
    </form>
  </div>
</body>
</html>
''';

const _homeHtml = '''
<!DOCTYPE html>
<html lang="zh">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>文件互传</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f5f5f5; min-height: 100vh; padding: 20px; }
    .header { text-align: center; padding: 20px 0; }
    .header h1 { font-size: 22px; color: #333; }
    .header p { font-size: 14px; color: #999; margin-top: 4px; }
    .section { background: white; border-radius: 16px; padding: 20px; margin-bottom: 16px; box-shadow: 0 2px 12px rgba(0,0,0,0.04); }
    .section h2 { font-size: 16px; color: #333; margin-bottom: 16px; display: flex; align-items: center; gap: 8px; }
    .drop-zone { border: 2px dashed #d0d0d0; border-radius: 12px; padding: 40px 20px; text-align: center; color: #999; transition: all 0.2s; cursor: pointer; }
    .drop-zone.dragover { border-color: #5B9BD5; background: #f0f7ff; color: #5B9BD5; }
    .drop-zone .icon { font-size: 36px; margin-bottom: 8px; }
    .drop-zone p { font-size: 14px; }
    .progress-bar { width: 100%; height: 6px; background: #e0e0e0; border-radius: 3px; margin-top: 12px; overflow: hidden; display: none; }
    .progress-bar .fill { height: 100%; background: #5B9BD5; border-radius: 3px; width: 0%; transition: width 0.3s; }
    .file-list { list-style: none; }
    .file-item { display: flex; align-items: center; padding: 12px 0; border-bottom: 1px solid #f0f0f0; }
    .file-item:last-child { border-bottom: none; }
    .file-item .icon { font-size: 24px; margin-right: 12px; }
    .file-item .info { flex: 1; }
    .file-item .name { font-size: 14px; color: #333; }
    .file-item .size { font-size: 12px; color: #999; margin-top: 2px; }
    .file-item .download { padding: 6px 14px; font-size: 13px; color: #5B9BD5; background: #f0f7ff; border: none; border-radius: 8px; cursor: pointer; text-decoration: none; }
    .file-item .download:hover { background: #e0efff; }
    .status { text-align: center; font-size: 13px; color: #999; margin-top: 8px; }
    .status.success { color: #27ae60; }
    .status.error { color: #e74c3c; }
    .empty { text-align: center; padding: 20px; color: #ccc; font-size: 14px; }
  </style>
</head>
<body>
  <div class="header">
    <h1>📱 文件互传</h1>
    <p>手机与电脑之间的文件传输</p>
  </div>

  <div class="section">
    <h2>📤 从电脑上传文件到手机</h2>
    <p style="font-size:13px;color:#999;margin-bottom:12px;">选择电脑上的文件，上传后会保存到手机</p>
    <div class="drop-zone" id="dropZone">
      <div class="icon">📁</div>
      <p>拖拽文件到这里，或点击选择文件</p>
    </div>
    <input type="file" id="fileInput" multiple style="display:none">
    <div class="progress-bar" id="progressBar"><div class="fill" id="progressFill"></div></div>
    <div class="status" id="uploadStatus"></div>
  </div>

  <div class="section">
    <h2>📥 从手机下载文件到电脑</h2>
    <p style="font-size:13px;color:#999;margin-bottom:12px;">手机端选择的共享文件，点击下载到电脑</p>
    <ul class="file-list" id="fileList">
      <li class="empty">加载中...</li>
    </ul>
  </div>

  <script>
    const dropZone = document.getElementById('dropZone');
    const fileInput = document.getElementById('fileInput');
    const progressBar = document.getElementById('progressBar');
    const progressFill = document.getElementById('progressFill');
    const uploadStatus = document.getElementById('uploadStatus');
    const fileList = document.getElementById('fileList');

    dropZone.addEventListener('click', () => fileInput.click());
    dropZone.addEventListener('dragover', (e) => { e.preventDefault(); dropZone.classList.add('dragover'); });
    dropZone.addEventListener('dragleave', () => dropZone.classList.remove('dragover'));
    dropZone.addEventListener('drop', (e) => { e.preventDefault(); dropZone.classList.remove('dragover'); uploadFiles(e.dataTransfer.files); });
    fileInput.addEventListener('change', () => uploadFiles(fileInput.files));

    async function uploadFiles(files) {
      if (!files.length) return;
      const formData = new FormData();
      for (const file of files) formData.append('files', file);
      progressBar.style.display = 'block';
      uploadStatus.textContent = '上传中...';
      uploadStatus.className = 'status';
      const xhr = new XMLHttpRequest();
      xhr.upload.addEventListener('progress', (e) => { if (e.lengthComputable) progressFill.style.width = (e.loaded / e.total * 100) + '%'; });
      xhr.addEventListener('load', () => {
        if (xhr.status === 200) { uploadStatus.textContent = '上传成功！文件已保存到手机'; uploadStatus.className = 'status success'; }
        else { uploadStatus.textContent = '上传失败'; uploadStatus.className = 'status error'; }
        setTimeout(() => { progressBar.style.display = 'none'; progressFill.style.width = '0%'; }, 2000);
      });
      xhr.addEventListener('error', () => { uploadStatus.textContent = '网络错误'; uploadStatus.className = 'status error'; });
      xhr.open('POST', '/api/upload');
      xhr.send(formData);
    }

    async function loadFileList() {
      try {
        const resp = await fetch('/api/files');
        const data = await resp.json();
        if (!data.files || data.files.length === 0) {
          fileList.innerHTML = '<li class="empty">手机端暂无共享文件</li>';
          return;
        }
        fileList.innerHTML = data.files.map(f => {
          const size = f.size < 1024 ? f.size + ' B' : f.size < 1048576 ? (f.size / 1024).toFixed(1) + ' KB' : (f.size / 1048576).toFixed(1) + ' MB';
          return '<li class="file-item">' +
            '<span class="icon">📄</span>' +
            '<div class="info"><div class="name">' + f.name + '</div><div class="size">' + size + '</div></div>' +
            '<a class="download" href="/api/download/' + encodeURIComponent(f.name) + '">下载</a>' +
            '</li>';
        }).join('');
      } catch (e) {
        fileList.innerHTML = '<li class="empty">加载失败</li>';
      }
    }
    loadFileList();
  </script>
</body>
</html>
''';
