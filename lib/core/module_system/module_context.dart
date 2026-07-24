/// 模块上下文 — 提供模块运行所需的基础服务
class ModuleContext {
  final String moduleId;

  ModuleContext({required this.moduleId});

  /// 获取模块专属的数据库表前缀
  String get tablePrefix => 'mod_$moduleId';
}
