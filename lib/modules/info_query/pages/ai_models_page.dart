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
  final Set<String> _selectedCreators = {};
  double _minimumScore = 35;
  List<AiModel> get _scoreModels =>
      modelsAboveScore(_snapshot?.models ?? [], _minimumScore);
  double get _highestScore => (_snapshot?.models ?? []).fold<double>(
      0,
      (highest, model) =>
          model.intelligence > highest ? model.intelligence : highest);
  double get _sliderMax => _highestScore > 35 ? _highestScore : 35;
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
        _minimumScore = _minimumScore.clamp(0, _sliderMax).toDouble();
        _selectedCreators.retainAll(_scoreModels.map((m) => m.creator));
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
    final creators = _scoreModels.map((m) => m.creator).toSet().toList();
    final models = _scoreModels
        .where((m) =>
            (_selectedCreators.isEmpty ||
                _selectedCreators.contains(m.creator)) &&
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
          Text(
              '智能指数 ≥ ${_minimumScore.toStringAsFixed(1)} · 目前最高 ${_highestScore.toStringAsFixed(1)}',
              style: AppTypography.label),
          Slider(
              value: _minimumScore,
              min: 0,
              max: _sliderMax,
              label: _minimumScore.toStringAsFixed(1),
              semanticFormatterCallback: (value) =>
                  '最低智能指数 ${value.toStringAsFixed(1)} 分',
              onChanged: (value) => setState(() {
                    _minimumScore = ((value * 10).round() / 10)
                        .clamp(0, _sliderMax)
                        .toDouble();
                    _selected = null;
                    _selectedCreators
                        .retainAll(_scoreModels.map((m) => m.creator));
                  })),
          const Text('拖动滑动条调整最低分数，模型按智能指数从高到低排列。',
              style: AppTypography.caption),
          const SizedBox(height: 16),
          TextField(
              decoration: const InputDecoration(
                  labelText: '搜索模型或厂商', prefixIcon: Icon(Icons.search)),
              onChanged: (value) => setState(() {
                    _search = value;
                    _selected = null;
                  })),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: DropdownButton<AiCostMetric>(
              isExpanded: true,
              value: _metric,
              items: AiCostMetric.values
                  .map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(m.label,
                          maxLines: 1, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _metric = value;
                    _selected = null;
                  });
                }
              },
            )),
            const SizedBox(width: 16),
            Expanded(
                child: TextButton.icon(
              onPressed:
                  creators.isEmpty ? null : () => _chooseCreators(creators),
              icon: const Icon(Icons.filter_list_rounded, size: 16),
              label: Text(
                  _selectedCreators.isEmpty
                      ? '厂商：全部'
                      : '厂商：${_selectedCreators.length} 家',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            )),
          ]),
          if (_selectedCreators.isNotEmpty)
            Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _selectedCreators
                    .map((creator) => InputChip(
                          label: ConstrainedBox(
                              constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.sizeOf(context).width - 112),
                              child: Text(creator,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                          onDeleted: () => setState(() {
                            _selectedCreators.remove(creator);
                            _selected = null;
                          }),
                        ))
                    .toList()),
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
                  .map((c) => ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width - 32),
                        child: Tooltip(
                            message: c,
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.circle,
                                  size: 8, color: creatorColor(c)),
                              const SizedBox(width: 4),
                              Flexible(
                                  child: Text(c,
                                      style: AppTypography.caption,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis)),
                            ])),
                      ))
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

  Future<void> _chooseCreators(List<String> creators) async {
    final pending = Set<String>.of(_selectedCreators);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, updateSheet) => SafeArea(
                child: SizedBox(
                  height: MediaQuery.sizeOf(ctx).height * 0.75,
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              const Expanded(
                                  child: Text('选择厂商（可多选）',
                                      style: AppTypography.displayMd)),
                              TextButton(
                                  onPressed: () => updateSheet(pending.clear),
                                  child: const Text('清空选择')),
                            ]),
                            Text(
                                '只列出智能指数 ≥ ${_minimumScore.toStringAsFixed(1)} 的厂商；不单独选择时展示全部。',
                                style: AppTypography.caption),
                            Expanded(
                                child: ListView.builder(
                                    itemCount: creators.length,
                                    itemBuilder: (ctx, index) {
                                      final creator = creators[index];
                                      return CheckboxListTile(
                                          key: ValueKey(
                                              'creator-option-$creator'),
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(creator),
                                          value: pending.contains(creator),
                                          onChanged: (value) => updateSheet(() {
                                                if (value == true) {
                                                  pending.add(creator);
                                                } else {
                                                  pending.remove(creator);
                                                }
                                              }));
                                    })),
                            Row(children: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('取消')),
                              const Spacer(),
                              FilledButton(
                                  onPressed: () => Navigator.pop(
                                      ctx, Set<String>.of(pending)),
                                  child: const Text('确定')),
                            ]),
                          ])),
                ),
              )),
    );
    if (!mounted || result == null) return;
    setState(() {
      _selectedCreators
        ..clear()
        ..addAll(
            result.intersection(_scoreModels.map((m) => m.creator).toSet()));
      _selected = null;
    });
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
