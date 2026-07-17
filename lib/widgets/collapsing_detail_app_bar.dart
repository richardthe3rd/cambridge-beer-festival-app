import 'package:flutter/material.dart';

/// A pinned [SliverAppBar] for detail screens whose title cross-fades from a
/// quiet "context" line (the festival name) to the screen's own identity (drink
/// name, brewery, style) as the identity hero scrolls up under the bar.
///
/// This keeps the festival name in the bar in a consistent role on every
/// screen — it never shrinks to a muted caption between the list and a detail
/// screen — while ensuring the user never loses track of *which* drink/brewery/
/// style they are looking at after the hero card scrolls off the top.
///
/// The hero card stays a normal body sliver; it is deliberately NOT folded into
/// this app bar's `flexibleSpace`. Because the hero is the first sliver directly
/// under the bar, the scroll offset itself measures how far the hero (and its
/// name at the top) has travelled under the bar — so the reveal is tied to the
/// hero's real position, not an arbitrary threshold. The identity fades in as
/// the name leaves, with no dead zone, and it works on short screens that can
/// only scroll a little.
///
/// The fade is a continuous 0→1 fraction driven by scroll position, so it tracks
/// the finger and never plays as a separate, timed animation. Only the title
/// subtree rebuilds on scroll (via a [ValueNotifier]), never the list below.
class CollapsingDetailAppBar extends StatefulWidget {
  const CollapsingDetailAppBar({
    required this.scrollController,
    required this.contextTitle,
    required this.collapsedTitle,
    this.collapsedSubtitle,
    this.leading,
    this.actions,
    this.revealSpan = 56,
    super.key,
  });

  /// The controller attached to the enclosing scroll view. Read-only here.
  final ScrollController scrollController;

  /// Quiet line shown at the top of the screen (the festival name).
  final String contextTitle;

  /// The screen's own identity, shown once the hero has scrolled under the bar.
  final String collapsedTitle;

  /// Optional secondary context appended inline after [collapsedTitle] (e.g.
  /// the brewery), on the same single line so the toolbar height is unchanged.
  final String? collapsedSubtitle;

  /// Leading widget (typically the home/back button). When null, the app bar
  /// inserts the platform back button automatically, as [AppBar] does.
  final Widget? leading;

  /// Trailing actions shown at the end of the bar (e.g. the "back to drinks
  /// list" affordance). Passed straight through to the underlying [SliverAppBar].
  final List<Widget>? actions;

  /// Scroll distance (logical px) over which the title fully cross-fades —
  /// roughly the height of the hero's name block, so the identity is fully in
  /// by the time the name has scrolled under the bar.
  final double revealSpan;

  @override
  State<CollapsingDetailAppBar> createState() => _CollapsingDetailAppBarState();
}

class _CollapsingDetailAppBarState extends State<CollapsingDetailAppBar> {
  /// The fade begins once the hero top is this far above the bar bottom, so the
  /// identity has a slight lead over the departing hero name (no dead zone).
  static const double _revealStart = 8;

  /// 0 = festival context fully shown, 1 = collapsed identity fully shown.
  late final ValueNotifier<double> _fraction = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
    // The controller has no clients until the first layout, so sync once after
    // the first frame — a restored or non-zero initial offset then shows the
    // correct title immediately, without waiting for the user to scroll.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onScroll();
    });
  }

  @override
  void didUpdateWidget(covariant CollapsingDetailAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-point the listener if the enclosing screen ever swaps the controller
    // instance, so the bar keeps tracking the live scroll position.
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
      _onScroll();
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _fraction.dispose();
    super.dispose();
  }

  void _onScroll() {
    final next = _computeFraction();
    // Ignore sub-pixel churn so scrolling doesn't rebuild the title every frame
    // when the fraction is pinned at 0 or 1.
    if ((next - _fraction.value).abs() > 0.001) {
      _fraction.value = next;
    }
  }

  /// How far the collapsed identity has revealed, from the current scroll offset
  /// (which, with the hero as the first sliver, is how far the hero has gone
  /// under the bar).
  double _computeFraction() {
    final offset = widget.scrollController.hasClients
        ? widget.scrollController.offset
        : 0.0;
    return ((offset - _revealStart) / (widget.revealSpan - _revealStart)).clamp(
      0.0,
      1.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverAppBar(
      pinned: true,
      // Left-aligned on every platform so the title doesn't jump to centre
      // between the list bar and here.
      centerTitle: false,
      leading: widget.leading,
      actions: widget.actions,
      title: ValueListenableBuilder<double>(
        valueListenable: _fraction,
        builder: (context, fraction, _) {
          // A single-line title on both sides keeps the toolbar height constant,
          // and each layer is only built at the end of the range where it is
          // visible — so at rest only the context line exists (no stray copy of
          // the identity in the tree) while both are present, cross-fading, mid
          // scroll.
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              if (fraction < 1.0)
                ExcludeSemantics(
                  excluding: fraction > 0.5,
                  child: Opacity(
                    opacity: (1 - fraction).clamp(0.0, 1.0),
                    child: _TitleLine(
                      text: widget.contextTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              if (fraction > 0.0)
                ExcludeSemantics(
                  excluding: fraction <= 0.5,
                  child: Opacity(
                    opacity: fraction.clamp(0.0, 1.0),
                    // A few px of upward drift as it fades in reads as the
                    // identity "settling" into the bar.
                    child: Transform.translate(
                      offset: Offset(0, (1 - fraction) * 6),
                      child: _CollapsedIdentity(
                        key: const ValueKey('appbar-collapsed-title'),
                        title: widget.collapsedTitle,
                        subtitle: widget.collapsedSubtitle,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A single ellipsised context line (the festival name), so the toolbar height
/// never changes between it and the collapsed identity.
class _TitleLine extends StatelessWidget {
  const _TitleLine({required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}

/// The collapsed identity: the screen's own name, with an optional secondary
/// value (e.g. the brewery) appended inline after a middot. Kept to a single
/// line — the brewery ellipsises away first on narrow screens — so the toolbar
/// height stays constant and it never overflows at large text scales.
class _CollapsedIdentity extends StatelessWidget {
  const _CollapsedIdentity({required this.title, this.subtitle, super.key});

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
      child: Text.rich(
        TextSpan(
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          children: [
            TextSpan(text: title),
            if (hasSubtitle)
              TextSpan(
                text: '  ·  $subtitle',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w400,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
