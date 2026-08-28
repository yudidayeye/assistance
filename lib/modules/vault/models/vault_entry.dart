import 'dart:convert';
import 'vault_note_item.dart';

/// 密码保险箱条目
class VaultEntry {
  final int? id;
  final int categoryId;
  final String title;
  final String? username;
  final String encryptedPassword;
  final String passwordIv;

  /// 加密该条目密码时使用的盐（方案 C：每条记录独立盐；旧数据为空用主盐）
  final String? salt;
  final String? note;
  final int sortOrder;
  final String createdAt;
  final String updatedAt;

  const VaultEntry({
    this.id,
    required this.categoryId,
    required this.title,
    this.username,
    required this.encryptedPassword,
    required this.passwordIv,
    this.salt,
    this.note,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VaultEntry.fromMap(Map<String, dynamic> map) {
    return VaultEntry(
      id: map['id'] as int?,
      categoryId: map['category_id'] as int,
      title: map['title'] as String,
      username: map['username'] as String?,
      encryptedPassword: map['encrypted_password'] as String,
      passwordIv: map['password_iv'] as String,
      salt: map['salt'] as String?,
      note: map['note'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category_id': categoryId,
      'title': title,
      'username': username,
      'encrypted_password': encryptedPassword,
      'password_iv': passwordIv,
      'salt': salt,
      'note': note,
      'sort_order': sortOrder,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  /// 解析备注为多条结构（兼容旧数据：普通文本视为「其他」标题的单项）
  List<VaultNoteItem> get noteItems {
    final raw = note;
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final items = <VaultNoteItem>[];
        for (final item in decoded) {
          if (item is Map) {
            items.add(VaultNoteItem.fromJson(Map<String, dynamic>.from(item)));
          }
        }
        return items;
      }
    } catch (_) {
      // 非 JSON 数组，按旧数据兼容处理
    }
    return [VaultNoteItem(title: '其他', content: raw)];
  }

  /// 将多条备注编码为 JSON 字符串（空列表返回 null）
  static String? encodeNotes(List<VaultNoteItem> items) {
    final valid = items
        .where(
            (i) => i.title.trim().isNotEmpty || i.content.trim().isNotEmpty)
        .toList();
    if (valid.isEmpty) return null;
    return jsonEncode(valid.map((i) => i.toJson()).toList());
  }

  VaultEntry copyWith({
    int? id,
    int? categoryId,
    String? title,
    String? username,
    String? encryptedPassword,
    String? passwordIv,
    String? salt,
    String? note,
    int? sortOrder,
    String? createdAt,
    String? updatedAt,
  }) {
    return VaultEntry(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      username: username ?? this.username,
      encryptedPassword: encryptedPassword ?? this.encryptedPassword,
      passwordIv: passwordIv ?? this.passwordIv,
      salt: salt ?? this.salt,
      note: note ?? this.note,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
