import 'package:flutter/material.dart';
import '../../../core/theme/theme_extension.dart';
import 'ai_dashboard_typography.dart';

/// 筛选与排序共用的选择项。
class AiFilterOption<T> {
  final T value;
  final String label;
  final String? description;
  const AiFilterOption(this.value, this.label, {this.description});
}

/// 菜单和弹出面板共用同一种触发控件。
class AiFilterControl extends StatefulWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool active;
  final bool expanded;
  final bool compact;
  final bool singleLine;
  const AiFilterControl(
      {super.key,
      required this.label,
      required this.value,
      required this.onTap,
      this.active = false,
      this.expanded = false,
      this.compact = false,
      this.singleLine = false});

  @override
  State<AiFilterControl> createState() => _AiFilterControlState();
}

class _AiFilterControlState extends State<AiFilterControl> {
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).appTheme;
    final enabled = widget.onTap != null;
    final emphasized = widget.expanded || _focused;
    final accent = widget.active || emphasized;
    final radius = BorderRadius.circular(theme.radiusSm);
    final foreground = !enabled
        ? theme.earthMedium
        : accent
            ? theme.primary
            : theme.earth;
    return Semantics(
      button: true,
      enabled: enabled,
      expanded: widget.expanded,
      label: '${widget.label}，${widget.value}',
      onTap: widget.onTap,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
              color: accent
                  ? Color.alphaBlend(theme.primary.withValues(alpha: 0.045),
                      theme.cardBackground)
                  : theme.cream.withValues(alpha: 0.65),
              borderRadius: radius,
              border: Border.all(
                  color: emphasized
                      ? theme.primary
                      : widget.active
                          ? theme.primary.withValues(alpha: 0.3)
                          : theme.earthMedium.withValues(alpha: 0.15))),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
                borderRadius: radius,
                onTap: widget.onTap,
                onHighlightChanged: (pressed) =>
                    setState(() => _pressed = pressed),
                onFocusChange: (focused) => setState(() => _focused = focused),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minHeight:
                          widget.compact ? 30 : (widget.singleLine ? 34 : 58)),
                  child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal:
                              widget.compact || widget.singleLine ? 8 : 12,
                          vertical:
                              widget.compact ? 4 : (widget.singleLine ? 6 : 9)),
                      child: Row(children: [
                        if (widget.singleLine) ...[
                          Text(widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AiDashboardTypography.caption.copyWith(
                                  fontSize: 10, color: theme.earthLight)),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                            child: widget.compact || widget.singleLine
                                ? Text(widget.value,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: (widget.singleLine
                                            ? AiDashboardTypography.strong
                                            : AiDashboardTypography.caption)
                                        .copyWith(
                                            fontSize:
                                                widget.singleLine ? 10 : null,
                                            color: foreground))
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        Text(widget.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AiDashboardTypography.caption
                                                .copyWith(
                                                    color: theme.earthLight)),
                                        const SizedBox(height: 3),
                                        Text(widget.value,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AiDashboardTypography.strong
                                                .copyWith(color: foreground)),
                                      ])),
                        SizedBox(width: widget.singleLine ? 4 : 8),
                        AnimatedRotation(
                            turns: widget.expanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 160),
                            child: Icon(Icons.keyboard_arrow_down_rounded,
                                size: widget.singleLine ? 14 : 18,
                                color:
                                    accent ? theme.primary : theme.earthLight)),
                      ])),
                )),
          ),
        ),
      ),
    );
  }
}

/// 带当前选项高亮的锚定菜单，取消原生下拉按钮的独立边线与箭头。
class AiFilterSelect<T> extends StatefulWidget {
  final String label;
  final T value;
  final List<AiFilterOption<T>> options;
  final ValueChanged<T> onChanged;
  final bool active;
  final bool compact;
  final bool singleLine;
  const AiFilterSelect(
      {super.key,
      required this.label,
      required this.value,
      required this.options,
      required this.onChanged,
      this.active = false,
      this.compact = false,
      this.singleLine = false});

  @override
  State<AiFilterSelect<T>> createState() => _AiFilterSelectState<T>();
}

class _AiFilterSelectState<T> extends State<AiFilterSelect<T>> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).appTheme;
    final current =
        widget.options.firstWhere((option) => option.value == widget.value);
    return LayoutBuilder(builder: (context, constraints) {
      final menuWidth = constraints.maxWidth.clamp(144.0, 184.0);
      return MenuAnchor(
        consumeOutsideTap: true,
        crossAxisUnconstrained: false,
        alignmentOffset: Offset(
            Directionality.of(context) == TextDirection.ltr ? -menuWidth : 0,
            0),
        onOpen: () => setState(() => _open = true),
        onClose: () => setState(() => _open = false),
        style: MenuStyle(
          alignment: Alignment.bottomRight,
          backgroundColor: WidgetStatePropertyAll(theme.cardBackground),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(4)),
          minimumSize: WidgetStatePropertyAll(Size(menuWidth, 0)),
          maximumSize: WidgetStatePropertyAll(Size(menuWidth, double.infinity)),
          side: WidgetStatePropertyAll(
              BorderSide(color: theme.earthMedium.withValues(alpha: 0.2))),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(theme.radiusLg))),
        ),
        menuChildren: [
          for (final option in widget.options)
            MenuItemButton(
              key: ValueKey('option-${widget.key}-${option.value}'),
              onPressed: () => widget.onChanged(option.value),
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
                padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                backgroundColor: WidgetStateProperty.resolveWith((states) =>
                    option.value == widget.value ||
                            states.contains(WidgetState.focused)
                        ? theme.primary.withValues(alpha: 0.07)
                        : Colors.transparent),
                foregroundColor: WidgetStatePropertyAll(
                    option.value == widget.value ? theme.primary : theme.earth),
                shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(theme.radiusSm))),
              ),
              trailingIcon: option.value == widget.value
                  ? Icon(Icons.check_rounded, size: 18, color: theme.primary)
                  : const SizedBox(width: 18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(option.label, style: AiDashboardTypography.strong),
                    if (option.description != null) ...[
                      const SizedBox(height: 3),
                      Text(option.description!,
                          style: AiDashboardTypography.caption
                              .copyWith(color: theme.earthLight)),
                    ],
                  ]),
            ),
        ],
        builder: (context, controller, child) => AiFilterControl(
            label: widget.label,
            value: current.label,
            active: widget.active,
            expanded: _open,
            compact: widget.compact,
            singleLine: widget.singleLine,
            onTap: () =>
                controller.isOpen ? controller.close() : controller.open()),
      );
    });
  }
}
