import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../storage/database_service.dart';
import '../theme/theme_provider.dart';
import 'settings_service.dart';
import '../../modules/period_book/services/period_book_service.dart';
import '../../modules/period_tracker/services/period_service.dart';
import '../../modules/vault/services/vault_service.dart';

/// 数据导入导出服务 — 支持 JSON 和纯文本格式
/// - JSON: 完整备份（设置 + 生理期记录 + 周期记账）
/// - 纯文本：兼容用户原有习惯的周期记账导入导出
class ImportExportService {
  static final ImportExportService instance = ImportExportService._();
  ImportExportService._();

  final DatabaseService _db = DatabaseService.instance;

  /// 当前导出格式版本号。格式变更时递增以支持迁移。
  static const int _schemaVersion = 4; // v4 新增密码保险箱模块支持

  // ═══════════════════════════════════════════════════════════════
  // 导出
  // ═══════════════════════════════════════════════════════════════

  /// 生成导出 JSON 的 bytes，供 FilePicker.saveFile 写入（通过 SAF 处理权限）
  Future<Uint8List> generateExportBytes() async {
    // 1. 读取所有 app_settings
    final settingsRows = await _db.query('app_settings');
    final settings = <String, String>{};
    for (final row in settingsRows) {
      settings[row['key'] as String] = row['value'] as String;
    }

    // 2. 读取所有生理期记录（按日期升序）
    final periodRows = await _db.query('mod_period_tracker_records',
        orderBy: 'start_date ASC');
    final periodRecords =
        periodRows.map((r) => Map<String, dynamic>.from(r)).toList();

    // 3. 读取所有周期记账数据（按显示顺序导出，保证导出文件可读且确定）
    final bookPeriods =
        await _db.query('mod_period_book_periods', orderBy: 'start_date ASC');
    final bookStages = await _db.query('mod_period_book_stages',
        orderBy: 'period_id ASC, sort_order ASC');
    final bookAdditions = await _db.query('mod_period_book_additions',
        orderBy: 'stage_id ASC, sort_order ASC, created_at ASC');
    final bookExpenses = await _db.query('mod_period_book_expenses',
        orderBy: 'stage_id ASC, sort_order ASC, created_at ASC');
    // 大额记录（周期级，不计入总本金/总支出）
    final bookLargeAdditions = await _db.query(
        'mod_period_book_large_additions',
        orderBy: 'period_id ASC, created_at ASC');
    final bookLargeExpenses = await _db.query('mod_period_book_large_expenses',
        orderBy: 'period_id ASC, sort_order ASC, created_at ASC');

    // 4. 读取密码保险箱数据（分类 + 条目）
    final vaultCategories = await _db.query(
        'mod_vault_categories',
        orderBy: 'sort_order ASC, created_at ASC');
    final vaultEntries = await _db.query('mod_vault_entries',
        orderBy: 'category_id ASC, created_at ASC');
    final vaultMaster = await _db.query('mod_vault_master', limit: 1);

    // 5. 构建导出 payload
    final payload = {
      'version': _schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'appName': 'my_assistant',
      'appVersion': '1.0.0',
      'data': {
        'app_settings': settings,
        'period_tracker_records': periodRecords,
        'period_book_periods': bookPeriods,
        'period_book_stages': bookStages,
        'period_book_additions': bookAdditions,
        'period_book_expenses': bookExpenses,
        'period_book_large_additions': bookLargeAdditions,
        'period_book_large_expenses': bookLargeExpenses,
        'vault_master': vaultMaster.isNotEmpty ? vaultMaster.first : null,
        'vault_categories': vaultCategories,
        'vault_entries': vaultEntries,
      },
    };

    // 6. 编码为 JSON bytes
    final jsonString = const JsonEncoder.withIndent('  ').convert(payload);
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  /// 将数据导出为 JSON 文件。
  ///
  /// [filePath] 可选参数，指定完整文件路径。
  /// 若不传则保存到下载/文档目录。
  Future<ExportResult> exportData({String? filePath}) async {
    try {
      final bytes = await generateExportBytes();

      // 确定目标路径（若未指定则使用下载/文档目录）
      String targetPath;
      if (filePath != null) {
        targetPath = filePath;
      } else {
        final dir = (await _getExportDirectory()).path;
        final fileName = 'my_assistant_backup_${_dateStamp()}.json';
        targetPath = '$dir${Platform.pathSeparator}$fileName';
      }

      final file = File(targetPath);
      await file.writeAsBytes(bytes);

      return ExportResult.success(file.path);
    } catch (e, stack) {
      debugPrint('Export error: $e\n$stack');
      return ExportResult.error(e.toString());
    }
  }

  /// 获取导出目标目录（优先下载目录，回退应用文档目录）
  Future<Directory> _getExportDirectory() async {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) return downloads;
    } catch (_) {}
    return getApplicationDocumentsDirectory();
  }

  // ═══════════════════════════════════════════════════════════════
  // 导入预览（从文件路径读取）
  // ═══════════════════════════════════════════════════════════════

  /// 从给定路径解析并校验 JSON 结构（不写入数据库）。
  ImportPreviewResult previewImportFromPath(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return ImportPreviewResult.invalidFormat('文件不存在：$filePath');
      }

      final content = file.readAsStringSync(encoding: utf8);
      final json = jsonDecode(content) as Map<String, dynamic>;

      final validationError = _validateStructure(json);
      if (validationError != null) {
        return ImportPreviewResult.invalidFormat(validationError);
      }

      final data = json['data'] as Map<String, dynamic>;
      final settings = data['app_settings'] as Map<String, dynamic>? ?? {};
      final periodRecords =
          (data['period_tracker_records'] as List<dynamic>?) ?? [];
      final bookPeriods = (data['period_book_periods'] as List<dynamic>?) ?? [];
      final bookStages = (data['period_book_stages'] as List<dynamic>?) ?? [];
      final bookAdditions =
          (data['period_book_additions'] as List<dynamic>?) ?? [];
      final bookExpenses =
          (data['period_book_expenses'] as List<dynamic>?) ?? [];
      final bookLargeAdditions =
          (data['period_book_large_additions'] as List<dynamic>?) ?? [];
      final bookLargeExpenses =
          (data['period_book_large_expenses'] as List<dynamic>?) ?? [];

      final vaultCategories =
          (data['vault_categories'] as List<dynamic>?) ?? [];
      final vaultEntries =
          (data['vault_entries'] as List<dynamic>?) ?? [];

      return ImportPreviewResult.ready(
        filePath: filePath,
        settingsCount: settings.length,
        periodRecordsCount: periodRecords.length,
        bookPeriodsCount: bookPeriods.length,
        bookStagesCount: bookStages.length,
        bookAdditionsCount: bookAdditions.length,
        bookExpensesCount: bookExpenses.length,
        bookLargeAdditionsCount: bookLargeAdditions.length,
        bookLargeExpensesCount: bookLargeExpenses.length,
        vaultCategoriesCount: vaultCategories.length,
        vaultEntriesCount: vaultEntries.length,
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
      int bookPeriodsCount = 0;
      int bookStagesCount = 0;
      int bookAdditionsCount = 0;
      int bookExpensesCount = 0;
      int bookLargeAdditionsCount = 0;
      int bookLargeExpensesCount = 0;
      int vaultCategoriesCount = 0;
      int vaultEntriesCount = 0;

      await _db.transaction((txn) async {
        // Phase 1: 合并 app_settings
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

        // Phase 4: 合并周期记账数据
        final bookResult = await _importPeriodBookData(txn, data);
        bookPeriodsCount = bookResult['periods']!;
        bookStagesCount = bookResult['stages']!;
        bookAdditionsCount = bookResult['additions']!;
        bookExpensesCount = bookResult['expenses']!;
        bookLargeAdditionsCount = bookResult['largeAdditions']!;
        bookLargeExpensesCount = bookResult['largeExpenses']!;

        // Phase 5: 合并密码保险箱数据
        final vaultResult = await _importVaultData(txn, data);
        vaultCategoriesCount = vaultResult['categories']!;
        vaultEntriesCount = vaultResult['entries']!;
      });

      // 导入后刷新运行时缓存
      await SettingsService.instance.loadSettings();
      await ThemeProvider.instance.loadTheme();

      // 通知模块服务数据已变更，刷新首页卡片
      PeriodBookService.instance.notifyChanged();
      PeriodService.instance.notifyChanged();
      VaultService.instance.notifyChanged();

      return ImportResult.success(
        settingsCount: settingsCount,
        periodRecordsCount: periodRecordsCount,
        bookPeriodsCount: bookPeriodsCount,
        bookStagesCount: bookStagesCount,
        bookAdditionsCount: bookAdditionsCount,
        bookExpensesCount: bookExpensesCount,
        bookLargeAdditionsCount: bookLargeAdditionsCount,
        bookLargeExpensesCount: bookLargeExpensesCount,
        vaultCategoriesCount: vaultCategoriesCount,
        vaultEntriesCount: vaultEntriesCount,
      );
    } catch (e, stack) {
      debugPrint('Import error: $e\n$stack');
      return ImportResult.error(e.toString());
    }
  }

  /// 导入周期记账数据
  Future<Map<String, int>> _importPeriodBookData(
      dynamic txn, Map<String, dynamic> data) async {
    int periodsCount = 0;
    int stagesCount = 0;
    int additionsCount = 0;
    int expensesCount = 0;
    int largeAdditionsCount = 0;
    int largeExpensesCount = 0;

    // 确保大额记录表存在（兼容旧数据库未创建该表的场景）
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS mod_period_book_large_additions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        period_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        reason TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (period_id) REFERENCES mod_period_book_periods(id) ON DELETE CASCADE
      )
    ''');
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS mod_period_book_large_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        period_id INTEGER NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (period_id) REFERENCES mod_period_book_periods(id) ON DELETE CASCADE
      )
    ''');
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_pb_large_additions_period ON mod_period_book_large_additions(period_id)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_pb_large_expenses_period ON mod_period_book_large_expenses(period_id)',
    );

    // 导入周期
    final periods = (data['period_book_periods'] as List<dynamic>?) ?? [];
    for (final period in periods) {
      final map = Map<String, dynamic>.from(period as Map);
      await txn.rawInsert(
        '''INSERT OR REPLACE INTO mod_period_book_periods
           (id, start_date, end_date, base_amount, is_closed, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?)''',
        [
          map['id'],
          map['start_date'],
          map['end_date'],
          map['base_amount'],
          map['is_closed'],
          map['created_at'],
          map['updated_at'],
        ],
      );
      periodsCount++;
    }

    // 导入阶段
    final stages = (data['period_book_stages'] as List<dynamic>?) ?? [];
    for (final stage in stages) {
      final map = Map<String, dynamic>.from(stage as Map);
      await txn.rawInsert(
        '''INSERT OR REPLACE INTO mod_period_book_stages
           (id, period_id, start_date, end_date, balance, sort_order, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          map['id'],
          map['period_id'],
          map['start_date'],
          map['end_date'],
          map['balance'],
          map['sort_order'],
          map['created_at'],
          map['updated_at'],
        ],
      );
      stagesCount++;
    }

    // 导入追加记录
    final additions = (data['period_book_additions'] as List<dynamic>?) ?? [];
    for (final addition in additions) {
      final map = Map<String, dynamic>.from(addition as Map);
      await txn.rawInsert(
        '''INSERT OR REPLACE INTO mod_period_book_additions
           (id, stage_id, amount, reason, sort_order, created_at)
           VALUES (?, ?, ?, ?, ?, ?)''',
        [
          map['id'],
          map['stage_id'],
          map['amount'],
          map['reason'],
          map['sort_order'] ?? 0,
          map['created_at'],
        ],
      );
      additionsCount++;
    }

    // 导入支出明细
    final expenses = (data['period_book_expenses'] as List<dynamic>?) ?? [];
    for (final expense in expenses) {
      final map = Map<String, dynamic>.from(expense as Map);
      await txn.rawInsert(
        '''INSERT OR REPLACE INTO mod_period_book_expenses
           (id, stage_id, category, amount, description, sort_order, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?)''',
        [
          map['id'],
          map['stage_id'],
          map['category'],
          map['amount'],
          map['description'],
          map['sort_order'] ?? 0,
          map['created_at'],
        ],
      );
      expensesCount++;
    }

    // 导入大额追加记录
    final largeAdditions =
        (data['period_book_large_additions'] as List<dynamic>?) ?? [];
    for (final addition in largeAdditions) {
      final map = Map<String, dynamic>.from(addition as Map);
      await txn.rawInsert(
        '''INSERT OR REPLACE INTO mod_period_book_large_additions
           (id, period_id, amount, reason, created_at)
           VALUES (?, ?, ?, ?, ?)''',
        [
          map['id'],
          map['period_id'],
          map['amount'],
          map['reason'],
          map['created_at'],
        ],
      );
      largeAdditionsCount++;
    }

    // 导入大额支出记录
    final largeExpenses =
        (data['period_book_large_expenses'] as List<dynamic>?) ?? [];
    for (final expense in largeExpenses) {
      final map = Map<String, dynamic>.from(expense as Map);
      await txn.rawInsert(
        '''INSERT OR REPLACE INTO mod_period_book_large_expenses
           (id, period_id, category, amount, description, sort_order, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?)''',
        [
          map['id'],
          map['period_id'],
          map['category'],
          map['amount'],
          map['description'],
          map['sort_order'] ?? 0,
          map['created_at'],
        ],
      );
      largeExpensesCount++;
    }

    return {
      'periods': periodsCount,
      'stages': stagesCount,
      'additions': additionsCount,
      'expenses': expensesCount,
      'largeAdditions': largeAdditionsCount,
      'largeExpenses': largeExpensesCount,
    };
  }

  /// 导入密码保险箱数据
  Future<Map<String, int>> _importVaultData(
      dynamic txn, Map<String, dynamic> data) async {
    int categoriesCount = 0;
    int entriesCount = 0;

    // 确保保险箱表存在（兼容旧数据库）
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS mod_vault_master (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        salt TEXT NOT NULL,
        verify_cipher TEXT NOT NULL,
        verify_iv TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS mod_vault_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL DEFAULT 'folder',
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_encrypted INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS mod_vault_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        username TEXT,
        encrypted_password TEXT NOT NULL,
        password_iv TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES mod_vault_categories(id) ON DELETE CASCADE
      )
    ''');
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_vault_entries_category ON mod_vault_entries(category_id)',
    );

    // 导入主密码数据（仅当备份中有且本地没有时写入，避免覆盖已有密码）
    final vaultMaster = data['vault_master'] as Map<String, dynamic>?;
    if (vaultMaster != null) {
      final existing = await txn.query('mod_vault_master', limit: 1);
      if (existing.isEmpty) {
        await txn.rawInsert(
          '''INSERT OR REPLACE INTO mod_vault_master
             (id, salt, verify_cipher, verify_iv, created_at)
             VALUES (?, ?, ?, ?, ?)''',
          [
            vaultMaster['id'] ?? 1,
            vaultMaster['salt'],
            vaultMaster['verify_cipher'],
            vaultMaster['verify_iv'],
            vaultMaster['created_at'],
          ],
        );
      }
    }

    // 导入分类
    final categories =
        (data['vault_categories'] as List<dynamic>?) ?? [];
    for (final cat in categories) {
      final map = Map<String, dynamic>.from(cat as Map);
      await txn.rawInsert(
        '''INSERT OR REPLACE INTO mod_vault_categories
           (id, name, icon, sort_order, is_encrypted, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?)''',
        [
          map['id'],
          map['name'],
          map['icon'] ?? 'folder',
          map['sort_order'] ?? 0,
          map['is_encrypted'] ?? 1,
          map['created_at'],
          map['updated_at'],
        ],
      );
      categoriesCount++;
    }

    // 导入条目
    final entries = (data['vault_entries'] as List<dynamic>?) ?? [];
    for (final entry in entries) {
      final map = Map<String, dynamic>.from(entry as Map);
      await txn.rawInsert(
        '''INSERT OR REPLACE INTO mod_vault_entries
           (id, category_id, title, username, encrypted_password, password_iv, note, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          map['id'],
          map['category_id'],
          map['title'],
          map['username'],
          map['encrypted_password'],
          map['password_iv'],
          map['note'],
          map['created_at'],
          map['updated_at'],
        ],
      );
      entriesCount++;
    }

    return {
      'categories': categoriesCount,
      'entries': entriesCount,
    };
  }

  // ═══════════════════════════════════════════════════════════════
  // 周期长度重算（事务内执行）
  // ═══════════════════════════════════════════════════════════════

  Future<void> _recalculateCycleLengthsInTransaction(dynamic txn) async {
    await txn.rawUpdate(
      'UPDATE mod_period_tracker_records SET cycle_length = NULL',
    );

    final rows = await txn.rawQuery(
      'SELECT * FROM mod_period_tracker_records ORDER BY start_date ASC',
    );

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
    if (data['period_book_periods'] != null &&
        data['period_book_periods'] is! List) {
      return '周期记账数据格式不正确';
    }
    if (data['period_book_stages'] != null &&
        data['period_book_stages'] is! List) {
      return '阶段数据格式不正确';
    }
    if (data['period_book_additions'] != null &&
        data['period_book_additions'] is! List) {
      return '追加记录数据格式不正确';
    }
    if (data['period_book_expenses'] != null &&
        data['period_book_expenses'] is! List) {
      return '支出记录数据格式不正确';
    }
    if (data['period_book_large_additions'] != null &&
        data['period_book_large_additions'] is! List) {
      return '大额追加数据格式不正确';
    }
    if (data['period_book_large_expenses'] != null &&
        data['period_book_large_expenses'] is! List) {
      return '大额支出数据格式不正确';
    }
    if (data['vault_master'] != null && data['vault_master'] is! Map) {
      return '密码保险箱主密码数据格式不正确';
    }
    if (data['vault_categories'] != null &&
        data['vault_categories'] is! List) {
      return '密码保险箱分类数据格式不正确';
    }
    if (data['vault_entries'] != null &&
        data['vault_entries'] is! List) {
      return '密码保险箱条目数据格式不正确';
    }

    return null;
  }

  // ═══════════════════════════════════════════════════════════════
  // 工具
  // ═══════════════════════════════════════════════════════════════

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

  factory ExportResult.userCancelled() =>
      const ExportResult._(isCancelled: true);

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
  final int bookPeriodsCount;
  final int bookStagesCount;
  final int bookAdditionsCount;
  final int bookExpensesCount;
  final int bookLargeAdditionsCount;
  final int bookLargeExpensesCount;
  final int vaultCategoriesCount;
  final int vaultEntriesCount;

  const ImportPreviewResult._({
    this.isReady = false,
    this.isCancelled = false,
    this.filePath,
    this.error,
    this.settingsCount = 0,
    this.periodRecordsCount = 0,
    this.bookPeriodsCount = 0,
    this.bookStagesCount = 0,
    this.bookAdditionsCount = 0,
    this.bookExpensesCount = 0,
    this.bookLargeAdditionsCount = 0,
    this.bookLargeExpensesCount = 0,
    this.vaultCategoriesCount = 0,
    this.vaultEntriesCount = 0,
  });

  factory ImportPreviewResult.ready({
    required String filePath,
    required int settingsCount,
    required int periodRecordsCount,
    int bookPeriodsCount = 0,
    int bookStagesCount = 0,
    int bookAdditionsCount = 0,
    int bookExpensesCount = 0,
    int bookLargeAdditionsCount = 0,
    int bookLargeExpensesCount = 0,
    int vaultCategoriesCount = 0,
    int vaultEntriesCount = 0,
  }) =>
      ImportPreviewResult._(
        isReady: true,
        filePath: filePath,
        settingsCount: settingsCount,
        periodRecordsCount: periodRecordsCount,
        bookPeriodsCount: bookPeriodsCount,
        bookStagesCount: bookStagesCount,
        bookAdditionsCount: bookAdditionsCount,
        bookExpensesCount: bookExpensesCount,
        bookLargeAdditionsCount: bookLargeAdditionsCount,
        bookLargeExpensesCount: bookLargeExpensesCount,
        vaultCategoriesCount: vaultCategoriesCount,
        vaultEntriesCount: vaultEntriesCount,
      );

  factory ImportPreviewResult.userCancelled() =>
      const ImportPreviewResult._(isCancelled: true);

  factory ImportPreviewResult.invalidFormat(String message) =>
      ImportPreviewResult._(isReady: false, error: message);
}

class ImportResult {
  final bool isSuccess;
  final String? error;
  final int settingsCount;
  final int periodRecordsCount;
  final int bookPeriodsCount;
  final int bookStagesCount;
  final int bookAdditionsCount;
  final int bookExpensesCount;
  final int bookLargeAdditionsCount;
  final int bookLargeExpensesCount;
  final int vaultCategoriesCount;
  final int vaultEntriesCount;

  const ImportResult._({
    this.isSuccess = false,
    this.error,
    this.settingsCount = 0,
    this.periodRecordsCount = 0,
    this.bookPeriodsCount = 0,
    this.bookStagesCount = 0,
    this.bookAdditionsCount = 0,
    this.bookExpensesCount = 0,
    this.bookLargeAdditionsCount = 0,
    this.bookLargeExpensesCount = 0,
    this.vaultCategoriesCount = 0,
    this.vaultEntriesCount = 0,
  });

  factory ImportResult.success({
    required int settingsCount,
    required int periodRecordsCount,
    int bookPeriodsCount = 0,
    int bookStagesCount = 0,
    int bookAdditionsCount = 0,
    int bookExpensesCount = 0,
    int bookLargeAdditionsCount = 0,
    int bookLargeExpensesCount = 0,
    int vaultCategoriesCount = 0,
    int vaultEntriesCount = 0,
  }) =>
      ImportResult._(
        isSuccess: true,
        settingsCount: settingsCount,
        periodRecordsCount: periodRecordsCount,
        bookPeriodsCount: bookPeriodsCount,
        bookStagesCount: bookStagesCount,
        bookAdditionsCount: bookAdditionsCount,
        bookExpensesCount: bookExpensesCount,
        bookLargeAdditionsCount: bookLargeAdditionsCount,
        bookLargeExpensesCount: bookLargeExpensesCount,
        vaultCategoriesCount: vaultCategoriesCount,
        vaultEntriesCount: vaultEntriesCount,
      );

  factory ImportResult.error(String message) =>
      ImportResult._(isSuccess: false, error: message);
}
