/// 追加记录实体
class AdditionRecord {
  final int? id;
  final int periodId;
  final double amount;
  final String reason;
  final String createdAt;

  const AdditionRecord({
    this.id,
    required this.periodId,
    required this.amount,
    required this.reason,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'period_id': periodId,
      'amount': amount,
      'reason': reason,
      'created_at': createdAt,
    };
  }

  factory AdditionRecord.fromMap(Map<String, dynamic> map) {
    return AdditionRecord(
      id: map['id'] as int?,
      periodId: map['period_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      reason: map['reason'] as String,
      createdAt: map['created_at'] as String,
    );
  }

  AdditionRecord copyWith({
    int? id,
    int? periodId,
    double? amount,
    String? reason,
    String? createdAt,
  }) {
    return AdditionRecord(
      id: id ?? this.id,
      periodId: periodId ?? this.periodId,
      amount: amount ?? this.amount,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'AdditionRecord(id: $id, periodId: $periodId, amount: $amount, reason: $reason)';
  }
}
