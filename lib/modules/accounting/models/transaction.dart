/// 交易类型
enum TransactionType { income, expense }

extension TransactionTypeExt on TransactionType {
  String get value => name;
  String get label => this == TransactionType.income ? '收入' : '支出';
}

/// 交易记录模型
class Transaction {
  final String id;
  final TransactionType type;
  final String categoryId;
  final double amount;
  final String? note;
  final DateTime date;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Transaction({
    required this.id,
    required this.type,
    required this.categoryId,
    required this.amount,
    this.note,
    required this.date,
    required this.createdAt,
    this.updatedAt,
  });

  Transaction copyWith({
    String? id,
    TransactionType? type,
    String? categoryId,
    double? amount,
    String? note,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 从数据库 Map 创建
  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String,
      type: map['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      categoryId: map['category_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      note: map['note'] as String?,
      date: DateTime.parse(map['date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : null,
    );
  }

  /// 转为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.value,
      'category_id': categoryId,
      'amount': amount,
      'note': note,
      'date': date.toIso8601String().split('T')[0],
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}