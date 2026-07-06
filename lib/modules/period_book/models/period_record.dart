/// 记账周期实体
class PeriodRecord {
  final int? id;
  final String startDate; // yyyy-MM-dd
  final String endDate; // yyyy-MM-dd
  final String? inProgressDate; // yyyy-MM-dd
  final double baseAmount;
  final double? balance;
  final bool isClosed;
  final String createdAt;
  final String updatedAt;

  const PeriodRecord({
    this.id,
    required this.startDate,
    required this.endDate,
    this.inProgressDate,
    required this.baseAmount,
    this.balance,
    this.isClosed = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'start_date': startDate,
      'end_date': endDate,
      'in_progress_date': inProgressDate,
      'base_amount': baseAmount,
      'balance': balance,
      'is_closed': isClosed ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory PeriodRecord.fromMap(Map<String, dynamic> map) {
    return PeriodRecord(
      id: map['id'] as int?,
      startDate: map['start_date'] as String,
      endDate: map['end_date'] as String,
      inProgressDate: map['in_progress_date'] as String?,
      baseAmount: (map['base_amount'] as num).toDouble(),
      balance: map['balance'] != null ? (map['balance'] as num).toDouble() : null,
      isClosed: (map['is_closed'] as int) == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  /// 周期天数：进行中日期 → 结束日期
  int get totalDays {
    final ref = inProgressDate ?? endDate;
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(ref);
    return end.difference(start).inDays + 1;
  }

  /// 是否进行中（未关闭）
  bool get isOngoing => !isClosed;

  PeriodRecord copyWith({
    int? id,
    String? startDate,
    String? endDate,
    String? inProgressDate,
    double? baseAmount,
    double? balance,
    bool? isClosed,
    String? createdAt,
    String? updatedAt,
  }) {
    return PeriodRecord(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      inProgressDate: inProgressDate ?? this.inProgressDate,
      baseAmount: baseAmount ?? this.baseAmount,
      balance: balance ?? this.balance,
      isClosed: isClosed ?? this.isClosed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'PeriodRecord(id: $id, $startDate ~ $endDate, base: $baseAmount, balance: $balance, closed: $isClosed)';
  }
}
