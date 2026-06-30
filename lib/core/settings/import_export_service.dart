import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../storage/database_service.dart';
import '../theme/theme_provider.dart';
import 'settings_service.dart';

/// 数据导入导出服务 — JSON 格式备份与恢复（设置 + 生理期记录）
class ImportExportService {
  static final ImportExportService instance = ImportExportService._();
  ImportExportService._();

  final DatabaseService _db = DatabaseService.instance;

  /// 当前导出格式版本号。格式变更时递增以支持迁移。
  static const int _schemaVersion = 1;

  // ═══════════════════════════════════════════════════════════════
  // 导出
  // ═══════════════════════════════════════════════════════════════

  /// 将数据导出到用户选择的 JSON 文件。
  Future<ExportResult> exportData() async {
    try {
      // 1. 读取所有 app_settings
      final settingsRows = await _db.query('app_settings');
      final settings = <String, String>{};
      for (final row in settingsRows) {
        settings[row['key'] as String] = row['value'] as String;
      }

      // 2. 读取所有生理期记录（按日期升序）
      final periodRows = await _db.query('mod_period_tracker_records',
          orderBy: 'start_date ASC');
      final periodRecords = periodRows
          .map((r) => Map<String, dynamic>.from(r))
          .toList();

      // 3. 构建导出 payload
      final payload = {
        'version': _schemaVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'appName': 'my_assistant',
        'appVersion': '1.0.0',
        'data': {
          'app_settings': settings,
          'period_tracker_records': periodRecords,
        },
      };

      // 4. 编码为格式化的 JSON
      final jsonString =
          const JsonEncoder.withIndent('  ').convert(payload);

      // 5. 打开系统"另存为"对话框
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: '导出数据',
        fileName: 'my_assistant_backup_${_dateStamp()}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        lockParentWindow: true,
      );

      if (outputPath == null) {
        return ExportResult.userCancelled();
      }

      // 6. 写入文件
      final file = File(outputPath);
      await file.writeAsString(jsonString, encoding: utf8);

      return ExportResult.success(outputPath);
    } catch (e, stack) {
      debugPrint('Export error: $e\n$stack');
      return ExportResult.error(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 导入预览
  // ═══════════════════════════════════════════════════════════════

  /// 打开文件选择器并预览导入内容（不写入数据库）。
  Future<ImportPreviewResult> previewImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '选择备份文件',
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
        lockParentWindow: true,
      );

      if (result == null || result.files.isEmpty) {
        return ImportPreviewResult.userCancelled();
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        return ImportPreviewResult.invalidFormat('无法获取文件路径');
      }

      // 读取并解析 JSON
      final file = File(filePath);
      final content = await file.readAsString(encoding: utf8);
      final json = jsonDecode(content) as Map<String, dynamic>;

      // 校验结构
      final validationError = _validateStructure(json);
      if (validationError != null) {
        return ImportPreviewResult.invalidFormat(validationError);
      }

      // 提取预览信息
      final data = json['data'] as Map<String, dynamic>;
      final settings = data['app_settings'] as Map<String, dynamic>? ?? {};
      final periodRecords =
          (data['period_tracker_records'] as List<dynamic>?) ?? [];

      return ImportPreviewResult.ready(
        filePath: filePath,
        settingsCount: settings.length,
        periodRecordsCount: periodRecords.length,
      );
    } catch (e) {
      if (e is FormatException) {
        return ImportPreviewResult.invalidFormat('JSON 格式无效');
      }
      return ImportPreviewResult.invalidFormat('文件读取失败：$e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 导入执行
  // ═══════════════════════════════════════════════════════════════

  /// 执行实际导入（需在用户确认后调用）。
  /// 整个操作在一个事务中原子完成。
  Future<ImportResult> executeImport(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString(encoding: utf8);
      final json = jsonDecode(content) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;

      int settingsCount = 0;
      int periodRecordsCount = 0;

      await _db.transaction((txn) async {
        // Phase 1: 合并 app_settings（INSERT OR REPLACE 覆盖，不删未包含的 key）
        final settings = data['app_settings'] as Map<String, dynamic>? ?? {};
        for (final entry in settings.entries) {
          await txn.rawInsert(
            'INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?)',
            [entry.key, entry.value.toString()],
          );
        }
        settingsCount = settings.length;

        // Phase 2: 合并生理期记录
        final periodRecords =
            (data['period_tracker_records'] as List<dynamic>?) ?? [];
        for (final record in periodRecords) {
          final map = Map<String, dynamic>.from(record as Map);
          await txn.rawInsert(
            '''INSERT OR REPLACE INTO mod_period_tracker_records
               (id, start_date, end_date, cycle_length, note, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?)''',
            [
              map['id'],
              map['start_date'],
              map['end_date'],
              map['cycle_length'],
              map['note'],
              map['created_at'],
              map['updated_at'],
            ],
          );
        }
        periodRecordsCount = periodRecords.length;

        // Phase 3: 在事务内重算周期长度
        if (periodRecords.isNotEmpty) {
          await _recalculateCycleLengthsInTransaction(txn);
        }
      });

      // 导入后刷新运行时缓存（模块开关、主题等）
      await SettingsService.instance.loadSettings();
      await ThemeProvider.instance.loadTheme();

      return ImportResult.success(
        settingsCount: settingsCount,
        periodRecordsCount: periodRecordsCount,
      );
    } catch (e, stack) {
      debugPrint('Import error: $e\n$stack');
      return ImportResult.error(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 周期长度重算（事务内执行）
  // ═══════════════════════════════════════════════════════════════

  /// 在给定事务中重算所有 cycle_length。
  /// 先清空全部 cycle_length，再按 start_date 升序计算相邻记录间隔。
  Future<void> _recalculateCycleLengthsInTransaction(dynamic txn) async {
    // 清空
    await txn.rawUpdate(
      'UPDATE mod_period_tracker_records SET cycle_length = NULL',
    );

    // 按 start_date 升序获取（作为 ISO 8601 字符串存储在数据库中）
    final rows = await txn.rawQuery(
      'SELECT * FROM mod_period_tracker_records ORDER BY start_date ASC',
    );

    // 从第二条开始计算与前一条的天数差
    for (int i = 1; i < rows.length; i++) {
      final current = DateTime.parse(rows[i]['start_date'] as String);
      final previous = DateTime.parse(rows[i - 1]['start_date'] as String);
      final cycleLength = current.difference(previous).inDays;

      await txn.rawUpdate(
        'UPDATE mod_period_tracker_records SET cycle_length = ? WHERE id = ?',
        [cycleLength, rows[i]['id']],
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 结构校验
  // ═══════════════════════════════════════════════════════════════

  /// 验证 JSON 结构。返回 null 表示有效，否则返回错误字符串。
  String? _validateStructure(Map<String, dynamic> json) {
    if (json['version'] is! int) {
      return '无效的文件格式：缺少版本号';
    }
    if (json['data'] is! Map) {
      return '无效的文件格式：缺少数据字段';
    }
    if (json['appName'] != 'my_assistant') {
      return '此文件不像是本应用的备份文件';
    }

    final version = json['version'] as int;
    if (version > _schemaVersion) {
      return '备份文件版本较新（v$version），请升级应用后再导入';
    }

    final data = json['data'] as Map<String, dynamic>;

    if (data['app_settings'] != null && data['app_settings'] is! Map) {
      return '设置数据格式不正确';
    }

    if (data['period_tracker_records'] != null &&
        data['period_tracker_records'] is! List) {
      return '生理期记录数据格式不正确';
    }

    return null; // 有效
  }

  // ═══════════════════════════════════════════════════════════════
  // 工具
  // ═══════════════════════════════════════════════════════════════

  /// 生成文件名时间戳 YYYYMMDD_HHmm
  static String _dateStamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
  }
}

// ═════════════════════════════════════════════════════════════════
// 结果模型
// ═════════════════════════════════════════════════════════════════

class ExportResult {
  final bool isSuccess;
  final bool isCancelled;
  final String? filePath;
  final String? error;

  const ExportResult._({
    this.isSuccess = false,
    this.isCancelled = false,
    this.filePath,
    this.error,
  });

  factory ExportResult.success(String path) =>
      ExportResult._(isSuccess: true, filePath: path);

  factory ExportResult.userCancelled() => ExportResult._(isCancelled: true);

  factory ExportResult.error(String message) =>
      ExportResult._(isSuccess: false, error: message);
}

class ImportPreviewResult {
  final bool isReady;
  final bool isCancelled;
  final String? filePath;
  final String? error;
  final int settingsCount;
  final int periodRecordsCount;

  const ImportPreviewResult._({
    this.isReady = false,
    this.isCancelled = false,
    this.filePath,
    this.error,
    this.settingsCount = 0,
    this.periodRecordsCount = 0,
  });

  factory ImportPreviewResult.ready({
    required String filePath,
    required int settingsCount,
    required int periodRecordsCount,
  }) =>
      ImportPreviewResult._(
        isReady: true,
        filePath: filePath,
        settingsCount: settingsCount,
        periodRecordsCount: periodRecordsCount,
      );

  factory ImportPreviewResult.userCancelled() =>
      ImportPreviewResult._(isCancelled: true);

  factory ImportPreviewResult.invalidFormat(String message) =>
      ImportPreviewResult._(isReady: false, error: message);
}

class ImportResult {
  final bool isSuccess;
  final String? error;
  final int settingsCount;
  final int periodRecordsCount;

  const ImportResult._({
    this.isSuccess = false,
    this.error,
    this.settingsCount = 0,
    this.periodRecordsCount = 0,
  });

  factory ImportResult.success({
    required int settingsCount,
    required int periodRecordsCount,
  }) =>
      ImportResult._(
        isSuccess: true,
        settingsCount: settingsCount,
        periodRecordsCount: periodRecordsCount,
      );

  factory ImportResult.error(String message) =>
      ImportResult._(isSuccess: false, error: message);
}
