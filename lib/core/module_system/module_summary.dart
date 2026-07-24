/// 首页模块摘要数据结构
class ModuleSummary {
  final String line1;
  final String? line2;

  const ModuleSummary({required this.line1, this.line2});

  @override
  String toString() {
    if (line2 != null) return '$line1\n$line2';
    return line1;
  }
}
