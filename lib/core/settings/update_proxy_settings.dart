import 'dart:async';
import 'dart:io';

class UpdateProxySettings {
  final String? server;
  final String bypass;
  final Map<String, String> environment;

  UpdateProxySettings({
    this.server,
    this.bypass = '',
    Map<String, String>? environment,
  }) : environment = Map.unmodifiable(environment ?? Platform.environment);

  static Future<UpdateProxySettings> load() async {
    if (Platform.isWindows) {
      try {
        final result = await Process.run('reg.exe', const [
          'query',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        ]).timeout(const Duration(seconds: 3));
        if (result.exitCode == 0) {
          return UpdateProxySettings.fromRegistry(result.stdout.toString());
        }
      } on ProcessException {
        return UpdateProxySettings();
      } on TimeoutException {
        return UpdateProxySettings();
      }
    }
    return UpdateProxySettings();
  }

  factory UpdateProxySettings.fromRegistry(String output,
      {Map<String, String>? environment}) {
    final values = <String, String>{};
    final pattern = RegExp(
      r'^[ \t]*(ProxyEnable|ProxyServer|ProxyOverride)[ \t]+REG_\w+[ \t]+([^\r\n]*)',
      multiLine: true,
    );
    for (final match in pattern.allMatches(output)) {
      values[match.group(1)!] = match.group(2)!.trim();
    }
    final enabled =
        values['ProxyEnable'] == '0x1' || values['ProxyEnable'] == '1';
    return UpdateProxySettings(
      server: enabled ? values['ProxyServer'] : null,
      bypass: values['ProxyOverride'] ?? '',
      environment: environment,
    );
  }

  String findProxy(Uri url) {
    if (url.host == 'localhost' ||
        (InternetAddress.tryParse(url.host)?.isLoopback ?? false)) {
      return 'DIRECT';
    }
    for (final entry in bypass.split(';')) {
      final pattern = entry.trim().toLowerCase();
      if (pattern.isEmpty) continue;
      if (pattern == '<local>' && !url.host.contains('.')) return 'DIRECT';
      final expression = RegExp(
        '^${RegExp.escape(pattern).replaceAll(r'\*', '.*')}' r'$',
        caseSensitive: false,
      );
      if (expression.hasMatch(url.host) || expression.hasMatch(url.authority)) {
        return 'DIRECT';
      }
    }
    String? address;
    final configured = server?.trim() ?? '';
    if (!configured.contains('=')) {
      address = configured;
    } else {
      for (final entry in configured.split(';')) {
        final separator = entry.indexOf('=');
        if (separator < 0) continue;
        if (entry.substring(0, separator).trim().toLowerCase() == url.scheme) {
          address = entry.substring(separator + 1).trim();
          break;
        }
      }
    }
    final proxy = address == null || address.isEmpty
        ? null
        : Uri.tryParse(address.contains('://') ? address : 'http://$address');
    final validProxy = proxy != null &&
        proxy.scheme == 'http' &&
        proxy.host.isNotEmpty &&
        proxy.port > 0 &&
        proxy.port <= 65535;
    return HttpClient.findProxyFromEnvironment(url, environment: {
      if (validProxy &&
          !environment.containsKey('${url.scheme}_proxy') &&
          !environment.containsKey('${url.scheme.toUpperCase()}_PROXY'))
        '${url.scheme}_proxy': proxy.authority,
      ...environment,
    });
  }

  HttpClient createHttpClient(Duration connectionTimeout) => HttpClient()
    ..connectionTimeout = connectionTimeout
    ..findProxy = findProxy;
}
