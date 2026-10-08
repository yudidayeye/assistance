/// 大额追加记录实体（周期级，不计入总本金）
class LargeAdditionRecord {
  final int? id;
  final int periodId;
  final double amount;
  final String reason;
  final int sortOrder;
  final String createdAt;

  /// 发生时间（可空，日粒度，格式 YYYY-MM-DD）；null 表示用户未填写。
  /// 注意：这是**落位依据**而非排序键，列表顺序由 [sortOrder] 独占承载。
  final String? entryDate;

  const LargeAdditionRecord({
    this.id,
    required this.periodId,
    required this.amount,
    required this.reason,
    this.sortOrder = 0,
    required this.createdAt,
    this.entryDate,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'period_id': periodId,
      'amount': amount,
      'reason': reason,
      'sort_order': sortOrder,
      'created_at': createdAt,
      'entry_date': entryDate,
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
      entryDate: map['entry_date'] as String?,
    );
  }

  LargeAdditionRecord copyWith({
    int? id,
    int? periodId,
    double? amount,
    String? reason,
    int? sortOrder,
    String? createdAt,
    String? entryDate,
  }) {
    return LargeAdditionRecord(
      id: id ?? this.id,
      periodId: periodId ?? this.periodId,
      amount: amount ?? this.amount,
      reason: reason ?? this.reason,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      entryDate: entryDate ?? this.entryDate,
    );
  }

  @override
  String toString() {
    return 'LargeAdditionRecord(id: $id, periodId: $periodId, amount: $amount, reason: $reason, entryDate: $entryDate)';
  }
}
