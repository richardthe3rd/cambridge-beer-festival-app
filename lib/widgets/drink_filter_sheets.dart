import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/models/models.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import 'sheet_handle.dart';

/// Shows the category filter (multi-select) as a modal bottom sheet.
void showCategoryFilter(BuildContext context) =>
    _showSheet(context, (_) => const CategoryFilterSheet());

/// Shows the style filter (multi-select) as a modal bottom sheet.
void showStyleFilter(BuildContext context) =>
    _showSheet(context, (_) => const StyleFilterSheet());

/// Shows the sort-options picker as a modal bottom sheet.
void showSortOptions(BuildContext context) =>
    _showSheet(context, (_) => const SortOptionsSheet());

/// Shows the availability/dietary view filters as a modal bottom sheet.
void showVisibilityFilter(BuildContext context) =>
    _showSheet(context, (_) => const VisibilityFilterSheet());

void _showSheet(BuildContext context, WidgetBuilder builder) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: builder,
  );
}

/// How long the style sheet's selected-styles summary takes to change size
/// or colour.
const _summaryDuration = Duration(milliseconds: 200);

/// Title row shared by the category, style and visibility sheets: the title
/// and a Clear button.
///
/// A [Wrap] rather than a spaceBetween [Row]: when both fit on one line —
/// every ordinary text size — it lays out identically, title at the start and
/// button at the end. When they cannot share a line (an accessibility text
/// size on a narrow phone) the button drops below the title instead of
/// squeezing it into a five-line column, which is what pushed the sheets'
/// pinned chrome past their height cap (#623). The title is constrained to
/// the sheet's width either way, so it wraps rather than overflowing
/// horizontally (#583).
///
/// The Clear button is always mounted and merely hidden while there is
/// nothing to clear, so the header — and with it the bottom-anchored sheet's
/// top edge — does not move on the empty ↔ non-empty transition (#630).
/// Hidden, it takes no taps and is absent from the semantics tree.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.clearLabel,
    required this.clearHint,
    required this.canClear,
    required this.onClear,
  });

  final String title;

  /// Semantics label and hint for the Clear button.
  final String clearLabel;
  final String clearHint;

  /// Whether there is anything to clear; the button is hidden otherwise.
  final bool canClear;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Full width, not shrink-wrapped: the enclosing Column is start-aligned,
    // and spaceBetween has nothing to distribute in a Wrap sized to its
    // content.
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          Visibility(
            visible: canClear,
            maintainState: true,
            maintainAnimation: true,
            maintainSize: true,
            child: Semantics(
              label: clearLabel,
              hint: clearHint,
              button: true,
              excludeSemantics: true,
              child: TextButton.icon(
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Clear'),
                onPressed: onClear,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Category filter sheet with checkboxes for multi-select. Categories arrive
/// already sorted naturally from [BeerProvider.availableCategories].
class CategoryFilterSheet extends StatelessWidget {
  const CategoryFilterSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BeerProvider>(
      builder: (context, beerProvider, child) {
        final categories = beerProvider.availableCategories;
        final counts = beerProvider.categoryCountsMap;
        final selectedCategories = beerProvider.selectedCategories;

        return Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: 16),
              _SheetHeader(
                title: 'Filter by Category',
                clearLabel: 'Clear all category filters',
                clearHint: 'Double tap to remove all category filters',
                canClear: selectedCategories.isNotEmpty,
                onClear: beerProvider.clearCategories,
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        label:
                            'Show all drinks, ${beerProvider.allDrinks.length} total',
                        value: selectedCategories.isEmpty
                            ? 'Selected'
                            : 'Not selected',
                        selected: selectedCategories.isEmpty,
                        button: true,
                        excludeSemantics: true,
                        child: CheckboxListTile(
                          key: const ValueKey('category-all'),
                          value: selectedCategories.isEmpty,
                          onChanged: (_) => beerProvider.clearCategories(),
                          title: Text('All (${beerProvider.allDrinks.length})'),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        ),
                      ),
                      ...categories.map((category) {
                        final formattedCategory =
                            BeverageTypeHelper.formatBeverageType(category);
                        final count = counts[category] ?? 0;
                        final isSelected = selectedCategories.contains(
                          category,
                        );
                        return Semantics(
                          label:
                              'Filter by $formattedCategory, '
                              '${StringFormattingHelper.drinkCountLabel(count)}',
                          value: isSelected ? 'Selected' : 'Not selected',
                          selected: isSelected,
                          button: true,
                          excludeSemantics: true,
                          child: CheckboxListTile(
                            key: ValueKey('category-$category'),
                            value: isSelected,
                            onChanged: (_) =>
                                beerProvider.toggleCategory(category),
                            title: Text('$formattedCategory ($count)'),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

/// Single-select sort-options sheet.
class SortOptionsSheet extends StatelessWidget {
  const SortOptionsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentSort = context.select<BeerProvider, DrinkSort>(
      (p) => p.currentSort,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 16),
          Text('Sort By', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: RadioGroup<DrinkSort>(
                groupValue: currentSort,
                onChanged: (value) {
                  if (value != null) {
                    context.read<BeerProvider>().setSort(value);
                    Navigator.pop(context);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: DrinkSort.values.map((sort) {
                    final sortLabel = sort.label;
                    return Semantics(
                      label: 'Sort by $sortLabel',
                      selected: currentSort == sort,
                      button: true,
                      excludeSemantics: true,
                      child: ListTile(
                        leading: Radio<DrinkSort>(value: sort),
                        title: Text(sortLabel),
                        // Matches the CheckboxListTile rows in the category,
                        // style, and visibility sheets, which are all dense.
                        dense: true,
                        onTap: () {
                          context.read<BeerProvider>().setSort(sort);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Style filter sheet with checkboxes for multi-select. Styles arrive
/// grouped by category, already sorted, from
/// [BeerProvider.stylesByCategory] — see that getter's doc for the ordering
/// and grouping rules. A category header renders above each group, unless
/// there is exactly one group (the common case once a single category is
/// selected), in which case the list renders flat with no header — a lone
/// header is noise.
class StyleFilterSheet extends StatelessWidget {
  const StyleFilterSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<BeerProvider>(
      builder: (context, beerProvider, child) {
        final stylesByCategory = beerProvider.stylesByCategory;
        final styleCounts = beerProvider.styleCountsMap;
        final selectedStyles = beerProvider.selectedStyles;
        final showHeaders = stylesByCategory.length > 1;
        final hasSelection = selectedStyles.isNotEmpty;
        final summaryColor = hasSelection
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurfaceVariant;

        return Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: 16),
              _SheetHeader(
                title: 'Filter by Style',
                clearLabel: 'Clear all style filters',
                clearHint: 'Double tap to remove all style filters',
                canClear: selectedStyles.isNotEmpty,
                onClear: beerProvider.clearStyles,
              ),
              const SizedBox(height: 8),
              // Selected-styles summary. Always shown — with nothing selected
              // it reads as a muted status line — so the sheet's height, and
              // with it its top edge, does not move on the empty ↔ non-empty
              // transition (#630). AnimatedSize still smooths the growth when
              // a long selection wraps onto a second line.
              AnimatedSize(
                duration: _summaryDuration,
                curve: Curves.easeInOut,
                child: AnimatedContainer(
                  duration: _summaryDuration,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: hasSelection
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasSelection
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        size: 16,
                        color: summaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hasSelection
                              ? selectedStyles.join(', ')
                              : 'Showing all styles',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: summaryColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    // The category headers are the only children narrower than
                    // the sheet; without this they centre instead of sitting
                    // above their group, unlike every other Column here.
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final entry in stylesByCategory.entries) ...[
                        if (showHeaders)
                          Semantics(
                            header: true,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: Text(
                                BeverageTypeHelper.formatBeverageType(
                                  entry.key,
                                ),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ...entry.value.map((style) {
                          final count = styleCounts[style] ?? 0;
                          final isSelected = selectedStyles.contains(style);
                          return Semantics(
                            label:
                                'Filter by $style, '
                                '${StringFormattingHelper.drinkCountLabel(count)}',
                            value: isSelected ? 'Selected' : 'Not selected',
                            selected: isSelected,
                            button: true,
                            excludeSemantics: true,
                            child: CheckboxListTile(
                              value: isSelected,
                              onChanged: (_) => beerProvider.toggleStyle(style),
                              title: Text('$style ($count)'),
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

/// Sheet for toggling visibility filters (availability, tasted, vegan,
/// allergen-free).
class VisibilityFilterSheet extends StatelessWidget {
  const VisibilityFilterSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BeerProvider>(
      builder: (context, beerProvider, child) {
        final active = beerProvider.visibilityFilters;

        return Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: 16),
              _SheetHeader(
                title: 'View Filters',
                clearLabel: 'Clear all view filters',
                clearHint: 'Double tap to remove all view filters',
                canClear:
                    active.isNotEmpty ||
                    beerProvider.excludedAllergens.isNotEmpty,
                onClear: () async {
                  await beerProvider.clearVisibilityFilters();
                  await beerProvider.clearAllergenFilters();
                },
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    // The 'Allergen-free' section header is the only
                    // child narrower than the sheet; without this it
                    // centres instead of sitting above its group — the
                    // same defect #506 shipped in StyleFilterSheet.
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      VisibilityFilterTile(
                        label: 'Available only',
                        subtitle: 'Hide sold out & not yet arrived drinks',
                        icon: Icons.check_circle_outline,
                        isChecked: active.contains(
                          DrinkVisibilityFilter.availableOnly,
                        ),
                        onChanged: (value) => beerProvider.setVisibilityFilter(
                          DrinkVisibilityFilter.availableOnly,
                          active: value ?? false,
                        ),
                      ),
                      VisibilityFilterTile(
                        label: 'Not tasted',
                        subtitle: 'Hide drinks you\'ve already tasted',
                        icon: Icons.remove_circle_outline,
                        isChecked: active.contains(
                          DrinkVisibilityFilter.notTasted,
                        ),
                        onChanged: (value) => beerProvider.setVisibilityFilter(
                          DrinkVisibilityFilter.notTasted,
                          active: value ?? false,
                        ),
                      ),
                      VisibilityFilterTile(
                        label: 'Vegan only',
                        subtitle: 'Show only drinks marked as vegan',
                        icon: Icons.eco_outlined,
                        isChecked: active.contains(
                          DrinkVisibilityFilter.veganOnly,
                        ),
                        onChanged: (value) => beerProvider.setVisibilityFilter(
                          DrinkVisibilityFilter.veganOnly,
                          active: value ?? false,
                        ),
                      ),
                      if (beerProvider.availableAllergens.isNotEmpty) ...[
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Text(
                            'Allergen-free',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        for (final allergen
                            in (beerProvider.availableAllergens.toList()
                              ..sort()))
                          VisibilityFilterTile(
                            label: _formatAllergenName(allergen),
                            subtitle: 'Hide drinks containing $allergen',
                            icon: Icons.no_meals_outlined,
                            isChecked: beerProvider.excludedAllergens.contains(
                              allergen,
                            ),
                            onChanged: (value) =>
                                beerProvider.setAllergenFilter(
                                  allergen,
                                  active: value ?? false,
                                ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  static String _formatAllergenName(String allergen) {
    if (allergen.isEmpty) return allergen;
    return allergen[0].toUpperCase() + allergen.substring(1);
  }
}

/// Checkbox row used inside [VisibilityFilterSheet] for a single toggle.
class VisibilityFilterTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isChecked;
  final ValueChanged<bool?> onChanged;

  const VisibilityFilterTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isChecked,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label. $subtitle',
      value: isChecked ? 'Active' : 'Inactive',
      selected: isChecked,
      button: true,
      excludeSemantics: true,
      child: CheckboxListTile(
        value: isChecked,
        onChanged: onChanged,
        secondary: Icon(icon),
        title: Text(label),
        subtitle: Text(subtitle),
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
      ),
    );
  }
}
