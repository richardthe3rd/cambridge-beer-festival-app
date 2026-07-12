import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import 'facts_strip.dart';

/// The identity hero at the top of the brewery screen.
///
/// Presents only the brewery's own facts — name, location, how many drinks and
/// styles it brings to the festival, when it was founded, and its notes — on a
/// plain surface card marked with the category-colour left edge, matching the
/// drink hero and the list card. The [accentCategory] is chosen by the caller
/// (a brewery can span categories) to colour that edge.
class BreweryHeroPanel extends StatelessWidget {
  final Producer producer;

  /// How many of this brewery's drinks are at the festival.
  final int drinkCount;

  /// How many distinct styles those drinks span. A zero count hides the cell.
  final int styleCount;

  /// The category whose accent colours the left edge — the brewery's dominant
  /// category, computed by the caller.
  final String accentCategory;

  const BreweryHeroPanel({
    required this.producer,
    required this.drinkCount,
    required this.styleCount,
    required this.accentCategory,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = CategoryColorHelper.getAccentColor(accentCategory);
    final hasNotes = producer.notes != null && producer.notes!.isNotEmpty;

    final cells = <FactCell>[
      FactCell(label: 'Drinks', value: _factValue(theme, '$drinkCount')),
      if (styleCount > 0)
        FactCell(label: 'Styles', value: _factValue(theme, '$styleCount')),
      if (producer.yearFounded != null)
        FactCell(
          label: 'Founded',
          value: _factValue(theme, '${producer.yearFounded}'),
        ),
    ];

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
            SelectableText(
              producer.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (producer.location.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                producer.location,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            FactsStrip(cells: cells),
            if (hasNotes) ...[const SizedBox(height: 14), _buildAbout(theme)],
          ],
        ),
      ),
    );
  }

  Widget _factValue(ThemeData theme, String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _buildAbout(ThemeData theme) {
    final divider = theme.colorScheme.outlineVariant.withValues(alpha: 0.6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, thickness: 1, color: divider),
        const SizedBox(height: 12),
        Text(
          'About this brewery',
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        SelectableText(producer.notes!, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
