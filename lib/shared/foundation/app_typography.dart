import 'package:flutter/material.dart';

/// 排版系统 — Apple SF Pro 风格 + 负字间距
///
/// 使用系统默认字体（iOS/macOS 自动为 SF Pro，Android 为 Roboto），
/// 融入 Apple 设计的紧凑负字间距风格。
class AppTypography {
  AppTypography._();

  // ── 字体族（使用系统默认，iOS/macOS 自动为 SF Pro） ──
  static const String? system = null;

  // ── 弹窗 / 焦点标题 ──
  static const TextStyle displayLg = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );
  static const TextStyle displayMd = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
  );
  static const TextStyle displaySm = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  // ── Header 标题 ──
  static const TextStyle headerTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  // ── 正文 / 按钮 / 标签 ──
  static const TextStyle bodyLg = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );
  static const TextStyle bodyMd = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
  );
  static const TextStyle bodySm = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
  );
  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    letterSpacing: -0.2,
  );
}
