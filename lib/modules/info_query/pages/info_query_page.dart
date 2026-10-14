import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/foundation/app_typography.dart';
import '../widgets/info_query_card.dart';
import '../widgets/info_query_typography.dart';

class InfoQueryPage extends StatelessWidget {
  const InfoQueryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).appTheme;
    return AppScaffold(
      appBar: AppBar(
        title: Text('资讯查询',
            style: AppTypography.headerTitle.copyWith(color: theme.earth)),
        centerTitle: false,
        titleSpacing: Navigator.of(context).canPop() ? 0 : null,
        automaticallyImplyLeading: true,
        backgroundColor: theme.cream,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              InfoQueryCard(
                onTap: () => context.push('/info_query/ai-models'),
                child: Row(children: [
                  Icon(Icons.insights_rounded, color: theme.primary, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AI 模型能力与价格',
                          style: InfoQueryTypography.strong),
                      const SizedBox(height: 8),
                      Text('比较智能指数与使用成本',
                          style: InfoQueryTypography.caption
                              .copyWith(color: theme.earthLight)),
                    ],
                  )),
                  const SizedBox(width: 12),
                  Icon(Icons.chevron_right_rounded,
                      color: theme.earthLight, size: 20),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
