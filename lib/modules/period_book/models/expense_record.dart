/// 支出明细实体
class ExpenseRecord {
  final int? id;
  final int stageId;
  final String category; // 'shopping' / 'other'
  final double amount;
  final String description;
  final String createdAt;

  const ExpenseRecord({
    this.id,
    required this.stageId,
    required this.category,
    required this.amount,
    required this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'stage_id': stageId,
      'category': category,
      'amount': amount,
      'description': description,
      'created_at': createdAt,
    };
  }

  factory ExpenseRecord.fromMap(Map<String, dynamic> map) {
    return ExpenseRecord(
      id: map['id'] as int?,
      stageId: map['stage_id'] as int,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String,
      createdAt: map['created_at'] as String,
    );
  }

  ExpenseRecord copyWith({
    int? id,
    int? stageId,
    String? category,
    double? amount,
    String? description,
    String? createdAt,
  }) {
    return ExpenseRecord(
      id: id ?? this.id,
      stageId: stageId ?? this.stageId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'ExpenseRecord(id: $id, stageId: $stageId, $category: $amount, $description)';
  }
}
