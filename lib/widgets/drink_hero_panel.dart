import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/utils.dart';

/// The identity hero at the top of the drink detail screen.
///
/// Presents only the drink's own facts — name, brewery, ABV, style, serve,
/// availability, vegan — on a plain surface card marked with the category
/// colour left edge, matching the drink list card and the similar-drinks
/// carousel. Nothing about the *user's* relationship to the drink (rating,
/// notes, want-to-try) lives here; that belongs to the "Your take" card.
///
/// Two facts are navigable: the brewery name links to the brewery screen and
/// the style cell links to the style screen. [onShareTap] shares the drink.
class DrinkHeroPanel extends StatelessWidget {
  final Drink drink;

  /// Share this drink.
  final VoidCallback onShareTap;

  /// Navigate to the brewery screen.
  final VoidCallback onBreweryTap;

  /// Navigate to the style screen. Null when the drink has no style, in which
  /// case the style cell shows the category and is not tappable.
  final VoidCallback? onStyleTap;

  const DrinkHeroPanel({
    required this.drink,
    required this.onShareTap,
    required this.onBreweryTap,
    this.onStyleTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = CategoryColorHelper.getAccentColor(drink.category);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopRow(context, theme),
            const SizedBox(height: 14),
            _buildFactsStrip(context, theme),
            if (drink.isVegan == true) ...[
              const SizedBox(height: 12),
              _buildVegan(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopRow(BuildContext context, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                drink.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              _buildBreweryLink(context, theme),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildShareButton(context, theme),
            const SizedBox(height: 8),
            _buildAbv(theme),
          ],
        ),
      ],
    );
  }

  Widget _buildBreweryLink(BuildContext context, ThemeData theme) {
    final location = drink.breweryLocation;
    final semanticLabel = location.isNotEmpty
        ? 'View all drinks from ${drink.breweryName}, $location'
        : 'View all drinks from ${drink.breweryName}';

    return Semantics(
      label: semanticLabel,
      hint: 'Double tap to see brewery details',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onBreweryTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  drink.breweryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    decoration: TextDecoration.underline,
                    decorationColor: theme.colorScheme.primary,
                  ),
                ),
              ),
              if (location.isNotEmpty)
                Flexible(
                  child: Text(
                    ' · $location',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareButton(BuildContext context, ThemeData theme) {
    return Semantics(
      label: 'Share ${drink.name}',
      hint: 'Double tap to share this drink',
      button: true,
      child: IconButton(
        icon: const Icon(Icons.share, size: 18),
        onPressed: onShareTap,
        tooltip: 'Share',
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          side: BorderSide(color: theme.colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildAbv(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          drink.abv.toStringAsFixed(1),
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
        Text(
          '% ABV',
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.2,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildFactsStrip(BuildContext context, ThemeData theme) {
    final divider = theme.colorScheme.outlineVariant.withValues(alpha: 0.6);
    final styleText =
        drink.style ?? StringFormattingHelper.capitalizeFirst(drink.category);

    final cells = <Widget>[
      _FactCell(
        first: true,
        label: 'Style',
        divider: divider,
        onTap: drink.style != null ? onStyleTap : null,
        semanticLabel: drink.style != null
            ? 'View all $styleText drinks'
            : null,
        value: _factValue(
          theme,
          styleText,
          isLink: drink.style != null,
          trailing: drink.style != null
              ? Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: theme.colorScheme.onSurface,
                )
              : null,
        ),
      ),
      _FactCell(
        label: 'Serve',
        divider: divider,
        value: _factValue(
          theme,
          StringFormattingHelper.capitalizeFirst(drink.dispense),
        ),
      ),
    ];

    final availability = _availabilityCell(theme, divider);
    if (availability != null) cells.add(availability);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: divider),
          bottom: BorderSide(color: divider),
        ),
      ),
      child: IntrinsicHeight(child: Row(children: cells)),
    );
  }

  /// The availability cell mirrors the previous hero card's logic: it only
  /// appears for a sold-out drink or one with a known bar. Sold-out reads in
  /// the error colour; otherwise the bar location is the value.
  Widget? _availabilityCell(ThemeData theme, Color divider) {
    final isSoldOut = drink.availabilityStatus == AvailabilityStatus.out;
    if (!isSoldOut && drink.bar == null) return null;

    if (isSoldOut) {
      return _FactCell(
        label: 'Availability',
        divider: divider,
        value: _factValue(theme, 'Sold Out', color: theme.colorScheme.error),
      );
    }

    final available = CategoryColorHelper.getTastedColor(theme.brightness);
    return _FactCell(
      label: drink.bar!,
      divider: divider,
      value: _factValue(
        theme,
        'Available',
        color: available,
        leading: Icon(Icons.check_circle, size: 13, color: available),
      ),
    );
  }

  Widget _factValue(
    ThemeData theme,
    String text, {
    bool isLink = false,
    Color? color,
    Widget? leading,
    Widget? trailing,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[leading, const SizedBox(width: 4)],
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color ?? theme.colorScheme.onSurface,
              decoration: isLink ? TextDecoration.underline : null,
              decorationColor: theme.colorScheme.primary,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget _buildVegan(ThemeData theme) {
    final green = CategoryColorHelper.getTastedColor(theme.brightness);
    return Semantics(
      label: 'This drink is vegan',
      container: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.eco, size: 16, color: green),
          const SizedBox(width: 6),
          Text(
            'Vegan',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single cell of the hero facts strip: a centred value over an uppercase
/// label, with a left divider unless it is the [first] cell. When [onTap] is
/// provided the whole cell is a navigation button carrying [semanticLabel].
class _FactCell extends StatelessWidget {
  final Widget value;
  final String label;
  final Color divider;
  final bool first;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const _FactCell({
    required this.value,
    required this.label,
    required this.divider,
    this.first = false,
    this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          value,
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 0.6,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      content = InkWell(onTap: onTap, child: content);
      if (semanticLabel != null) {
        content = Semantics(
          label: semanticLabel,
          button: true,
          excludeSemantics: true,
          child: content,
        );
      }
    }

    return Expanded(
      child: DecoratedBox(
        decoration: first
            ? const BoxDecoration()
            : BoxDecoration(
                border: Border(left: BorderSide(color: divider)),
              ),
        child: content,
      ),
    );
  }
}
