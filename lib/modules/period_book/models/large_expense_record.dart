/// 大额支出记录实体（周期级，不计入总支出）
class LargeExpenseRecord {
  final int? id;
  final int periodId;
  final String category; // 'shopping' / 'other'

  /// 是否属于其他支出（兼容旧数据 `other` 与带分类数据）。
  bool get isOther => category == 'other' || category.startsWith('other:');
  final double amount;
  final String description;
  final int sortOrder;
  final String createdAt;

  /// 发生时间（可空，日粒度，格式 YYYY-MM-DD）；null 表示用户未填写。
  /// 注意：这是**落位依据**而非排序键，列表顺序由 [sortOrder] 独占承载。
  final String? entryDate;

  const LargeExpenseRecord({
    this.id,
    required this.periodId,
    required this.category,
    required this.amount,
    required this.description,
    this.sortOrder = 0,
    required this.createdAt,
    this.entryDate,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'period_id': periodId,
      'category': category,
      'amount': amount,
      'description': description,
      'sort_order': sortOrder,
      'created_at': createdAt,
      'entry_date': entryDate,
    };
  }

  factory LargeExpenseRecord.fromMap(Map<String, dynamic> map) {
    return LargeExpenseRecord(
      id: map['id'] as int?,
      periodId: map['period_id'] as int,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: map['created_at'] as String,
      entryDate: map['entry_date'] as String?,
    );
  }

  LargeExpenseRecord copyWith({
    int? id,
    int? periodId,
    String? category,
    double? amount,
    String? description,
    int? sortOrder,
    String? createdAt,
    String? entryDate,
  }) {
    return LargeExpenseRecord(
      id: id ?? this.id,
      periodId: periodId ?? this.periodId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      entryDate: entryDate ?? this.entryDate,
    );
  }

  @override
  String toString() {
    return 'LargeExpenseRecord(id: $id, periodId: $periodId, $category: $amount, $description, sort: $sortOrder, entryDate: $entryDate)';
  }
}
