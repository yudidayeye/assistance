import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:my_assistant/core/settings/update_proxy_settings.dart';

void main() {
  final github = Uri.parse('https://api.github.com/repos/example/app');

  test('读取已启用的 Windows 系统代理', () {
    final settings = UpdateProxySettings.fromRegistry('''
    ProxyEnable    REG_DWORD    0x1
    ProxyServer    REG_SZ    127.0.0.1:7897
    ProxyOverride    REG_SZ    <local>;*.internal
''', environment: {});
    expect(settings.findProxy(github), 'PROXY 127.0.0.1:7897');
    expect(settings.findProxy(Uri.parse('https://printer')), 'DIRECT');
    expect(settings.findProxy(Uri.parse('https://test.internal')), 'DIRECT');
    expect(settings.findProxy(Uri.parse('https://localhost')), 'DIRECT');
    expect(settings.findProxy(Uri.parse('http://127.0.0.1')), 'DIRECT');
    expect(settings.findProxy(Uri.parse('http://[::1]')), 'DIRECT');
  });

  test('系统代理关闭或读取失败时不使用旧代理地址', () {
    for (final output in [
      '',
      '    ProxyEnable    REG_DWORD    0x0\n'
          '    ProxyServer    REG_SZ    127.0.0.1:7897',
    ]) {
      expect(
          UpdateProxySettings.fromRegistry(output, environment: {})
              .findProxy(github),
          'DIRECT');
    }
  });

  test('按协议选择代理且不误用 SOCKS 地址', () {
    final settings = UpdateProxySettings(
      server: 'http=127.0.0.1:8080;https=127.0.0.1:7897;socks=127.0.0.1:1080',
      environment: {},
    );
    expect(settings.findProxy(github), 'PROXY 127.0.0.1:7897');
    expect(settings.findProxy(Uri.parse('http://example.com')),
        'PROXY 127.0.0.1:8080');
    expect(
        UpdateProxySettings(server: 'socks=127.0.0.1:1080', environment: {})
            .findProxy(github),
        'DIRECT');
  });

  test('环境变量代理优先且 NO_PROXY 保留直连规则', () {
    final settings = UpdateProxySettings(
      server: '127.0.0.1:7897',
      environment: {
        'HTTPS_PROXY': '127.0.0.1:8080',
        'NO_PROXY': 'api.github.com',
      },
    );
    expect(settings.findProxy(github), 'DIRECT');
    expect(settings.findProxy(Uri.parse('https://github.com')),
        'PROXY 127.0.0.1:8080');
  });

  test('HTTP 客户端实际通过配置的代理发出请求', () async {
    final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = IOClient(UpdateProxySettings(
      server: '127.0.0.1:${proxy.port}',
      environment: {},
    ).createHttpClient(const Duration(seconds: 2)));
    addTearDown(() async {
      client.close();
      await proxy.close(force: true);
    });
    proxy.listen((request) async {
      request.response.write('proxied');
      await request.response.close();
    });
    final response = await client.get(Uri.parse('http://unreachable.invalid/'));
    expect(response.body, 'proxied');
  });
}
