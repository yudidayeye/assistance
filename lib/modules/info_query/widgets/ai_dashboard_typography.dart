import 'package:flutter/material.dart';

/// 模型仪表盘采用设计图中的紧凑排版，不影响资讯入口等页面。
class AiDashboardTypography {
  AiDashboardTypography._();
  static const title = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.25,
      letterSpacing: -0.23);
  static const body =
      TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.47);
  static const strong =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.24);
  static const caption =
      TextStyle(fontSize: 11, fontWeight: FontWeight.w400, height: 1.4);
}
