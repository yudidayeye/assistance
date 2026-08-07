/// 密码保险箱分类
class VaultCategory {
  final int? id;
  final String name;
  final String icon;
  final int sortOrder;
  final bool isEncrypted;
  final String createdAt;
  final String updatedAt;

  const VaultCategory({
    this.id,
    required this.name,
    this.icon = 'folder',
    this.sortOrder = 0,
    this.isEncrypted = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VaultCategory.fromMap(Map<String, dynamic> map) {
    return VaultCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: map['icon'] as String? ?? 'folder',
      sortOrder: map['sort_order'] as int? ?? 0,
      isEncrypted: (map['is_encrypted'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'icon': icon,
      'sort_order': sortOrder,
      'is_encrypted': isEncrypted ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  VaultCategory copyWith({
    int? id,
    String? name,
    String? icon,
    int? sortOrder,
    bool? isEncrypted,
    String? createdAt,
    String? updatedAt,
  }) {
    return VaultCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
