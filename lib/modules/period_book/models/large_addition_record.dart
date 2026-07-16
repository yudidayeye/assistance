/// 大额追加记录实体（周期级，不计入总本金）
class LargeAdditionRecord {
  final int? id;
  final int periodId;
  final double amount;
  final String reason;
  final String createdAt;

  const LargeAdditionRecord({
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

  factory LargeAdditionRecord.fromMap(Map<String, dynamic> map) {
    return LargeAdditionRecord(
      id: map['id'] as int?,
      periodId: map['period_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      reason: map['reason'] as String,
      createdAt: map['created_at'] as String,
    );
  }

  LargeAdditionRecord copyWith({
    int? id,
    int? periodId,
    double? amount,
    String? reason,
    String? createdAt,
  }) {
    return LargeAdditionRecord(
      id: id ?? this.id,
      periodId: periodId ?? this.periodId,
      amount: amount ?? this.amount,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'LargeAdditionRecord(id: $id, periodId: $periodId, amount: $amount, reason: $reason)';
  }
}
