import 'package:flutter/material.dart';
import '../utils/utils.dart';
import 'facts_strip.dart';

/// The identity hero at the top of the style screen.
///
/// Presents only the style's own facts — its name, how many drinks share it,
/// their average ABV, the category it belongs to, and its description — on a
/// plain surface card marked with the category-colour left edge, matching the
/// drink and brewery heroes. A style is scoped to one [category], so that
/// category both colours the edge and appears as a fact.
class StyleHeroPanel extends StatelessWidget {
  final String styleName;

  /// The category this style belongs to — colours the left edge and shows as a
  /// fact.
  final String category;

  /// How many drinks at the festival share this style.
  final int drinkCount;

  /// The average ABV across those drinks.
  final double averageAbv;

  /// The style's description, or null when not loaded yet or none exists — in
  /// which case the about section simply does not render.
  final String? description;

  const StyleHeroPanel({
    required this.styleName,
    required this.category,
    required this.drinkCount,
    required this.averageAbv,
    this.description,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = CategoryColorHelper.getAccentColor(category);
    final hasDescription = description != null && description!.isNotEmpty;

    final cells = <FactCell>[
      FactCell(label: 'Drinks', value: factValueText(theme, '$drinkCount')),
      FactCell(
        label: 'Avg ABV',
        value: factValueText(theme, '${averageAbv.toStringAsFixed(1)}%'),
      ),
      FactCell(
        label: 'Category',
        value: factValueText(
          theme,
          StringFormattingHelper.capitalizeFirst(category),
        ),
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
              styleName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            FactsStrip(cells: cells),
            if (hasDescription) ...[
              const SizedBox(height: 14),
              HeroAboutSection(heading: 'About this style', body: description!),
            ],
          ],
        ),
      ),
    );
  }
}
