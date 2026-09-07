import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../domain/models/models.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';

/// First-run preference flow.
///
/// Asks a brand-new user the two questions that make a 400-drink list
/// navigable — which kinds of drink they care about, and whether to hide
/// what they can't have — then writes both as saved preferences
/// ([BeerProvider.applyOnboardingPreferences]) and hands them the drinks
/// list already filtered.
///
/// Reachable two ways: automatically from `/` on a first launch (see the
/// root redirect in `router.dart`), and on demand from the settings sheet.
/// Both entry points land here, so the screen must work with preferences
/// already set — the initial selection is seeded from the provider's current
/// state rather than assuming empty.
///
/// Nothing here is a lock-in: every answer maps onto the same category and
/// view filters the drinks screen's own controls edit, and the filter buttons
/// show an active state with a clear (x) so a saved choice is always visible
/// and reversible.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  /// Selected [Drink.category] values. Empty means "show everything", matching
  /// the null-vs-empty convention the filter fields use throughout.
  late Set<String> _categories;
  late Set<DrinkVisibilityFilter> _visibilityFilters;
  late Set<String> _excludedAllergens;

  /// The dietary switches to offer, given what the loaded catalogue actually
  /// declares.
  ///
  /// Mirrors `VisibilityFilterSheet`'s own rule rather than hard-coding a
  /// list, because the feeds are uneven and a filter with no data behind it
  /// is a switch that empties the list:
  ///
  ///  * [DrinkVisibilityFilter.availableOnly] is always offered —
  ///    `filterByAvailability` drops only an explicit sold-out status, so a
  ///    drink whose availability is unknown survives it.
  ///  * [DrinkVisibilityFilter.veganOnly] only when the catalogue carries
  ///    `is_vegan` at all. That field entered the feed with cbf2026; on the
  ///    three earlier festivals every product is null, and `filterByVegan`
  ///    excludes null, so the switch would return nothing.
  ///  * [DrinkVisibilityFilter.notTasted] never — it hides drinks already in
  ///    the tasting log, which is empty by definition for the audience this
  ///    screen exists for.
  ///
  /// Allergen exclusions are offered separately, from
  /// [BeerProvider.availableAllergens], which by construction lists only
  /// allergens something in scope actually declares.
  List<DrinkVisibilityFilter> _offeredVisibilityFilters(BeerProvider provider) {
    return [
      DrinkVisibilityFilter.availableOnly,
      if (provider.hasVeganData) DrinkVisibilityFilter.veganOnly,
    ];
  }

  @override
  void initState() {
    super.initState();
    final provider = context.read<BeerProvider>();
    _categories = Set<String>.from(provider.selectedCategories);
    _visibilityFilters = Set<DrinkVisibilityFilter>.from(
      provider.visibilityFilters,
    );
    _excludedAllergens = Set<String>.from(provider.excludedAllergens);
  }

  /// The categories to offer.
  ///
  /// Prefers the loaded catalogue's own categories, which are the exact values
  /// the filter matches against. Falls back to the festival registry's
  /// beverage types — mapped through [BeverageCategories.feedCategoryFor],
  /// because two feed slugs differ from the category their products carry —
  /// so the screen still works on a first launch that never reached the
  /// network.
  List<String> _categoryOptions(BeerProvider provider) {
    final loaded = provider.availableCategories;
    if (loaded.isNotEmpty) return loaded;
    return provider.currentFestival.availableBeverageTypes
        .map(BeverageCategories.feedCategoryFor)
        .toSet()
        .toList()
      ..sort();
  }

  /// Leaves the screen the way it was entered: a re-visit from settings was
  /// pushed and pops back to where it came from, whereas the first-run
  /// redirect replaced `/` and has nothing to pop, so it goes to the drinks
  /// list instead.
  void _leave(String festivalId) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(buildFestivalHome(festivalId));
    }
  }

  Future<void> _finish() async {
    final provider = context.read<BeerProvider>();
    final festivalId = provider.currentFestival.id;
    await provider.applyOnboardingPreferences(
      categories: _categories,
      visibilityFilters: _visibilityFilters,
      excludedAllergens: _excludedAllergens,
    );
    if (!mounted) return;
    _leave(festivalId);
  }

  Future<void> _dismiss() async {
    final provider = context.read<BeerProvider>();
    final festivalId = provider.currentFestival.id;
    // Only the first run has anything to record; a later visit from settings
    // is a plain cancel and must not rewrite the flag.
    if (!provider.hasCompletedOnboarding) {
      await provider.skipOnboarding();
    }
    if (!mounted) return;
    _leave(festivalId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<BeerProvider>();
    final options = _categoryOptions(provider);
    // The same screen serves the first run and a later edit from settings;
    // only the framing changes.
    final isFirstRun = !provider.hasCompletedOnboarding;
    final dismissLabel = isFirstRun ? 'Skip' : 'Cancel';
    final confirmLabel = isFirstRun ? 'Start browsing' : 'Save';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                // Generous bottom padding so the last dietary switch does
                // not sit flush against the fixed action row when the list
                // runs long (five allergens on some festivals).
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFirstRun
                          ? 'Welcome to ${provider.currentFestival.name}'
                          : 'Drink preferences',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tell us what you drink and we will show you that first. '
                      'You can change any of this later from the filter '
                      'buttons on the drinks list.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'What do you drink?',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pick as many as you like, or none to see everything.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final category in options)
                          _CategoryChoiceChip(
                            category: category,
                            selected: _categories.contains(category),
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                _categories.add(category);
                              } else {
                                _categories.remove(category);
                              }
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Anything to hide?',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    for (final filter in _offeredVisibilityFilters(provider))
                      _VisibilityChoiceTile(
                        filter: filter,
                        value: _visibilityFilters.contains(filter),
                        onChanged: (value) => setState(() {
                          if (value) {
                            _visibilityFilters.add(filter);
                          } else {
                            _visibilityFilters.remove(filter);
                          }
                        }),
                      ),
                    for (final allergen
                        in (provider.availableAllergens.toList()..sort()))
                      _AllergenChoiceTile(
                        allergen: allergen,
                        value: _excludedAllergens.contains(allergen),
                        onChanged: (value) => setState(() {
                          if (value) {
                            _excludedAllergens.add(allergen);
                          } else {
                            _excludedAllergens.remove(allergen);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: dismissLabel,
                      hint: isFirstRun
                          ? 'Double tap to browse everything without '
                                'setting preferences'
                          : 'Double tap to leave your preferences unchanged',
                      button: true,
                      excludeSemantics: true,
                      child: OutlinedButton(
                        key: const ValueKey('welcome-skip'),
                        onPressed: _dismiss,
                        child: Text(dismissLabel),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Semantics(
                      label: 'Save preferences and start browsing',
                      hint: 'Double tap to apply your choices',
                      button: true,
                      excludeSemantics: true,
                      child: FilledButton(
                        key: const ValueKey('welcome-continue'),
                        onPressed: _finish,
                        child: Text(confirmLabel),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One drink-category choice. Mirrors the `Semantics(label/value/selected)`
/// shape the filter sheets use, so a screen reader announces the selection
/// state independently of the chip's visible styling.
class _CategoryChoiceChip extends StatelessWidget {
  final String category;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _CategoryChoiceChip({
    required this.category,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final label = BeverageTypeHelper.formatBeverageType(category);
    return Semantics(
      label: label,
      value: selected ? 'Selected' : 'Not selected',
      selected: selected,
      button: true,
      excludeSemantics: true,
      child: FilterChip(
        key: ValueKey('welcome-category-$category'),
        selected: selected,
        onSelected: onSelected,
        avatar: Icon(
          BeverageTypeHelper.getBeverageIcon(
            BeverageCategories.slugFor(category),
          ),
          size: 18,
        ),
        label: Text(label),
      ),
    );
  }
}

/// One allergen exclusion, rendered like a view-filter switch.
///
/// Kept a separate widget from [_VisibilityChoiceTile] because the options are
/// data-driven rather than enum-driven: the set comes from
/// [BeerProvider.availableAllergens], so it varies by festival and by what is
/// in scope.
///
/// The wording matches `VisibilityFilterSheet`'s deliberately. "Hide drinks
/// containing X" is what the filter does — it removes drinks that *declare* X.
/// It does not promise the remainder are free of it, and the feeds do not
/// support that stronger claim: outside the domestic beer feed most products
/// carry an empty `allergens` map, which is indistinguishable from a declared
/// absence.
class _AllergenChoiceTile extends StatelessWidget {
  final String allergen;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AllergenChoiceTile({
    required this.allergen,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final title = allergen.isEmpty
        ? allergen
        : allergen[0].toUpperCase() + allergen.substring(1);
    final subtitle = 'Hides drinks containing $allergen';
    return Semantics(
      label: title,
      value: value ? 'On' : 'Off',
      toggled: value,
      hint: subtitle,
      excludeSemantics: true,
      child: SwitchListTile(
        key: ValueKey('welcome-allergen-$allergen'),
        value: value,
        onChanged: onChanged,
        title: Text(title),
        subtitle: Text(subtitle),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

/// One view-filter choice, rendered as a switch row with an explanation of
/// what it hides.
class _VisibilityChoiceTile extends StatelessWidget {
  final DrinkVisibilityFilter filter;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _VisibilityChoiceTile({
    required this.filter,
    required this.value,
    required this.onChanged,
  });

  static const _labels = <DrinkVisibilityFilter, (String, String)>{
    DrinkVisibilityFilter.availableOnly: (
      'Only what is on now',
      'Hides drinks that are sold out or not yet on the bar',
    ),
    DrinkVisibilityFilter.veganOnly: (
      'Vegan only',
      'Hides drinks not marked as vegan',
    ),
    DrinkVisibilityFilter.notTasted: (
      'Hide what I have tasted',
      'Hides drinks already in your tasting log',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = _labels[filter]!;
    return Semantics(
      label: title,
      value: value ? 'On' : 'Off',
      toggled: value,
      hint: subtitle,
      excludeSemantics: true,
      child: SwitchListTile(
        key: ValueKey('welcome-filter-${filter.name}'),
        value: value,
        onChanged: onChanged,
        title: Text(title),
        subtitle: Text(subtitle),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
