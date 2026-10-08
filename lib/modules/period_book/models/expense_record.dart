/// 支出明细实体
class ExpenseRecord {
  final int? id;
  final int stageId;
  final String category; // 'shopping' / 'other'
  final double amount;
  final String description;
  final int sortOrder; // 排序序号
  final String createdAt;

  /// 发生时间（可空，日粒度，格式 YYYY-MM-DD）；null 表示用户未填写。
  /// 注意：这是**落位依据**而非排序键，列表顺序由 [sortOrder] 独占承载。
  final String? entryDate;

  /// 是否属于其他支出（兼容旧数据 `other` 与带分类数据）。
  bool get isOther => category == 'other' || category.startsWith('other:');

  const ExpenseRecord({
    this.id,
    required this.stageId,
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
      'stage_id': stageId,
      'category': category,
      'amount': amount,
      'description': description,
      'sort_order': sortOrder,
      'created_at': createdAt,
      'entry_date': entryDate,
    };
  }

  factory ExpenseRecord.fromMap(Map<String, dynamic> map) {
    return ExpenseRecord(
      id: map['id'] as int?,
      stageId: map['stage_id'] as int,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: map['created_at'] as String,
      entryDate: map['entry_date'] as String?,
    );
  }

  ExpenseRecord copyWith({
    int? id,
    int? stageId,
    String? category,
    double? amount,
    String? description,
    int? sortOrder,
    String? createdAt,
    String? entryDate,
  }) {
    return ExpenseRecord(
      id: id ?? this.id,
      stageId: stageId ?? this.stageId,
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
    return 'ExpenseRecord(id: $id, stageId: $stageId, $category: $amount, $description, sort: $sortOrder, entryDate: $entryDate)';
  }
}
