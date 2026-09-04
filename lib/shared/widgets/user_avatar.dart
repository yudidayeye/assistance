import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/theme/theme_extension.dart';

/// 用户圆形头像 — 渐变底圈 + 内圆（base64 图 / 默认人形图标）
///
/// 纯展示组件：不读 Controller，头像数据由外部注入，profile 用户卡与
/// 工具箱顶栏欢迎区共用。头像为空串 / 解码异常时回退默认人形图标。
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.avatarB64,
    this.size = 60,
    this.onTap,
  });

  /// 头像 base64（null / '' 时展示默认人形图标）
  final String? avatarB64;

  /// 外圈直径（profile 用 60，工具箱欢迎区用 ~52）
  final double size;

  /// 点击回调（null 则纯展示、不可点）
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            appTheme.primary.withValues(alpha: 0.18),
            appTheme.primaryLight.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(child: _buildFace(appTheme)),
    );

    if (onTap == null) return circle;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: circle,
    );
  }

  /// 内圆头像面：已设图展示图片，否则默认人形（尺寸按外圈 0.8 等比）
  Widget _buildFace(AppThemeExtension appTheme) {
    final face = size * 0.8;
    final raw = avatarB64;
    if (raw != null && raw.isNotEmpty) {
      try {
        final bytes = base64Decode(raw);
        return ClipOval(
          child: SizedBox(
            width: face,
            height: face,
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildDefaultFace(appTheme),
            ),
          ),
        );
      } catch (_) {
        // base64 数据异常时回退默认人形
      }
    }
    return _buildDefaultFace(appTheme);
  }

  /// 默认人形头像（无自定义头像 / 头像数据异常时展示）
  Widget _buildDefaultFace(AppThemeExtension appTheme) {
    final face = size * 0.8;
    return Container(
      width: face,
      height: face,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: appTheme.primary.withValues(alpha: 0.12),
      ),
      child: Icon(
        Icons.person_rounded,
        color: appTheme.primary,
        size: face * 28 / 48,
      ),
    );
  }
}
