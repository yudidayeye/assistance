/// 传输记录模型
class TransferRecord {
  final int? id;
  final String fileName;
  final int fileSize;
  final String filePath;
  final TransferDirection direction;
  final String? targetPath;
  final TransferStatus status;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;

  const TransferRecord({
    this.id,
    required this.fileName,
    required this.fileSize,
    required this.filePath,
    required this.direction,
    this.targetPath,
    this.status = TransferStatus.pending,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
  });

  TransferRecord copyWith({
    int? id,
    String? fileName,
    int? fileSize,
    String? filePath,
    TransferDirection? direction,
    String? targetPath,
    TransferStatus? status,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return TransferRecord(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      filePath: filePath ?? this.filePath,
      direction: direction ?? this.direction,
      targetPath: targetPath ?? this.targetPath,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  factory TransferRecord.fromMap(Map<String, dynamic> map) {
    return TransferRecord(
      id: map['id'] as int?,
      fileName: map['file_name'] as String,
      fileSize: map['file_size'] as int,
      filePath: map['file_path'] as String,
      direction: TransferDirection.values.firstWhere(
        (d) => d.name == map['direction'],
        orElse: () => TransferDirection.upload,
      ),
      targetPath: map['target_path'] as String?,
      status: TransferStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => TransferStatus.pending,
      ),
      errorMessage: map['error_message'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'file_name': fileName,
      'file_size': fileSize,
      'file_path': filePath,
      'direction': direction.name,
      'target_path': targetPath,
      'status': status.name,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }
}

/// 传输方向
enum TransferDirection {
  upload,   // 手机→电脑
  download, // 电脑→手机
}

/// 传输状态
enum TransferStatus {
  pending,      // 等待传输
  transferring, // 传输中
  completed,    // 已完成
  failed,       // 失败
}
