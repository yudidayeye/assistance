import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/module_system/tool_module.dart';
import '../../core/module_system/module_context.dart';
import '../../core/module_system/module_summary.dart';
import 'services/transfer_service.dart';
import 'pages/file_transfer_page.dart';

/// 文件互传模块注册
class FileTransferModule implements ToolModule {
  @override
  String get moduleId => 'file_transfer';

  @override
  String get displayName => '文件互传';

  @override
  String get description => '手机与电脑局域网文件互传';

  @override
  ModuleIcon get icon => const ModuleIcon.icon(Icons.swap_horiz_rounded);

  @override
  Color get themeColor => const Color(0xFF5B9BD5); // 科技蓝

  @override
  Widget buildEntryPage(BuildContext context) => const FileTransferPage();

  @override
  Widget? buildSettingsPage(BuildContext context) => null;

  @override
  List<RouteBase> buildSubRoutes() => [];

  @override
  Future<void> onRegister(ModuleContext context) async {}

  @override
  Future<void> onOpen(ModuleContext context) async {}

  @override
  Future<void> onClose(ModuleContext context) async {}

  @override
  Future<ModuleSummary> getSummary() async {
    final records = await TransferService.instance.getRecords(limit: 1);
    if (records.isNotEmpty) {
      final last = records.first;
      final direction = last.direction.name == 'upload' ? '手机→电脑' : '电脑→手机';
      return ModuleSummary(
        line1: '最近: ${last.fileName}',
        line2: '$direction · ${_formatStatus(last.status.name)}',
      );
    }
    return const ModuleSummary(line1: '点击开始传文件');
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'completed':
        return '已完成';
      case 'transferring':
        return '传输中';
      case 'failed':
        return '失败';
      default:
        return '等待中';
    }
  }
}
