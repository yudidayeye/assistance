import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../models/ai_model.dart';
import '../services/ai_leaderboard_service.dart';
import '../widgets/ai_relation_chart.dart';

class AiModelsPage extends StatefulWidget {
  final AiLeaderboardService? service;
  const AiModelsPage({super.key, this.service});
  @override
  State<AiModelsPage> createState() => _AiModelsPageState();
}

class _AiModelsPageState extends State<AiModelsPage> {
  AiLeaderboardService get _service =>
      widget.service ?? AiLeaderboardService.instance;
  AiSnapshot? _snapshot;
  bool _querying = false;
  bool _cached = false;
  String? _error;
  String _search = '';
  String? _creator;
  AiCostMetric _metric = AiCostMetric.task;
  AiModel? _selected;

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  Future<void> _loadCache() async {
    try {
      final cached = await _service.cached();
      if (mounted && _snapshot == null && cached != null) {
        setState(() {
          _snapshot = cached;
          _cached = true;
        });
      }
    } catch (_) {/* 缓存不可用时仍可查询。 */}
  }

  Future<void> _query() async {
    if (_querying) return;
    setState(() {
      _querying = true;
      _error = null;
    });
    try {
      final result = await _service.query();
      if (!mounted) return;
      setState(() {
        _snapshot = result;
        _cached = false;
        _selected = null;
        if (_creator != null &&
            !topCreators(result.models).contains(_creator)) {
          _creator = null;
        }
      });
    } on AiQueryException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _cached = _snapshot != null;
        });
      }
    } finally {
      if (mounted) setState(() => _querying = false);
    }
  }

  Future<void> _openSource() async {
    try {
      if (await launchUrl(Uri.parse(AiLeaderboardService.sourceUrl),
          mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {/* 页面提供明确失败反馈。 */}
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无法打开浏览器，请稍后重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).appTheme;
    final creators = topCreators(_snapshot?.models ?? []);
    final allowed = creators.toSet();
    final models = (_snapshot?.models ?? [])
        .where((m) =>
            allowed.contains(m.creator) &&
            (_creator == null || m.creator == _creator) &&
            '${m.name} ${m.creator}'
                .toLowerCase()
                .contains(_search.toLowerCase()))
        .toList();
    final frontier = paretoFrontier(models, _metric).map((m) => m.slug).toSet();
    final plotCount = models.where((m) => (m.cost(_metric) ?? 0) > 0).length;
    final date = _snapshot?.fetchedAt
        .toLocal()
        .toIso8601String()
        .substring(0, 16)
        .replaceFirst('T', ' ');
    return AppScaffold(
      appBar:
          AppBar(title: const Text('AI 模型能力与价格'), backgroundColor: theme.cream),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('能力 × 成本',
            style: AppTypography.displayLg.copyWith(color: theme.earth)),
        const SizedBox(height: 8),
        const Text('越靠左上，表示成本更低、能力更强。点击圆点或模型条目查看详情。'),
        const SizedBox(height: 16),
        FilledButton.icon(
            onPressed: _querying ? null : _query,
            icon: _querying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded),
            label: Text(_querying ? '正在查询…' : '查询最新数据')),
        TextButton.icon(
            onPressed: _openSource,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('查看原始榜单 · Artificial Analysis')),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error))),
        if (_snapshot == null)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text('点击查询获取当前公开榜单。查询仅访问数据源，不发送你的记账或其他本地数据。')),
        if (_snapshot != null) ...[
          Text('${_cached ? "上次查询缓存" : "本次获取"}：$date',
              style: AppTypography.caption.copyWith(color: theme.earthLight)),
          const Text('以上为获取时间；数据更新频率以源站为准。', style: AppTypography.caption),
          const Text('仅展示前20家厂商，按各厂商最高智能指数排名。', style: AppTypography.caption),
          const SizedBox(height: 16),
          TextField(
              decoration: const InputDecoration(
                  labelText: '搜索模型或厂商', prefixIcon: Icon(Icons.search)),
              onChanged: (value) => setState(() {
                    _search = value;
                    _selected = null;
                  })),
          const SizedBox(height: 12),
          Wrap(spacing: 16, runSpacing: 8, children: [
            DropdownButton<AiCostMetric>(
                value: _metric,
                items: AiCostMetric.values
                    .map(
                        (m) => DropdownMenuItem(value: m, child: Text(m.label)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _metric = value;
                      _selected = null;
                    });
                  }
                }),
            DropdownButton<String>(
                value: _creator ?? '',
                items: [
                  const DropdownMenuItem(value: '', child: Text('前20家厂商')),
                  ...creators
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                ],
                onChanged: (value) => setState(() {
                      _creator = value == '' ? null : value;
                      _selected = null;
                    })),
          ]),
          const SizedBox(height: 8),
          Text('${_metric.label}（${_metric.unit}） · $plotCount 个模型入图'),
          if (_metric == AiCostMetric.task)
            const Text('与图片同口径：完成智能指数评测任务的加权平均成本。',
                style: AppTypography.caption)
          else
            const Text('Token 单价与每任务成本口径不同，不能直接互换。',
                style: AppTypography.caption),
          AiRelationChart(
              models: models,
              metric: _metric,
              selectedSlug: _selected?.slug,
              onSelected: _showDetails),
          TextButton.icon(
              onPressed: () => _showLargeChart(models),
              icon: const Icon(Icons.fullscreen_rounded),
              label: const Text('放大关系图')),
          if (models
              .any((m) => m.cost(_metric) == null || m.cost(_metric) == 0))
            const Text('未公布成本或免费模型仅在列表展示，不放入对数坐标轴。',
                style: AppTypography.caption),
          const SizedBox(height: 8),
          const Text('虚线为优势前沿；绿色区域表示低于当前模型成本中位数、同时高于能力中位数。',
              style: AppTypography.caption),
          const SizedBox(height: 12),
          Wrap(
              spacing: 12,
              runSpacing: 6,
              children: models
                  .map((m) => m.creator)
                  .toSet()
                  .map((c) => Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.circle, size: 8, color: creatorColor(c)),
                        const SizedBox(width: 4),
                        Text(c, style: AppTypography.caption)
                      ]))
                  .toList()),
          const SizedBox(height: 16),
          Text('模型明细（${models.length}）', style: AppTypography.displayMd),
          if (models.isEmpty)
            const Padding(
                padding: EdgeInsets.all(16), child: Text('没有符合筛选条件的模型')),
          ...models.map((m) => ListTile(
              contentPadding: EdgeInsets.zero,
              selected: _selected?.slug == m.slug,
              title: Text(m.name),
              subtitle: Text(
                  '${m.creator} · 智能指数 ${m.intelligence.toStringAsFixed(1)}${m.estimated ? "（估计）" : ""}'),
              trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(m.cost(_metric) == null
                        ? '未公布'
                        : '\$${m.cost(_metric)!.toStringAsFixed(4)}'),
                    if (frontier.contains(m.slug))
                      Text('优势前沿',
                          style: AppTypography.caption
                              .copyWith(color: theme.primary)),
                  ]),
              onTap: () => _showDetails(m))),
        ],
      ]),
    );
  }

  void _showLargeChart(List<AiModel> models) {
    showDialog<void>(
        context: context,
        builder: (ctx) => Dialog.fullscreen(
              child: AppScaffold(
                  appBar: AppBar(
                      title: const Text('能力与成本关系图'),
                      leading: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx))),
                  body: Column(children: [
                    Text('${_metric.label}（${_metric.unit}） · 支持双指缩放、拖动'),
                    Expanded(
                        child: InteractiveViewer(
                            constrained: false,
                            minScale: 0.3,
                            maxScale: 4,
                            child: SizedBox(
                                width: 1000,
                                height: 520,
                                child: AiRelationChart(
                                    models: models,
                                    metric: _metric,
                                    height: 520,
                                    selectedSlug: _selected?.slug,
                                    onSelected: (model) => showModalBottomSheet<
                                            void>(
                                        context: ctx,
                                        isScrollControlled: true,
                                        builder: (_) => SafeArea(
                                            child: SingleChildScrollView(
                                                child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            24),
                                                    child:
                                                        _details(model))))))))),
                  ])),
            ));
  }

  Widget _details(AiModel model) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(model.name, style: AppTypography.displayMd),
            Text(
                '${model.creator} · 智能指数 ${model.intelligence.toStringAsFixed(2)}${model.estimated ? "（估计值）" : ""}'),
            for (final metric in AiCostMetric.values)
              Text(
                  '${metric.label}：${model.cost(metric) == null ? "未公布" : "\$${model.cost(metric)!.toStringAsFixed(4)}"} ${metric.unit}'),
          ]);
  void _showDetails(AiModel model) {
    setState(() => _selected = model);
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(child: _details(model)))));
  }
}
