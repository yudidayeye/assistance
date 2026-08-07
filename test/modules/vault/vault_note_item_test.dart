import 'package:flutter_test/flutter_test.dart';
import 'package:my_assistant/modules/vault/models/vault_entry.dart';
import 'package:my_assistant/modules/vault/models/vault_note_item.dart';

VaultEntry _entryWithNote(String? note) => VaultEntry(
      categoryId: 1,
      title: 't',
      encryptedPassword: 'e',
      passwordIv: 'iv',
      note: note,
      createdAt: 'now',
      updatedAt: 'now',
    );

void main() {
  test('多条备注编码后可完整解析', () {
    const items = [
      VaultNoteItem(title: '账号', content: 'zhangsan@example.com'),
      VaultNoteItem(title: '手机号', content: '13800138000'),
    ];
    final encoded = VaultEntry.encodeNotes(items);
    expect(encoded, isNotNull);

    final parsed = _entryWithNote(encoded).noteItems;
    expect(parsed.length, 2);
    expect(parsed[0].title, '账号');
    expect(parsed[0].content, 'zhangsan@example.com');
    expect(parsed[1].title, '手机号');
    expect(parsed[1].content, '13800138000');
  });

  test('旧数据（普通文本）兼容为「其他」标题的单项', () {
    final parsed = _entryWithNote('备注内容abc').noteItems;
    expect(parsed.length, 1);
    expect(parsed[0].title, '其他');
    expect(parsed[0].content, '备注内容abc');
  });

  test('空备注返回空列表，编码空列表返回 null', () {
    expect(_entryWithNote(null).noteItems, isEmpty);
    expect(_entryWithNote('').noteItems, isEmpty);
    expect(VaultEntry.encodeNotes(const []), isNull);
    expect(
      VaultEntry.encodeNotes(const [VaultNoteItem(title: '', content: '')]),
      isNull,
    );
  });

  test('copyText 只返回描述内容', () {
    expect(
      const VaultNoteItem(title: '账号', content: 'abc').copyText,
      'abc',
    );
    expect(const VaultNoteItem(title: '账号').copyText, '');
  });
}
