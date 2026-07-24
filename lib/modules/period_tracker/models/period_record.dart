/// 经期记录模型
class PeriodRecord {
  final String id;
  final DateTime startDate;
  final DateTime? endDate;
  final int? cycleLength;
  final String? note;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PeriodRecord({
    required this.id,
    required this.startDate,
    this.endDate,
    this.cycleLength,
    this.note,
    required this.createdAt,
    this.updatedAt,
  });

  PeriodRecord copyWith({
    String? id,
    DateTime? startDate,
    Object endDate = _sentinel,
    Object? cycleLength = _sentinel,
    Object? note = _sentinel,
    DateTime? createdAt,
    Object? updatedAt = _sentinel,
  }) {
    return PeriodRecord(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      endDate: endDate == _sentinel ? this.endDate : endDate as DateTime?,
      cycleLength:
          cycleLength == _sentinel ? this.cycleLength : cycleLength as int?,
      note: note == _sentinel ? this.note : note as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt:
          updatedAt == _sentinel ? this.updatedAt : updatedAt as DateTime?,
    );
  }

  static const _sentinel = Object();

  /// 经期持续天数
  int? get durationDays {
    if (endDate == null) return null;
    return endDate!.difference(startDate).inDays + 1;
  }

  /// 是否正在进行中
  bool get isOngoing => endDate == null;

  /// 从数据库 Map 创建
  factory PeriodRecord.fromMap(Map<String, dynamic> map) {
    return PeriodRecord(
      id: map['id'] as String,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: map['end_date'] != null
          ? DateTime.parse(map['end_date'] as String)
          : null,
      cycleLength: map['cycle_length'] as int?,
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// 转为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate?.toIso8601String().split('T')[0],
      'cycle_length': cycleLength,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
