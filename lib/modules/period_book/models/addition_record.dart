/// 追加记录实体
class AdditionRecord {
  final int? id;
  final int stageId;
  final double amount;
  final String reason;
  final int sortOrder; // 排序序号
  final String createdAt;

  /// 发生时间（可空，日粒度，格式 YYYY-MM-DD）；null 表示用户未填写。
  /// 注意：这是**落位依据**而非排序键，列表顺序由 [sortOrder] 独占承载。
  final String? entryDate;

  const AdditionRecord({
    this.id,
    required this.stageId,
    required this.amount,
    required this.reason,
    this.sortOrder = 0,
    required this.createdAt,
    this.entryDate,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'stage_id': stageId,
      'amount': amount,
      'reason': reason,
      'sort_order': sortOrder,
      'created_at': createdAt,
      'entry_date': entryDate,
    };
  }

  factory AdditionRecord.fromMap(Map<String, dynamic> map) {
    return AdditionRecord(
      id: map['id'] as int?,
      stageId: map['stage_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      reason: map['reason'] as String,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: map['created_at'] as String,
      entryDate: map['entry_date'] as String?,
    );
  }

  AdditionRecord copyWith({
    int? id,
    int? stageId,
    double? amount,
    String? reason,
    int? sortOrder,
    String? createdAt,
    String? entryDate,
  }) {
    return AdditionRecord(
      id: id ?? this.id,
      stageId: stageId ?? this.stageId,
      amount: amount ?? this.amount,
      reason: reason ?? this.reason,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      entryDate: entryDate ?? this.entryDate,
    );
  }

  @override
  String toString() {
    return 'AdditionRecord(id: $id, stageId: $stageId, amount: $amount, reason: $reason, entryDate: $entryDate)';
  }
}
