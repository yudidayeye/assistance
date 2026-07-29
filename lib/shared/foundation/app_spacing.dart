import 'package:flutter/material.dart';

/// 间距系统 — 根据 UI.md 文档定义的 Apple 设计间距
///
/// Base unit: 8px
/// Tokens: xxs=4, xs=8, sm=12, md=17, lg=24, xl=32, xxl=48, section=80
class AppSpacing {
  AppSpacing._();

  // ── 数值 token（对齐 UI.md 文档） ──
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 17;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double section = 80;

  // ── 水平 SizedBox ──
  static const SizedBox w2 = SizedBox(width: 2);
  static const SizedBox w4 = SizedBox(width: xxs);
  static const SizedBox w6 = SizedBox(width: 6);
  static const SizedBox w8 = SizedBox(width: xs);
  static const SizedBox w10 = SizedBox(width: 10);
  static const SizedBox w12 = SizedBox(width: sm);
  static const SizedBox w16 = SizedBox(width: 16);
  static const SizedBox w17 = SizedBox(width: md);
  static const SizedBox w20 = SizedBox(width: 20);
  static const SizedBox w24 = SizedBox(width: lg);

  // ── 垂直 SizedBox ──
  static const SizedBox h2 = SizedBox(height: 2);
  static const SizedBox h4 = SizedBox(height: xxs);
  static const SizedBox h6 = SizedBox(height: 6);
  static const SizedBox h8 = SizedBox(height: xs);
  static const SizedBox h10 = SizedBox(height: 10);
  static const SizedBox h12 = SizedBox(height: sm);
  static const SizedBox h14 = SizedBox(height: 14);
  static const SizedBox h16 = SizedBox(height: 16);
  static const SizedBox h17 = SizedBox(height: md);
  static const SizedBox h18 = SizedBox(height: 18);
  static const SizedBox h20 = SizedBox(height: 20);
  static const SizedBox h22 = SizedBox(height: 22);
  static const SizedBox h24 = SizedBox(height: lg);
  static const SizedBox h32 = SizedBox(height: xl);
  static const SizedBox h40 = SizedBox(height: 40);
  static const SizedBox h48 = SizedBox(height: xxl);
  static const SizedBox h80 = SizedBox(height: section);

  // ── 常用 EdgeInsets（对齐 UI.md 文档） ──
  /// 页面水平边距 16px
  static const EdgeInsets pageH = EdgeInsets.symmetric(horizontal: 16);

  /// 卡片内边距 24px
  static const EdgeInsets cardPad = EdgeInsets.all(lg);

  /// 按钮内边距（垂直 11px，水平 22px）
  static const EdgeInsets btnPad = EdgeInsets.symmetric(horizontal: 22, vertical: 11);

  /// 弹窗内边距 24px
  static const EdgeInsets dialogPad = EdgeInsets.all(lg);

  /// 列表项水平边距 20px
  static const EdgeInsets listItemH = EdgeInsets.symmetric(horizontal: 20);

  /// 列表项垂直边距 8px
  static const EdgeInsets listItemV = EdgeInsets.symmetric(vertical: 8);
}
