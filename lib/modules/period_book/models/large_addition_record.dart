/// 大额追加记录实体（周期级，不计入总本金）
class LargeAdditionRecord {
  final int? id;
  final int periodId;
  final double amount;
  final String reason;
  final int sortOrder;
  final String createdAt;

  const LargeAdditionRecord({
    this.id,
    required this.periodId,
    required this.amount,
    required this.reason,
    this.sortOrder = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'period_id': periodId,
      'amount': amount,
      'reason': reason,
      'sort_order': sortOrder,
      'created_at': createdAt,
    };
  }

  factory LargeAdditionRecord.fromMap(Map<String, dynamic> map) {
    return LargeAdditionRecord(
      id: map['id'] as int?,
      periodId: map['period_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      reason: map['reason'] as String,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: map['created_at'] as String,
    );
  }

  LargeAdditionRecord copyWith({
    int? id,
    int? periodId,
    double? amount,
    String? reason,
    int? sortOrder,
    String? createdAt,
  }) {
    return LargeAdditionRecord(
      id: id ?? this.id,
      periodId: periodId ?? this.periodId,
      amount: amount ?? this.amount,
      reason: reason ?? this.reason,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'LargeAdditionRecord(id: $id, periodId: $periodId, amount: $amount, reason: $reason)';
  }
}
