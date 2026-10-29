import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../models/ai_model.dart';
import '../services/ai_leaderboard_service.dart';
import '../widgets/ai_relation_chart.dart';
import '../widgets/ai_dashboard_summary.dart';
import '../widgets/info_query_card.dart';
import '../widgets/ai_dashboard_typography.dart';
import '../widgets/ai_filter_select.dart';

class AiModelsPage extends StatefulWidget {
  final AiLeaderboardService? service;
  const AiModelsPage({super.key, this.service});
  @override
  State<AiModelsPage> createState() => _AiModelsPageState();
}

class _AiModelsPageState extends State<AiModelsPage> {
  static const double _defaultMinimumScore = 25;
  AiLeaderboardService get _service =>
      widget.service ?? AiLeaderboardService.instance;
  AiSnapshot? _snapshot;
  bool _querying = false;
  bool _cached = false;
  String? _error;
  String _search = '';
  final _searchController = TextEditingController();
  double _maximumCost = 0;
  bool _sortByCost = false;
  final _openFilter = ValueNotifier<String?>(null);
  final Set<String> _selectedCreators = {};
  final Set<String> _hiddenCreators = {};
  double _minimumScore = _defaultMinimumScore;
  int _legendPage = 0;
  List<AiModel> get _scoreModels =>
      modelsAboveScore(_snapshot?.models ?? [], _minimumScore);
  double get _highestScore => (_snapshot?.models ?? []).fold<double>(
      0,
      (highest, model) =>
          model.intelligence > highest ? model.intelligence : highest);
  double get _sliderMax => _highestScore > _defaultMinimumScore
      ? _highestScore
      : _defaultMinimumScore;
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
        _hiddenCreators.retainAll(result.models.map((m) => m.creator));
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
  void dispose() {
    _openFilter.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _search = '';
      _minimumScore = _defaultMinimumScore;
      _maximumCost = 0;
      _sortByCost = false;
      _selectedCreators.clear();
      _hiddenCreators.clear();
      _selected = null;
      _legendPage = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).appTheme;
    final scoreModels = _scoreModels;
    final creators = scoreModels.map((m) => m.creator).toSet().toList()..sort();
    final models = scoreModels
        .where((m) =>
            (_selectedCreators.isEmpty ||
                _selectedCreators.contains(m.creator)) &&
            (_maximumCost == 0 ||
                (m.cost(_metric) != null &&
                    m.cost(_metric)! <= _maximumCost)) &&
            '${m.name} ${m.creator}'
                .toLowerCase()
                .contains(_search.trim().toLowerCase()))
        .toList();
    if (_sortByCost) {
      models.sort((a, b) => (a.cost(_metric) ?? double.infinity)
          .compareTo(b.cost(_metric) ?? double.infinity));
    }
    final chartModels =
        models.where((m) => !_hiddenCreators.contains(m.creator)).toList();
    final date = _snapshot?.fetchedAt
        .toLocal()
        .toIso8601String()
        .substring(0, 16)
        .replaceFirst('T', ' ');
    final colors =
        creatorColors((_snapshot?.models ?? []).map((m) => m.creator));
    return AppScaffold(
      appBar: AppBar(
        title: Text('AI 模型能力与价格',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headerTitle.copyWith(color: theme.earth)),
        centerTitle: false,
        titleSpacing: Navigator.of(context).canPop() ? 0 : null,
        toolbarHeight: 32,
        elevation: 0,
        backgroundColor: theme.cream,
        scrolledUnderElevation: 0,
      ),
      body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: CustomScrollView(slivers: [
              SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  sliver: SliverMainAxisGroup(slivers: [
                    SliverToBoxAdapter(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (date != null)
                                      Expanded(
                                          child: Text(
                                              '${_cached ? "上次查询缓存" : "本次获取"}：$date',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AiDashboardTypography
                                                  .caption
                                                  .copyWith(
                                                      color:
                                                          theme.earthLight))),
                                    if (_snapshot != null) _queryButton(theme),
                                  ])),
                          if (_error != null)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Text(_error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))),
                          if (_snapshot == null)
                            InfoQueryCard(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text('按需获取公开榜单，查询后可离线查看。',
                                      style: AiDashboardTypography.body
                                          .copyWith(color: theme.earthLight)),
                                  const SizedBox(height: 12),
                                  _queryButton(theme),
                                ])),
                          if (_snapshot != null) ...[
                            AiDashboardSummary(
                                models: scoreModels,
                                metric: _metric,
                                date: date!),
                            const SizedBox(height: 12),
                            ValueListenableBuilder<String?>(
                                valueListenable: _openFilter,
                                builder: (context, value, child) =>
                                    _buildFilters(creators)),
                            const SizedBox(height: 12),
                            InfoQueryCard(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        const Expanded(
                                            child: Text('能力与成本关系图',
                                                style: AiDashboardTypography
                                                    .title)),
                                        IconButton(
                                            tooltip: '放大关系图',
                                            onPressed: () =>
                                                _showLargeChart(chartModels),
                                            padding: EdgeInsets.zero,
                                            style: IconButton.styleFrom(
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap),
                                            alignment: Alignment.center,
                                            constraints:
                                                const BoxConstraints.tightFor(
                                                    width: 28, height: 28),
                                            icon: Icon(Icons.fullscreen_rounded,
                                                size: 18,
                                                color: theme.earthLight))
                                      ]),
                                      Text(
                                          '每个点代表一个模型，展示能力水平与${_metric.label}的关系。',
                                          style: AiDashboardTypography.body
                                              .copyWith(
                                                  color: theme.earthLight)),
                                      const SizedBox(height: 8),
                                      AiRelationChart(
                                          height: 250,
                                          models: chartModels,
                                          metric: _metric,
                                          minimumScore: _minimumScore,
                                          colors: colors,
                                          selectedSlug: _selected?.slug,
                                          onSelected: _showDetails),
                                      const SizedBox(height: 12),
                                      _buildLegend(models, colors),
                                    ])),
                            const SizedBox(height: 12),
                            Container(
                                decoration: BoxDecoration(
                                  color: theme.cardBackground,
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(14)),
                                ),
                                padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          child: LayoutBuilder(
                                              builder: (context, constraints) {
                                            final heading = Text(
                                                '模型列表（${models.length}）',
                                                style: AiDashboardTypography
                                                    .title);
                                            final sort = SizedBox(
                                              width: 124,
                                              child: AiFilterSelect<bool>(
                                                key: const ValueKey(
                                                    'model-sort'),
                                                label: '模型排序',
                                                value: _sortByCost,
                                                compact: true,
                                                options: const [
                                                  AiFilterOption(
                                                      false, '智能指数优先',
                                                      description: '智能指数从高到低'),
                                                  AiFilterOption(true, '使用成本优先',
                                                      description: '使用成本从低到高'),
                                                ],
                                                onChanged: (value) => setState(
                                                    () => _sortByCost = value),
                                              ),
                                            );
                                            if (constraints.maxWidth < 310 ||
                                                MediaQuery.textScalerOf(context)
                                                        .scale(14) >
                                                    18) {
                                              return Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    heading,
                                                    const SizedBox(height: 8),
                                                    sort
                                                  ]);
                                            }
                                            return Row(children: [
                                              Expanded(child: heading),
                                              const SizedBox(width: 8),
                                              sort
                                            ]);
                                          })),
                                      const SizedBox(height: 8),
                                      if (models.isEmpty)
                                        const Padding(
                                            padding: EdgeInsets.all(16),
                                            child: Text('没有符合筛选条件的模型')),
                                    ])),
                          ],
                        ])),
                    SliverList.builder(
                      itemCount: models.length,
                      itemBuilder: (context, index) => Container(
                        padding: EdgeInsets.fromLTRB(
                            8, 0, 8, index == models.length - 1 ? 8 : 0),
                        decoration: BoxDecoration(
                          color: theme.cardBackground,
                          borderRadius: index == models.length - 1
                              ? const BorderRadius.vertical(
                                  bottom: Radius.circular(14))
                              : null,
                        ),
                        child: Column(children: [
                          _buildModelRow(models[index], colors),
                          if (index < models.length - 1)
                            Divider(
                                height: 1,
                                thickness: 0.5,
                                indent: 10,
                                endIndent: 10,
                                color:
                                    theme.earthMedium.withValues(alpha: 0.16)),
                        ]),
                      ),
                    ),
                  ])),
            ]),
          )),
    );
  }

  Future<void> _showFilterPanel(
      String name, Future<void> Function() open) async {
    _openFilter.value = name;
    try {
      await open();
    } finally {
      if (mounted) _openFilter.value = null;
    }
  }

  /// 「查询最新数据」按钮：与记账模块「添加支出」保持同一套按钮样式。
  Widget _queryButton(AppThemeExtension theme) => OutlinedButton.icon(
        onPressed: _querying ? null : _query,
        icon: _querying
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.refresh_rounded, size: 16),
        label: Text(_querying ? '正在查询…' : '查询最新数据'),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.primary,
          backgroundColor: theme.primary.withValues(alpha: 0.1),
          side: BorderSide(color: theme.primary.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      );

  Widget _buildFilters(List<String> creators) {
    final theme = Theme.of(context).appTheme;
    return InfoQueryCard(
        padding: const EdgeInsets.all(12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Text('筛选模型', style: AiDashboardTypography.title),
            IconButton(
                tooltip: '数据说明',
                onPressed: _showDataInfo,
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                alignment: Alignment.center,
                constraints:
                    const BoxConstraints.tightFor(width: 28, height: 28),
                icon: Icon(Icons.info_outline_rounded,
                    size: 18, color: theme.earthLight)),
            const Spacer(),
            IconButton(
                tooltip: '重置',
                onPressed: _resetFilters,
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                    foregroundColor: theme.earthLight,
                    minimumSize: const Size(30, 30),
                    maximumSize: const Size(30, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                icon: const Icon(Icons.restart_alt_rounded, size: 18))
          ]),
          const SizedBox(height: 8),
          TextField(
              controller: _searchController,
              style: AiDashboardTypography.body,
              decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  hintText: '搜索模型或厂商（如 GPT、Claude、DeepSeek...）',
                  hintStyle: AiDashboardTypography.body
                      .copyWith(color: theme.earthLight),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(theme.radiusSm),
                      borderSide: BorderSide(
                          color: theme.earthMedium.withValues(alpha: 0.18))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(theme.radiusSm),
                      borderSide: BorderSide(color: theme.primary)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(theme.radiusSm)),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 20, color: theme.earthLight)),
              onChanged: (value) => setState(() {
                    _search = value;
                    _selected = null;
                    _legendPage = 0;
                  })),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth < 260 ||
                    MediaQuery.textScalerOf(context).scale(14) > 18
                ? 1
                : 2;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(
                  width: width,
                  child: AiFilterControl(
                      key: const ValueKey('minimum-score'),
                      label: '能力指标',
                      value: '≥ ${_minimumScore.toStringAsFixed(1)}',
                      active: _minimumScore != _defaultMinimumScore,
                      singleLine: true,
                      expanded: _openFilter.value == 'score',
                      onTap: () => _showFilterPanel('score', _chooseScore))),
              SizedBox(
                  width: width,
                  child: AiFilterSelect<double>(
                      key: const ValueKey('maximum-cost'),
                      label: '价格范围',
                      value: _maximumCost,
                      active: _maximumCost != 0,
                      singleLine: true,
                      options: [
                        const AiFilterOption(0.0, '全部价格'),
                        for (final value in [0.1, 1.0, 10.0])
                          AiFilterOption(
                              value, '\$${value.toStringAsFixed(2)} 以内',
                              description: _metric.unit),
                      ],
                      onChanged: (value) => setState(() {
                            _maximumCost = value;
                            _selected = null;
                            _legendPage = 0;
                          }))),
              SizedBox(
                  width: width,
                  child: AiFilterControl(
                      key: const ValueKey('creator-filter'),
                      label: '模型厂商',
                      value: _selectedCreators.isEmpty
                          ? '全部厂商'
                          : '已选 ${_selectedCreators.length} 家',
                      active: _selectedCreators.isNotEmpty,
                      singleLine: true,
                      expanded: _openFilter.value == 'creators',
                      onTap: creators.isEmpty
                          ? null
                          : () => _showFilterPanel(
                              'creators', () => _chooseCreators(creators)))),
              SizedBox(
                  width: width,
                  child: AiFilterSelect<AiCostMetric>(
                      key: const ValueKey('cost-metric'),
                      label: '价格口径',
                      value: _metric,
                      active: _metric != AiCostMetric.task,
                      singleLine: true,
                      options: [
                        for (final metric in AiCostMetric.values)
                          AiFilterOption(metric, metric.label,
                              description: metric.unit)
                      ],
                      onChanged: (value) => setState(() {
                            _metric = value;
                            _maximumCost = 0;
                            _selected = null;
                          }))),
            ]);
          }),
        ]));
  }

  Future<void> _chooseScore() async {
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        constraints: const BoxConstraints(maxWidth: double.infinity),
        builder: (ctx) => SafeArea(
            child: StatefulBuilder(
                builder: (ctx, update) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                        width: double.infinity,
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('智能指数 ≥ ${_minimumScore.toStringAsFixed(1)}',
                                  style: AiDashboardTypography.title),
                              Slider(
                                  value: _minimumScore,
                                  min: 0,
                                  max: _sliderMax,
                                  label: _minimumScore.toStringAsFixed(1),
                                  onChanged: (value) {
                                    setState(() {
                                      _minimumScore =
                                          ((value * 10).round() / 10)
                                              .clamp(0, _sliderMax)
                                              .toDouble();
                                      _selected = null;
                                      _legendPage = 0;
                                      _selectedCreators.retainAll(
                                          _scoreModels.map((m) => m.creator));
                                    });
                                    update(() {});
                                  }),
                              Text(
                                  '目前最高 ${_highestScore.toStringAsFixed(1)} · 调整后立即筛选',
                                  style: AiDashboardTypography.caption),
                              Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('完成'))),
                            ]))))));
  }

  Widget _buildLegend(List<AiModel> models, Map<String, Color> colors) {
    final theme = Theme.of(context).appTheme;
    final creators = models.map((model) => model.creator).toSet().toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
      decoration: BoxDecoration(
          color: theme.cream.withValues(alpha: 0.45),
          border: Border.all(color: theme.earthMedium.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(8)),
      child: LayoutBuilder(builder: (context, constraints) {
        // 按可用宽度和字号确定列数，每页固定为两行，避免长名称挤出第三行。
        final minimumWidth = MediaQuery.textScalerOf(context).scale(56);
        final columns = ((constraints.maxWidth + 4) / (minimumWidth + 4))
            .floor()
            .clamp(1, 8);
        final perPage = columns * 2;
        final pages = ((creators.length + perPage - 1) ~/ perPage)
            .clamp(1, creators.length + 1);
        final page = _legendPage.clamp(0, pages - 1);
        final shown = creators.skip(page * perPage).take(perPage).toList();
        final itemWidth = (constraints.maxWidth - (columns - 1) * 4) / columns;
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Expanded(
                    child: Tooltip(
                        message: '点击厂商可在图表中隐藏或显示其模型',
                        child: Text('厂商图例',
                            style: AiDashboardTypography.caption))),
                if (pages > 1) ...[
                  IconButton(
                      tooltip: '上一页厂商',
                      visualDensity: VisualDensity.compact,
                      onPressed: page > 0
                          ? () => setState(() => _legendPage = page - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left_rounded, size: 18)),
                  Text('${page + 1}/$pages',
                      style: AiDashboardTypography.caption),
                  IconButton(
                      tooltip: '下一页厂商',
                      visualDensity: VisualDensity.compact,
                      onPressed: page < pages - 1
                          ? () => setState(() => _legendPage = page + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded, size: 18)),
                ],
              ]),
              for (var row = 0; row < 2; row++)
                Row(key: ValueKey('legend-row-$row'), children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (column > 0) const SizedBox(width: 4),
                    Expanded(
                        child: SizedBox(
                            height: 32,
                            child: row * columns + column < shown.length
                                ? _buildLegendItem(
                                    shown[row * columns + column],
                                    colors,
                                    itemWidth)
                                : null)),
                  ],
                ]),
            ]);
      }),
    );
  }

  Widget _buildLegendItem(
      String creator, Map<String, Color> colors, double width) {
    final theme = Theme.of(context).appTheme;
    return FilterChip(
      key: ValueKey('legend-$creator'),
      avatar: Icon(Icons.circle, size: 8, color: colors[creator]),
      avatarBoxConstraints:
          const BoxConstraints.tightFor(width: 10, height: 10),
      showCheckmark: false,
      selected: !_hiddenCreators.contains(creator),
      backgroundColor: Colors.transparent,
      selectedColor: Colors.transparent,
      side: BorderSide.none,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.only(left: 3),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      label: Tooltip(
          message: creator,
          child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: (width - 18).clamp(0, width)),
              child: Text(creator,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AiDashboardTypography.caption.copyWith(
                      fontSize: 10,
                      color: _hiddenCreators.contains(creator)
                          ? theme.earthMedium
                          : theme.earth,
                      decoration: _hiddenCreators.contains(creator)
                          ? TextDecoration.lineThrough
                          : null)))),
      onSelected: (selected) => setState(() {
        if (selected) {
          _hiddenCreators.remove(creator);
        } else {
          _hiddenCreators.add(creator);
        }
        _selected = null;
      }),
    );
  }

  Widget _buildModelRow(AiModel model, Map<String, Color> colors) {
    final theme = Theme.of(context).appTheme;
    final cost = model.cost(_metric);
    return InkWell(
        key: ValueKey('model-row-${model.slug}'),
        onTap: () => _showDetails(model),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(children: [
              Icon(Icons.circle, size: 11, color: colors[model.creator]),
              const SizedBox(width: 10),
              Expanded(
                  flex: 5,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(model.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AiDashboardTypography.strong
                                .copyWith(color: theme.earth)),
                        const SizedBox(height: 6),
                        Text(model.creator,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AiDashboardTypography.caption
                                .copyWith(color: theme.earthLight)),
                      ])),
              const SizedBox(width: 10),
              SizedBox(
                  width: MediaQuery.textScalerOf(context).scale(86),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('智能指数',
                            style: AiDashboardTypography.caption
                                .copyWith(color: theme.earthLight)),
                        Text(
                            '${model.intelligence.toStringAsFixed(1)}${model.estimated ? "（估计）" : ""}',
                            style: AiDashboardTypography.strong),
                        Text(_metric.label,
                            style: AiDashboardTypography.caption
                                .copyWith(color: theme.earthLight)),
                        Text(
                            cost == null
                                ? '未公布'
                                : '\$${cost.toStringAsFixed(4)}',
                            style: AiDashboardTypography.caption
                                .copyWith(color: theme.earthLight)),
                      ])),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: theme.earthLight),
            ])));
  }

  void _showDataInfo() {
    final theme = Theme.of(context).appTheme;
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        constraints: const BoxConstraints(maxWidth: double.infinity),
        builder: (ctx) => SafeArea(
            child: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LayoutBuilder(builder: (context, constraints) {
                            final compact = constraints.maxWidth < 380;
                            return Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  const Text('关于榜单数据',
                                      style: AiDashboardTypography.title),
                                  OutlinedButton.icon(
                                      onPressed: _openSource,
                                      icon: const Icon(
                                          Icons.open_in_new_rounded,
                                          size: 16),
                                      label: Text(compact
                                          ? '原始榜单'
                                          : 'Artificial Analysis 原始榜单'),
                                      style: OutlinedButton.styleFrom(
                                          foregroundColor: theme.earthLight,
                                          backgroundColor: theme.earthLight
                                              .withValues(alpha: 0.08),
                                          side: BorderSide(
                                              color: theme.earthLight
                                                  .withValues(alpha: 0.25)),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          textStyle: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500))),
                                ]);
                          }),
                          const SizedBox(height: 12),
                          const Text(
                              '数据来源为 Artificial Analysis 公开榜单，时间表示本机最近成功获取的时间。智能指数越高，综合能力越强。每任务成本为完成智能指数评测任务的加权平均成本。',
                              style: AiDashboardTypography.body),
                          const SizedBox(height: 8),
                          const Text(
                              'Token 单价与每任务成本口径不同，不能直接互换。未公布的数据保持缺失，不推算能力类型。',
                              style: AiDashboardTypography.body),
                        ])))));
  }

  Future<void> _chooseCreators(List<String> creators) async {
    final theme = Theme.of(context).appTheme;
    final pending = Set<String>.of(_selectedCreators);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, updateSheet) => SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: MediaQuery.sizeOf(ctx).height * 0.75,
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              const Expanded(
                                  child: Text('选择厂商（可多选）',
                                      style: AiDashboardTypography.title)),
                              TextButton(
                                  onPressed: () => updateSheet(pending.clear),
                                  child: const Text('清空选择')),
                            ]),
                            Text(
                                '只列出智能指数 ≥ ${_minimumScore.toStringAsFixed(1)} 的厂商；不单独选择时展示全部。',
                                style: AiDashboardTypography.caption),
                            Expanded(
                                child: ListView.builder(
                                    itemCount: creators.length,
                                    itemBuilder: (ctx, index) {
                                      final creator = creators[index];
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: CheckboxListTile(
                                            key: ValueKey(
                                                'creator-option-$creator'),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 12),
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius
                                                    .circular(theme.radiusSm)),
                                            tileColor: theme.cream,
                                            selectedTileColor: theme.primary
                                                .withValues(alpha: 0.06),
                                            selected: pending.contains(creator),
                                            activeColor: theme.primary,
                                            checkboxShape:
                                                RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4)),
                                            title: Text(creator,
                                                style: AiDashboardTypography
                                                    .body
                                                    .copyWith(fontSize: 14)),
                                            value: pending.contains(creator),
                                            onChanged: (value) =>
                                                updateSheet(() {
                                                  if (value == true) {
                                                    pending.add(creator);
                                                  } else {
                                                    pending.remove(creator);
                                                  }
                                                })),
                                      );
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
                      title: Text('能力与成本关系图',
                          style: AppTypography.headerTitle
                              .copyWith(color: Theme.of(ctx).appTheme.earth)),
                      centerTitle: false,
                      titleSpacing: 0,
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
                                    minimumScore: _minimumScore,
                                    colors: creatorColors((_snapshot?.models ?? [])
                                        .map((model) => model.creator)),
                                    detailedLabels: true,
                                    height: 520,
                                    selectedSlug: _selected?.slug,
                                    onSelected: (model) => showModalBottomSheet<void>(
                                        context: ctx,
                                        isScrollControlled: true,
                                        constraints: const BoxConstraints(
                                            maxWidth: double.infinity),
                                        builder: (_) => SafeArea(
                                            child: SingleChildScrollView(
                                                child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(24),
                                                    child: _details(model))))))))),
                  ])),
            ));
  }

  Widget _details(AiModel model) => SizedBox(
      width: double.infinity,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(model.name, style: AiDashboardTypography.title),
            const SizedBox(height: 12),
            Text(
                '${model.creator} · 智能指数 ${model.intelligence.toStringAsFixed(2)}${model.estimated ? "（估计值）" : ""}',
                style: AiDashboardTypography.body),
            for (final metric in AiCostMetric.values)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                      '${metric.label}：${model.cost(metric) == null ? "未公布" : "\$${model.cost(metric)!.toStringAsFixed(4)}"} ${metric.unit}',
                      style: AiDashboardTypography.body)),
          ]));

  void _showDetails(AiModel model) {
    setState(() => _selected = model);
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        constraints: const BoxConstraints(maxWidth: double.infinity),
        builder: (ctx) => SafeArea(
            child: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _details(model)))));
  }
}
