import 'package:flutter/material.dart';

/// A pinned [SliverAppBar] for detail screens whose title cross-fades from a
/// quiet "context" line (the festival name) to the screen's own identity (drink
/// name, brewery, style) once the identity hero has scrolled out of view.
///
/// This keeps the festival name in the bar in a consistent role on every
/// screen — it never shrinks to a muted caption between the list and a detail
/// screen — while ensuring the user never loses track of *which* drink/brewery/
/// style they are looking at after the hero card scrolls off the top.
///
/// The hero card stays a normal body sliver; it is deliberately NOT folded into
/// this app bar's `flexibleSpace`. When the collapsed title is showing, the
/// hero is off-screen, so the two never present the same name at rest.
///
/// Collapse is driven by [scrollController] offset crossing [collapseThreshold],
/// with a small hysteresis band so the title cannot flicker at the boundary.
/// Only the title subtree rebuilds on scroll (via a [ValueNotifier]), never the
/// list below.
class CollapsingDetailAppBar extends StatefulWidget {
  const CollapsingDetailAppBar({
    required this.scrollController,
    required this.contextTitle,
    required this.collapsedTitle,
    this.collapsedSubtitle,
    this.leading,
    this.actions,
    this.collapseThreshold = 180,
    super.key,
  });

  /// The controller attached to the enclosing scroll view. Read-only here.
  final ScrollController scrollController;

  /// Quiet line shown at the top of the screen (the festival name).
  final String contextTitle;

  /// The screen's own identity, shown once scrolled past the hero.
  final String collapsedTitle;

  /// Optional secondary line under [collapsedTitle] (e.g. the brewery name).
  final String? collapsedSubtitle;

  /// Leading widget (typically the home/back button). When null, the app bar
  /// inserts the platform back button automatically, as [AppBar] does.
  final Widget? leading;

  /// Trailing actions (e.g. an overflow menu).
  final List<Widget>? actions;

  /// Scroll offset (logical px) past which the collapsed title is shown.
  final double collapseThreshold;

  @override
  State<CollapsingDetailAppBar> createState() => _CollapsingDetailAppBarState();
}

class _CollapsingDetailAppBarState extends State<CollapsingDetailAppBar> {
  /// Half-width of the hysteresis band around [collapseThreshold], so the
  /// title collapses slightly later than it expands and can't rapidly toggle
  /// while the user hovers the exact threshold.
  static const double _hysteresis = 24;

  late final ValueNotifier<bool> _collapsed = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _collapsed.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = widget.scrollController.hasClients
        ? widget.scrollController.offset
        : 0.0;
    // Widen the "stay collapsed" region so a small jitter near the threshold
    // doesn't cross back and forth.
    final next = _collapsed.value
        ? offset > widget.collapseThreshold - _hysteresis
        : offset > widget.collapseThreshold + _hysteresis;
    if (next != _collapsed.value) {
      _collapsed.value = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      // Left-aligned on every platform so the title doesn't jump to centre
      // between the list bar and here.
      centerTitle: false,
      leading: widget.leading,
      actions: widget.actions,
      title: ValueListenableBuilder<bool>(
        valueListenable: _collapsed,
        builder: (context, collapsed, _) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: collapsed
                ? _CollapsedTitle(
                    key: const ValueKey('appbar-collapsed-title'),
                    title: widget.collapsedTitle,
                    subtitle: widget.collapsedSubtitle,
                  )
                : _ContextTitle(
                    key: const ValueKey('appbar-context-title'),
                    text: widget.contextTitle,
                  ),
          );
        },
      ),
    );
  }
}

/// The quiet top-of-screen line: the festival name at full opacity (not the
/// muted caption the detail bars used to show).
class _ContextTitle extends StatelessWidget {
  const _ContextTitle({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}

/// The collapsed identity: the screen's own name in bold, with an optional
/// secondary line (e.g. brewery) underneath.
class _CollapsedTitle extends StatelessWidget {
  const _CollapsedTitle({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;

    return Semantics(
      header: true,
      label: hasSubtitle ? '$title, $subtitle' : title,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          if (hasSubtitle)
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
        ],
      ),
    );
  }
}
