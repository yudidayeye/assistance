/// 密码条目的备注项 — 标题 + 描述（均为用户自定义）
class VaultNoteItem {
  final String title;
  final String content;

  const VaultNoteItem({required this.title, this.content = ''});

  factory VaultNoteItem.fromJson(Map<String, dynamic> json) {
    return VaultNoteItem(
      title: (json['title'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'title': title, 'content': content};

  /// 复制到剪贴板的文本：仅描述内容
  String get copyText => content;
}
