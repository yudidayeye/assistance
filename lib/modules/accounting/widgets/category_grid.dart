import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../../../core/theme/theme_extension.dart';

/// 分类选择网格 — 奢华自然主义风格
class CategoryGrid extends StatelessWidget {
  final TransactionType type;
  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<Category> onCategorySelected;

  const CategoryGrid({
    super.key,
    required this.type,
    required this.categories,
    this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;
    final accentColor =
        type == TransactionType.expense ? appTheme.rose : appTheme.sage;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final isSelected = cat.id == selectedCategoryId;

        return GestureDetector(
          onTap: () => onCategorySelected(cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withAlpha(25)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? accentColor.withAlpha(80)
                    : appTheme.earthMedium.withAlpha(20),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: accentColor.withAlpha(30),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 图标容器
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withAlpha(40)
                        : appTheme.creamDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    cat.icon,
                    size: 20,
                    color: isSelected ? accentColor : appTheme.earthMedium,
                  ),
                ),
                const SizedBox(height: 8),

                // 分类名称
                Text(
                  cat.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? accentColor : appTheme.earthMedium,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
