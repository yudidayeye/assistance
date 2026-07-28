import 'package:flutter/material.dart';

/// 间距系统 — 将 AppThemeExtension 中的 spaceXs~spaceXl 具象化为 SizedBox / EdgeInsets 常量
///
/// 消除项目中 200+ 处硬编码 `SizedBox(height: N)` / `EdgeInsets` 数字。
class AppSpacing {
  AppSpacing._();

  // ── 数值 token ──
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  // ── 水平 SizedBox ──
  static const SizedBox w2 = SizedBox(width: 2);
  static const SizedBox w4 = SizedBox(width: 4);
  static const SizedBox w6 = SizedBox(width: 6);
  static const SizedBox w8 = SizedBox(width: 8);
  static const SizedBox w10 = SizedBox(width: 10);
  static const SizedBox w12 = SizedBox(width: 12);
  static const SizedBox w16 = SizedBox(width: 16);
  static const SizedBox w20 = SizedBox(width: 20);
  static const SizedBox w24 = SizedBox(width: 24);

  // ── 垂直 SizedBox ──
  static const SizedBox h2 = SizedBox(height: 2);
  static const SizedBox h4 = SizedBox(height: 4);
  static const SizedBox h6 = SizedBox(height: 6);
  static const SizedBox h8 = SizedBox(height: 8);
  static const SizedBox h10 = SizedBox(height: 10);
  static const SizedBox h12 = SizedBox(height: 12);
  static const SizedBox h14 = SizedBox(height: 14);
  static const SizedBox h16 = SizedBox(height: 16);
  static const SizedBox h18 = SizedBox(height: 18);
  static const SizedBox h20 = SizedBox(height: 20);
  static const SizedBox h22 = SizedBox(height: 22);
  static const SizedBox h24 = SizedBox(height: 24);
  static const SizedBox h32 = SizedBox(height: 32);
  static const SizedBox h40 = SizedBox(height: 40);
  static const SizedBox h48 = SizedBox(height: 48);

  // ── 常用 EdgeInsets ──
  static const EdgeInsets pageH = EdgeInsets.symmetric(horizontal: 16);
  static const EdgeInsets pageH20 = EdgeInsets.symmetric(horizontal: 20);
  static const EdgeInsets pageH24 = EdgeInsets.symmetric(horizontal: 24);
  static const EdgeInsets cardPad = EdgeInsets.symmetric(horizontal: 16, vertical: 14);
  static const EdgeInsets cardPadLg = EdgeInsets.all(24);
  static const EdgeInsets btnPadV = EdgeInsets.symmetric(vertical: 14);
  static const EdgeInsets btnPadM = EdgeInsets.symmetric(horizontal: 28, vertical: 16);
  static const EdgeInsets dialogPad = EdgeInsets.all(28);
  static const EdgeInsets listItemH = EdgeInsets.symmetric(horizontal: 20, vertical: 8);
}
