import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 手机端 HTTP 文件服务器服务
class FileServerService extends ChangeNotifier {
  static final FileServerService instance = FileServerService._();
  FileServerService._();

  HttpServer? _server;
  String? _localIp;
  int _port = 8080;
  String? _connectionCode;
  // 已认证的 session token 集合
  final Set<String> _validTokens = {};

  bool get isRunning => _server != null;
  String? get localIp => _localIp;
  int get port => _port;
  String? get connectionCode => _connectionCode;

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

  // --- 请求处理 ---

  Future<shelf.Response> _handleRequest(shelf.Request request) async {
    final path = request.requestedUri.path;
    final method = request.method;

    // 不需要认证的路由
    if (path == '/' && method == 'GET') {
      return _serveLoginPage(request);
    }
    if (path == '/auth' && method == 'POST') {
      return _handleAuth(request);
    }

    // 需要认证的路由
    if (!_isAuthenticated(request)) {
      if (path.startsWith('/api/')) {
        return shelf.Response(401, body: jsonEncode({'error': '未认证'}));
      }
      return _serveLoginPage(request);
    }

    // 已认证的路由
    if (path == '/home' && method == 'GET') {
      return _serveHomePage(request);
    }
    if (path == '/api/upload' && method == 'POST') {
      return _handleUpload(request);
    }
    if (path == '/api/files' && method == 'GET') {
      return _handleListFiles(request);
    }
    if (path.startsWith('/api/download/') && method == 'GET') {
      return _handleDownload(request);
    }

    return shelf.Response.notFound('页面不存在');
  }

  // --- 认证 ---

  bool _isAuthenticated(shelf.Request request) {
    final cookie = request.headers['cookie'] ?? '';
    final tokenMatch = RegExp(r'session_token=([^;]+)').firstMatch(cookie);
    if (tokenMatch != null) {
      return _validTokens.contains(tokenMatch.group(1));
    }
    // 也支持 query 参数传递 token（用于下载链接）
    final token = request.requestedUri.queryParameters['token'];
    if (token != null) {
      return _validTokens.contains(token);
    }
    return false;
  }

  // --- 登录页面 ---

  shelf.Response _serveLoginPage(shelf.Request request) {
    return shelf.Response.ok(
      _loginHtml,
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  }

  // --- 认证处理 ---

  Future<shelf.Response> _handleAuth(shelf.Request request) async {
    final body = await request.readAsString();
    final params = Uri.splitQueryString(body);
    final code = params['code'] ?? '';

    if (code == _connectionCode) {
      final token = _generateToken();
      _validTokens.add(token);
      return shelf.Response.found(
        '/home',
        headers: {
          'set-cookie': 'session_token=$token; Path=/; HttpOnly',
        },
      );
    }

    return shelf.Response.ok(
      _loginHtmlWithError,
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  }

  // --- 主页面 ---

  shelf.Response _serveHomePage(shelf.Request request) {
    return shelf.Response.ok(
      _homeHtml,
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  }

  // --- 文件上传 ---

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

      final bytes = await request.read().fold<List<int>>(
        <int>[],
        (prev, chunk) => [...prev, ...chunk],
      );

      final files = _parseMultipart(bytes, boundary);
      if (files.isEmpty) {
        return shelf.Response(400, body: jsonEncode({'error': '未找到文件'}));
      }

      final downloadDir = await _getDownloadDir();
      final savedFiles = <String>[];

      for (final file in files) {
        final filePath = p.join(downloadDir, file['filename']!);
        await File(filePath).writeAsBytes(file['data'] as List<int>);
        savedFiles.add(file['filename']!);
      }

      return shelf.Response.ok(
        jsonEncode({'message': '上传成功', 'files': savedFiles}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return shelf.Response.internalServerError(
        body: jsonEncode({'error': '上传失败: $e'}),
      );
    }
  }

  // --- 文件列表 ---

  Future<shelf.Response> _handleListFiles(shelf.Request request) async {
    try {
      final downloadDir = await _getDownloadDir();
      final dir = Directory(downloadDir);
      if (!await dir.exists()) {
        return shelf.Response.ok(
          jsonEncode({'files': []}),
          headers: {'content-type': 'application/json'},
        );
      }

      final files = <Map<String, dynamic>>[];
      await for (final entity in dir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          files.add({
            'name': p.basename(entity.path),
            'size': stat.size,
            'modified': stat.modified.toIso8601String(),
          });
        }
      }

      files.sort((a, b) => (b['modified'] as String).compareTo(a['modified'] as String));

      return shelf.Response.ok(
        jsonEncode({'files': files}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return shelf.Response.internalServerError(
        body: jsonEncode({'error': '获取文件列表失败: $e'}),
      );
    }
  }

  // --- 文件下载 ---

  Future<shelf.Response> _handleDownload(shelf.Request request) async {
    try {
      final fileName = Uri.decodeComponent(
        request.requestedUri.path.replaceFirst('/api/download/', ''),
      );
      final downloadDir = await _getDownloadDir();
      final filePath = p.join(downloadDir, fileName);
      final file = File(filePath);

      if (!await file.exists()) {
        return shelf.Response.notFound('文件不存在');
      }

      final bytes = await file.readAsBytes();
      return shelf.Response.ok(
        bytes,
        headers: {
          'content-type': 'application/octet-stream',
          'content-disposition': 'attachment; filename="$fileName"',
          'content-length': bytes.length.toString(),
        },
      );
    } catch (e) {
      return shelf.Response.internalServerError(
        body: jsonEncode({'error': '下载失败: $e'}),
      );
    }
  }

  // --- 辅助方法 ---

  String _generateCode() {
    final random = Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  String _generateToken() {
    final random = Random.secure();
    return List.generate(32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Future<String> _getLocalIp() async {
    try {
      for (final interface in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      )) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '未知';
  }

  Future<String> _getDownloadDir() async {
    if (Platform.isAndroid) {
      // Android 使用外部存储的 Download 目录
      final dirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
      if (dirs != null && dirs.isNotEmpty) {
        return dirs.first.path;
      }
    }
    final appDir = await getApplicationDocumentsDirectory();
    final downloadDir = p.join(appDir.path, 'file_transfer');
    await Directory(downloadDir).create(recursive: true);
    return downloadDir;
  }

  String? _extractBoundary(String contentType) {
    final match = RegExp(r'boundary=(.+)').firstMatch(contentType);
    return match?.group(1)?.trim();
  }

  List<Map<String, dynamic>> _parseMultipart(List<int> bytes, String boundary) {
    final files = <Map<String, dynamic>>[];
    final boundaryBytes = utf8.encode('--$boundary');
    final endBoundaryBytes = utf8.encode('--$boundary--');
    final headerEnd = utf8.encode('\r\n\r\n');

    int searchStart = 0;
    while (searchStart < bytes.length) {
      // 找到下一个 boundary
      final boundaryIdx = _indexOf(bytes, boundaryBytes, searchStart);
      if (boundaryIdx == -1) break;

      // 检查是否是结束 boundary
      if (_indexOf(bytes, endBoundaryBytes, searchStart) == boundaryIdx) break;

      // 找到 header 结束位置
      final headerEndIdx = _indexOf(bytes, headerEnd, boundaryIdx + boundaryBytes.length);
      if (headerEndIdx == -1) break;

      // 解析 header
      final headerBytes = bytes.sublist(boundaryIdx + boundaryBytes.length, headerEndIdx);
      final header = utf8.decode(headerBytes);

      // 提取文件名
      final filenameMatch = RegExp(r'filename="([^"]+)"').firstMatch(header);
      if (filenameMatch == null) {
        searchStart = headerEndIdx + headerEnd.length;
        continue;
      }
      final filename = filenameMatch.group(1)!;

      // 找到下一个 boundary 的位置（数据结束）
      final nextBoundaryIdx = _indexOf(bytes, boundaryBytes, headerEndIdx + headerEnd.length);
      final dataEnd = nextBoundaryIdx != -1 ? nextBoundaryIdx - 2 : bytes.length; // -2 去掉 \r\n

      final data = bytes.sublist(headerEndIdx + headerEnd.length, dataEnd);
      files.add({'filename': filename, 'data': data});

      searchStart = nextBoundaryIdx != -1 ? nextBoundaryIdx : bytes.length;
    }

    return files;
  }

  int _indexOf(List<int> haystack, List<int> needle, int start) {
    outer:
    for (int i = start; i <= haystack.length - needle.length; i++) {
      for (int j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  shelf.Middleware _logMiddleware() {
    return (shelf.Handler innerHandler) {
      return (shelf.Request request) async {
        debugPrint('[FileServer] ${request.method} ${request.requestedUri.path}');
        return innerHandler(request);
      };
    };
  }
}

// --- 内嵌 HTML ---

const _loginHtml = '''
<!DOCTYPE html>
<html lang="zh">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>文件互传 - 连接验证</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: #f5f5f5;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .card {
      background: white;
      border-radius: 16px;
      padding: 40px 32px;
      width: 90%;
      max-width: 360px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.08);
    }
    .icon { text-align: center; font-size: 48px; margin-bottom: 16px; }
    h1 { text-align: center; font-size: 20px; color: #333; margin-bottom: 8px; }
    .desc { text-align: center; font-size: 14px; color: #999; margin-bottom: 24px; }
    .error { text-align: center; font-size: 13px; color: #e74c3c; margin-bottom: 16px; }
    input {
      width: 100%;
      padding: 14px;
      font-size: 24px;
      text-align: center;
      letter-spacing: 8px;
      border: 2px solid #e0e0e0;
      border-radius: 12px;
      outline: none;
      transition: border-color 0.2s;
    }
    input:focus { border-color: #5B9BD5; }
    button {
      width: 100%;
      padding: 14px;
      margin-top: 16px;
      font-size: 16px;
      color: white;
      background: #5B9BD5;
      border: none;
      border-radius: 12px;
      cursor: pointer;
      transition: background 0.2s;
    }
    button:hover { background: #4a8bc5; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">📱</div>
    <h1>文件互传</h1>
    <p class="desc">请输入手机端显示的 6 位连接码</p>
    <form method="POST" action="/auth">
      <input type="text" name="code" maxlength="6" pattern="[0-9]{6}"
             placeholder="000000" autocomplete="off" autofocus>
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
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: #f5f5f5;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .card {
      background: white;
      border-radius: 16px;
      padding: 40px 32px;
      width: 90%;
      max-width: 360px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.08);
    }
    .icon { text-align: center; font-size: 48px; margin-bottom: 16px; }
    h1 { text-align: center; font-size: 20px; color: #333; margin-bottom: 8px; }
    .desc { text-align: center; font-size: 14px; color: #999; margin-bottom: 16px; }
    .error {
      text-align: center; font-size: 13px; color: #e74c3c; margin-bottom: 16px;
      padding: 10px; background: #fdf0ef; border-radius: 8px;
    }
    input {
      width: 100%;
      padding: 14px;
      font-size: 24px;
      text-align: center;
      letter-spacing: 8px;
      border: 2px solid #e74c3c;
      border-radius: 12px;
      outline: none;
      transition: border-color 0.2s;
    }
    input:focus { border-color: #c0392b; }
    button {
      width: 100%;
      padding: 14px;
      margin-top: 16px;
      font-size: 16px;
      color: white;
      background: #5B9BD5;
      border: none;
      border-radius: 12px;
      cursor: pointer;
      transition: background 0.2s;
    }
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
      <input type="text" name="code" maxlength="6" pattern="[0-9]{6}"
             placeholder="000000" autocomplete="off" autofocus>
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
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: #f5f5f5;
      min-height: 100vh;
      padding: 20px;
    }
    .header {
      text-align: center;
      padding: 20px 0;
    }
    .header h1 { font-size: 22px; color: #333; }
    .header p { font-size: 14px; color: #999; margin-top: 4px; }
    .section {
      background: white;
      border-radius: 16px;
      padding: 20px;
      margin-bottom: 16px;
      box-shadow: 0 2px 12px rgba(0,0,0,0.04);
    }
    .section h2 {
      font-size: 16px;
      color: #333;
      margin-bottom: 16px;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .drop-zone {
      border: 2px dashed #d0d0d0;
      border-radius: 12px;
      padding: 40px 20px;
      text-align: center;
      color: #999;
      transition: all 0.2s;
      cursor: pointer;
    }
    .drop-zone.dragover {
      border-color: #5B9BD5;
      background: #f0f7ff;
      color: #5B9BD5;
    }
    .drop-zone .icon { font-size: 36px; margin-bottom: 8px; }
    .drop-zone p { font-size: 14px; }
    .progress-bar {
      width: 100%;
      height: 6px;
      background: #e0e0e0;
      border-radius: 3px;
      margin-top: 12px;
      overflow: hidden;
      display: none;
    }
    .progress-bar .fill {
      height: 100%;
      background: #5B9BD5;
      border-radius: 3px;
      width: 0%;
      transition: width 0.3s;
    }
    .file-list { list-style: none; }
    .file-item {
      display: flex;
      align-items: center;
      padding: 12px 0;
      border-bottom: 1px solid #f0f0f0;
    }
    .file-item:last-child { border-bottom: none; }
    .file-item .icon { font-size: 24px; margin-right: 12px; }
    .file-item .info { flex: 1; }
    .file-item .name { font-size: 14px; color: #333; }
    .file-item .size { font-size: 12px; color: #999; margin-top: 2px; }
    .file-item .download {
      padding: 6px 14px;
      font-size: 13px;
      color: #5B9BD5;
      background: #f0f7ff;
      border: none;
      border-radius: 8px;
      cursor: pointer;
      text-decoration: none;
    }
    .file-item .download:hover { background: #e0efff; }
    .status {
      text-align: center;
      font-size: 13px;
      color: #999;
      margin-top: 8px;
    }
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
    <h2>📤 上传文件到手机</h2>
    <div class="drop-zone" id="dropZone">
      <div class="icon">📁</div>
      <p>拖拽文件到这里，或点击选择文件</p>
    </div>
    <input type="file" id="fileInput" multiple style="display:none">
    <div class="progress-bar" id="progressBar"><div class="fill" id="progressFill"></div></div>
    <div class="status" id="uploadStatus"></div>
  </div>

  <div class="section">
    <h2>📥 从手机下载文件</h2>
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

    // 拖拽上传
    dropZone.addEventListener('click', () => fileInput.click());
    dropZone.addEventListener('dragover', (e) => {
      e.preventDefault();
      dropZone.classList.add('dragover');
    });
    dropZone.addEventListener('dragleave', () => dropZone.classList.remove('dragover'));
    dropZone.addEventListener('drop', (e) => {
      e.preventDefault();
      dropZone.classList.remove('dragover');
      uploadFiles(e.dataTransfer.files);
    });
    fileInput.addEventListener('change', () => uploadFiles(fileInput.files));

    async function uploadFiles(files) {
      if (!files.length) return;
      const formData = new FormData();
      for (const file of files) formData.append('files', file);

      progressBar.style.display = 'block';
      uploadStatus.textContent = '上传中...';
      uploadStatus.className = 'status';

      const xhr = new XMLHttpRequest();
      xhr.upload.addEventListener('progress', (e) => {
        if (e.lengthComputable) {
          progressFill.style.width = (e.loaded / e.total * 100) + '%';
        }
      });
      xhr.addEventListener('load', () => {
        if (xhr.status === 200) {
          uploadStatus.textContent = '上传成功！';
          uploadStatus.className = 'status success';
          loadFileList();
        } else {
          uploadStatus.textContent = '上传失败';
          uploadStatus.className = 'status error';
        }
        setTimeout(() => { progressBar.style.display = 'none'; progressFill.style.width = '0%'; }, 2000);
      });
      xhr.addEventListener('error', () => {
        uploadStatus.textContent = '网络错误';
        uploadStatus.className = 'status error';
      });
      xhr.open('POST', '/api/upload');
      xhr.send(formData);
    }

    async function loadFileList() {
      try {
        const resp = await fetch('/api/files');
        const data = await resp.json();
        if (!data.files || data.files.length === 0) {
          fileList.innerHTML = '<li class="empty">暂无文件</li>';
          return;
        }
        fileList.innerHTML = data.files.map(f => {
          const size = f.size < 1024 ? f.size + ' B'
            : f.size < 1048576 ? (f.size / 1024).toFixed(1) + ' KB'
            : (f.size / 1048576).toFixed(1) + ' MB';
          return '<li class="file-item">' +
            '<span class="icon">📄</span>' +
            '<div class="info"><div class="name">' + f.name + '</div>' +
            '<div class="size">' + size + '</div></div>' +
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
