import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/section_card.dart';

class InfoQueryPage extends StatelessWidget {
  const InfoQueryPage({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).appTheme;
    return AppScaffold(
      appBar: AppBar(title: const Text('资讯查询'), backgroundColor: theme.cream),
      body: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SectionCard(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Icon(Icons.insights_rounded, color: theme.primary),
              title: const Text('AI 模型能力与价格'),
              subtitle: const Text('查询最新榜单，比较智能指数与使用成本'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/info_query/ai-models'),
            ),
          )),
    );
  }
}
