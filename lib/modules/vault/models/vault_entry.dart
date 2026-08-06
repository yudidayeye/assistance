/// 密码保险箱条目
class VaultEntry {
  final int? id;
  final int categoryId;
  final String title;
  final String encryptedPassword;
  final String passwordIv;
  final String? note;
  final String createdAt;
  final String updatedAt;

  const VaultEntry({
    this.id,
    required this.categoryId,
    required this.title,
    required this.encryptedPassword,
    required this.passwordIv,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VaultEntry.fromMap(Map<String, dynamic> map) {
    return VaultEntry(
      id: map['id'] as int?,
      categoryId: map['category_id'] as int,
      title: map['title'] as String,
      encryptedPassword: map['encrypted_password'] as String,
      passwordIv: map['password_iv'] as String,
      note: map['note'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category_id': categoryId,
      'title': title,
      'encrypted_password': encryptedPassword,
      'password_iv': passwordIv,
      'note': note,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  VaultEntry copyWith({
    int? id,
    int? categoryId,
    String? title,
    String? encryptedPassword,
    String? passwordIv,
    String? note,
    String? createdAt,
    String? updatedAt,
  }) {
    return VaultEntry(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      encryptedPassword: encryptedPassword ?? this.encryptedPassword,
      passwordIv: passwordIv ?? this.passwordIv,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
