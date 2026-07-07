/// 阶段记录实体
class StageRecord {
  final int? id;
  final int periodId;
  final String startDate; // yyyy-MM-dd
  final String endDate; // yyyy-MM-dd
  final double? balance; // 本阶段余额（手动输入）
  final int sortOrder; // 排序序号
  final String createdAt;
  final String updatedAt;

  const StageRecord({
    this.id,
    required this.periodId,
    required this.startDate,
    required this.endDate,
    this.balance,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'period_id': periodId,
      'start_date': startDate,
      'end_date': endDate,
      'balance': balance,
      'sort_order': sortOrder,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory StageRecord.fromMap(Map<String, dynamic> map) {
    return StageRecord(
      id: map['id'] as int?,
      periodId: map['period_id'] as int,
      startDate: map['start_date'] as String,
      endDate: map['end_date'] as String,
      balance: map['balance'] != null ? (map['balance'] as num).toDouble() : null,
      sortOrder: map['sort_order'] as int,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  /// 阶段天数
  int get totalDays {
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);
    return end.difference(start).inDays + 1;
  }

  /// 是否有余额数据
  bool get hasBalance => balance != null;

  StageRecord copyWith({
    int? id,
    int? periodId,
    String? startDate,
    String? endDate,
    double? balance,
    int? sortOrder,
    String? createdAt,
    String? updatedAt,
  }) {
    return StageRecord(
      id: id ?? this.id,
      periodId: periodId ?? this.periodId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      balance: balance ?? this.balance,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'StageRecord(id: $id, periodId: $periodId, $startDate ~ $endDate, balance: $balance, sort: $sortOrder)';
  }
}
