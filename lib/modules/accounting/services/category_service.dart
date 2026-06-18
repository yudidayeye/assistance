import '../../../core/storage/database_service.dart';
import '../models/category.dart';
import '../models/transaction.dart';

/// 分类服务
class CategoryService {
  static final CategoryService instance = CategoryService._();
  CategoryService._();

  final DatabaseService _db = DatabaseService.instance;
  static const String _table = 'mod_accounting_categories';

  bool _initialized = false;

  /// 初始化预设分类
  Future<void> initializeDefaultCategories() async {
    if (_initialized) return;
    final count = (await _db.query(_table)).length;
    if (count == 0) {
      for (final cat in defaultExpenseCategories) {
        await _db.insert(_table, cat.toMap());
      }
      for (final cat in defaultIncomeCategories) {
        await _db.insert(_table, cat.toMap());
      }
    }
    _initialized = true;
  }

  /// 获取所有支出分类
  Future<List<Category>> getExpenseCategories() async {
    final rows = await _db.query(
      _table,
      where: 'type = ?',
      whereArgs: ['expense'],
      orderBy: 'sort_order ASC',
    );
    return rows.map((r) => Category.fromMap(r)).toList();
  }

  /// 获取所有收入分类
  Future<List<Category>> getIncomeCategories() async {
    final rows = await _db.query(
      _table,
      where: 'type = ?',
      whereArgs: ['income'],
      orderBy: 'sort_order ASC',
    );
    return rows.map((r) => Category.fromMap(r)).toList();
  }

  /// 获取指定类型的所有分类
  Future<List<Category>> getCategories(TransactionType type) async {
    if (type == TransactionType.expense) {
      return getExpenseCategories();
    }
    return getIncomeCategories();
  }

  /// 根据ID获取分类
  Future<Category?> getCategory(String id) async {
    final rows = await _db.query(_table, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Category.fromMap(rows.first);
  }

  /// 添加自定义分类
  Future<void> addCustomCategory(Category category) async {
    await _db.insert(_table, category.toMap());
  }

  /// 删除自定义分类
  Future<void> deleteCategory(String id) async {
    await _db.delete(_table, where: 'id = ? AND is_custom = 1', whereArgs: [id]);
  }

  /// 获取所有分类
  Future<List<Category>> getAllCategories() async {
    final rows = await _db.query(_table, orderBy: 'sort_order ASC');
    return rows.map((r) => Category.fromMap(r)).toList();
  }
}