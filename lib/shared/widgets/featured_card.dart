import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/module_system/tool_module.dart';
import 'package:go_router/go_router.dart';

/// 特色功能卡片 — 工具箱首页展示卡片
/// 对应 Figma 设计中的 tall gradient card（绿色/粉色渐变）
class FeaturedCard extends StatelessWidget {
  final ToolModule module;
  final String categoryLabel;
  final LinearGradient gradient;
  final VoidCallback? onTap;
  final bool vertical;

  const FeaturedCard({
    super.key,
    required this.module,
    required this.categoryLabel,
    required this.gradient,
    this.onTap,
    this.vertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final shadowColor = gradient.colors.first.withAlpha(0x30);

    return GestureDetector(
      onTap: onTap ?? () => context.push('/${module.moduleId}'),
      child: Container(
        height: vertical ? 160 : 124,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 32,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            // 装饰性半透明圆形
            _buildDecoCircle(
              top: -32,
              right: 30,
              size: 144,
              alpha: 38,
            ),
            _buildDecoCircle(
              bottom: -16,
              left: -16,
              size: 112,
              alpha: 25,
            ),

            if (vertical)
              // 两列模式：垂直布局
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 图标
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(51),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: module.icon.build(size: 22, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 分类标签
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(64),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        categoryLabel,
                        style: TextStyle(
                          fontFamily: GoogleFonts.dmSans().fontFamily,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // 标题
                    Text(
                      module.displayName,
                      style: TextStyle(
                        fontFamily: GoogleFonts.robotoSlab().fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),

                    // 副标题
                    Text(
                      module.description,
                      style: TextStyle(
                        fontFamily: GoogleFonts.dmSans().fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withAlpha(191),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              )
            else
              // 单列模式：水平布局
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    // 左侧：64x64 图标容器
                    _buildIconContainer(),
                    const SizedBox(width: 16),

                    // 中间：分类标签 + 标题 + 副标题
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildCategoryPill(),
                          const SizedBox(height: 8),
                          Text(
                            module.displayName,
                            style: TextStyle(
                              fontFamily: GoogleFonts.robotoSlab().fontFamily,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            module.description,
                            style: TextStyle(
                              fontFamily: GoogleFonts.dmSans().fontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withAlpha(191),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // 右侧：箭头图标
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Colors.white.withAlpha(191),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecoCircle({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required int alpha,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(alpha),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildIconContainer() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(51),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: module.icon.build(size: 32, color: Colors.white),
      ),
    );
  }

  Widget _buildCategoryPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(64),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        categoryLabel,
        style: TextStyle(
          fontFamily: GoogleFonts.dmSans().fontFamily,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
