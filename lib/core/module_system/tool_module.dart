import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'module_context.dart';
import 'module_summary.dart';

/// 模块图标类型
class ModuleIcon {
  final IconData? iconData;
  final String? assetPath;

  const ModuleIcon.icon(IconData data)
      : iconData = data,
        assetPath = null;
  const ModuleIcon.asset(String path)
      : iconData = null,
        assetPath = path;

  Widget build({double size = 32, Color? color}) {
    if (iconData != null) {
      return Icon(iconData, size: size, color: color);
    }
    if (assetPath != null) {
      return Image.asset(assetPath!, width: size, height: size);
    }
    return Icon(Icons.extension, size: size, color: color);
  }
}

/// 工具模块抽象接口
abstract class ToolModule implements ModuleSummaryProvider {
  /// 模块唯一标识
  String get moduleId;

  /// 显示名称
  String get displayName;

  /// 模块描述
  String get description;

  /// 模块图标
  ModuleIcon get icon;

  /// 模块主题色（用于首页卡片背景渐变）
  Color get themeColor;

  /// 模块入口页面 Widget
  Widget buildEntryPage(BuildContext context);

  /// 模块设置页面（可选）
  Widget? buildSettingsPage(BuildContext context);

  /// 模块子路由（模块自行声明，默认返回空列表）
  List<RouteBase> buildSubRoutes() => [];

  /// 模块注册时的初始化逻辑（如建表、迁移）
  Future<void> onRegister(ModuleContext context);

  /// 模块被打开时的逻辑
  Future<void> onOpen(ModuleContext context);

  /// 模块被关闭/切换时的清理逻辑
  Future<void> onClose(ModuleContext context);
}

/// 模块摘要提供者接口
abstract class ModuleSummaryProvider {
  /// 返回首页卡片摘要信息
  Future<ModuleSummary> getSummary();
}
