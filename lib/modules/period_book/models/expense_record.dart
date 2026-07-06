/// 支出明细实体
class ExpenseRecord {
  final int? id;
  final int periodId;
  final String category; // 'shopping' / 'other'
  final double amount;
  final String description;
  final String createdAt;

  const ExpenseRecord({
    this.id,
    required this.periodId,
    required this.category,
    required this.amount,
    required this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'period_id': periodId,
      'category': category,
      'amount': amount,
      'description': description,
      'created_at': createdAt,
    };
  }

  factory ExpenseRecord.fromMap(Map<String, dynamic> map) {
    return ExpenseRecord(
      id: map['id'] as int?,
      periodId: map['period_id'] as int,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String,
      createdAt: map['created_at'] as String,
    );
  }

  ExpenseRecord copyWith({
    int? id,
    int? periodId,
    String? category,
    double? amount,
    String? description,
    String? createdAt,
  }) {
    return ExpenseRecord(
      id: id ?? this.id,
      periodId: periodId ?? this.periodId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'ExpenseRecord(id: $id, periodId: $periodId, $category: $amount, $description)';
  }
}
