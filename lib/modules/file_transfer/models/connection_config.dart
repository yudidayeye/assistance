/// 连接配置模型 — 保存电脑 SMB 共享连接信息
class ConnectionConfig {
  final int? id;
  final String name;       // 配置名称（如"家里电脑"）
  final String host;       // IP 地址
  final int port;          // SMB 端口，默认 445
  final String shareName;  // 共享文件夹名（如 PhoneShare$）
  final String? username;
  final String? password;
  final bool isDefault;
  final DateTime createdAt;

  const ConnectionConfig({
    this.id,
    required this.name,
    required this.host,
    this.port = 445,
    required this.shareName,
    this.username,
    this.password,
    this.isDefault = false,
    required this.createdAt,
  });

  ConnectionConfig copyWith({
    int? id,
    String? name,
    String? host,
    int? port,
    String? shareName,
    String? username,
    String? password,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return ConnectionConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      shareName: shareName ?? this.shareName,
      username: username ?? this.username,
      password: password ?? this.password,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory ConnectionConfig.fromMap(Map<String, dynamic> map) {
    return ConnectionConfig(
      id: map['id'] as int?,
      name: map['name'] as String,
      host: map['host'] as String,
      port: map['port'] as int? ?? 445,
      shareName: map['share_name'] as String,
      username: map['username'] as String?,
      password: map['password'] as String?,
      isDefault: (map['is_default'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'host': host,
      'port': port,
      'share_name': shareName,
      'username': username,
      'password': password,
      'is_default': isDefault ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
