import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 排版系统 — 缓存字体族 + 预定义 TextStyle
///
/// 消除项目中 56+ 次 `GoogleFonts.dmSans().fontFamily` 重复调用，
/// 集中管理 299 处内联 TextStyle 的常用组合。
class AppTypography {
  AppTypography._();

  // ── 字体族缓存（各加载一次） ──
  static final String dmSans = GoogleFonts.dmSans().fontFamily!;
  static final String playfair = GoogleFonts.playfairDisplay().fontFamily!;

  // ── 弹窗 / 焦点标题（Playfair Display） ──
  static final TextStyle displayLg = TextStyle(
    fontFamily: playfair,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );
  static final TextStyle displayMd = TextStyle(
    fontFamily: playfair,
    fontSize: 19,
    fontWeight: FontWeight.w600,
  );
  static final TextStyle displaySm = TextStyle(
    fontFamily: playfair,
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  // ── Header 标题（DM Sans 16 / 700） ──
  static final TextStyle headerTitle = TextStyle(
    fontFamily: dmSans,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
  );

  // ── 正文 / 按钮 / 标签（DM Sans） ──
  static final TextStyle bodyLg = TextStyle(
    fontFamily: dmSans,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
  static final TextStyle bodyMd = TextStyle(
    fontFamily: dmSans,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
  static final TextStyle bodySm = TextStyle(
    fontFamily: dmSans,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );
  static final TextStyle label = TextStyle(
    fontFamily: dmSans,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );
  static final TextStyle caption = TextStyle(
    fontSize: 11,
  );
}
