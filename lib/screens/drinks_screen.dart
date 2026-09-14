import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/models/models.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// Main screen showing the list of drinks
class DrinksScreen extends StatefulWidget {
  const DrinksScreen({required this.festivalId, super.key});

  final String festivalId;

  @override
  State<DrinksScreen> createState() => _DrinksScreenState();
}

class _DrinksScreenState extends State<DrinksScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;
  Timer? _searchDebounceTimer;

  void _onSearchChanged(String value) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(
      const Duration(milliseconds: 300),
      () => context.read<BeerProvider>().setSearchQuery(value),
    );
  }

  /// Abandons the find: closes the field, drops the query, and restores the
  /// festival header and overflow menu to the app bar. Reached from the app
  /// bar's back arrow and from the bottom search button while search is open.
  ///
  /// Deliberately NOT reached from the system back gesture. A PopScope here
  /// would nest inside BeerFestivalHome's exit-confirmation PopScope
  /// (beer_festival_home.dart), and Navigator invokes every registered
  /// handler for one back event — so back closed search *and* raised "Press
  /// back again to exit", arming the exit timer. Making hardware back exit
  /// search needs the two scopes coordinated, not a second PopScope here.
  ///
  /// Collapsing clears the query; expanding does not. Search here is a
  /// transient find, not a persisted facet like the category/style/visibility
  /// filters — those survive their sheet closing because a lit chip names the
  /// value still applied, whereas a closed search field can only say that
  /// *something* is narrowing the list, never which word. A query left
  /// applied behind a closed field is a list the user cannot explain.
  void _closeSearch() {
    _searchDebounceTimer?.cancel();
    // setState mutates widget-local state only. The provider call
    // stays outside the closure: notifyListeners() marks watching
    // elements dirty synchronously, and mixing that with an
    // in-progress setState is what produces "setState() or
    // markNeedsBuild() called during build" (issue #526).
    setState(() {
      _showSearch = false;
      _searchController.clear();
    });
    context.read<BeerProvider>().setSearchQuery('');
  }

  /// Clears the query but stays in the find, so a miss can be retried with a
  /// different word without leaving search and losing the keyboard. This is
  /// the in-field clear button; [_closeSearch] is the exit.
  ///
  /// No setState: the field keeps its focus precisely because nothing is
  /// rebuilt out of the tree, and the clear button's own visibility is driven
  /// off the controller by a ValueListenableBuilder in [_SearchField]. The
  /// provider call still runs outside any setState closure (issue #526).
  void _clearQuery() {
    _searchDebounceTimer?.cancel();
    _searchController.clear();
    context.read<BeerProvider>().setSearchQuery('');
  }

  void _toggleSearch() {
    if (_showSearch) {
      _closeSearch();
      return;
    }
    // Expanding adopts whatever query is already applied rather than opening
    // empty over a filtered list. The provider's query outlives this screen —
    // switching to the My Festival tab replaces the route stack via
    // context.go, so _closeSearch never runs and the query survives into the
    // next DrinksScreen. The bottom search button lights up to say so
    // (SearchButton's hasQuery && !isActive state, which is reachable only
    // this way); opening search then has to show the word, or the user is
    // looking at an empty field over a list narrowed by something invisible.
    final existingQuery = context.read<BeerProvider>().searchQuery;
    setState(() {
      _showSearch = true;
      _searchController.value = TextEditingValue(
        text: existingQuery,
        selection: TextSelection.collapsed(offset: existingQuery.length),
      );
    });
  }

  void _navigateToDetail(BuildContext context, Drink drink) {
    navigateToRoute(
      context,
      buildDrinkDetailPath(widget.festivalId, drink.category, drink.id),
    );
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Narrow per-concern selects instead of a bare watch<BeerProvider>() —
    // each select only rebuilds this screen when the specific value it reads
    // actually changes, rather than on every notifyListeners() (e.g. a
    // theme-mode change this screen doesn't render). A single context.read
    // below covers action callbacks, which never need to subscribe to
    // rebuilds.
    //
    // Festival-flash guard: the router schedules setFestival in a post-frame
    // callback, so a URL-driven festival change (cross-festival deep link on a
    // warm app, browser back/forward, the post-init redirect in main.dart)
    // would otherwise render one frame of the previous festival's name and
    // drinks before the provider catches up (issue #397). Keep it first in
    // build(), as in MyFestivalScreen. Festival.== is id-scoped by design, so
    // this selects the id specifically rather than the whole Festival object
    // (selecting the object would swallow an in-place metadata refresh).
    final currentFestivalId = context.select<BeerProvider, String>(
      (p) => p.currentFestival.id,
    );
    if (currentFestivalId != widget.festivalId) {
      return buildLoadingScaffold();
    }

    final currentFestivalName = context.select<BeerProvider, String>(
      (p) => p.currentFestival.name,
    );

    final isLoading = context.select<BeerProvider, bool>((p) => p.isLoading);
    final error = context.select<BeerProvider, String?>((p) => p.error);
    final isRefreshing = context.select<BeerProvider, bool>(
      (p) => p.isRefreshing,
    );
    final refreshNotice = context.select<BeerProvider, String?>(
      (p) => p.refreshNotice,
    );
    // Test against the unfiltered list so an active filter (favourites only,
    // search query with no matches) doesn't hide the refresh indicator.
    final hasData = context.select<BeerProvider, bool>(
      (p) => p.allDrinks.isNotEmpty,
    );
    final searchQuery = context.select<BeerProvider, String>(
      (p) => p.searchQuery,
    );
    final currentSort = context.select<BeerProvider, DrinkSort>(
      (p) => p.currentSort,
    );

    // selectedCategories/visibilityFilters/excludedAllergens each return a
    // fresh Set.unmodifiable(...) wrapper on every call, so a selector on the
    // whole Set always sees "changed" — wasteful, but harmless. Selecting
    // derived primitives keeps those reads able to actually skip.
    //
    // (selectedStyles is different: DrinkFilterController reassigns
    // _selectedStyles to a new Set on every mutation rather than mutating in
    // place, so Dart's identity == makes it genuinely selector-safe as a whole
    // Set. Primitives are used below for consistency, not necessity.)
    //
    // The actual Set contents, needed for the formatted label text, are read
    // directly off `provider` below — safe because that read isn't used as a
    // change-detection comparison.
    final selectedCategoriesLength = context.select<BeerProvider, int>(
      (p) => p.selectedCategories.length,
    );
    final selectedCategoriesEmpty = selectedCategoriesLength == 0;
    final selectedStylesLength = context.select<BeerProvider, int>(
      (p) => p.selectedStyles.length,
    );
    final selectedStylesEmpty = selectedStylesLength == 0;
    final selectedStylesFirst = context.select<BeerProvider, String?>(
      (p) => p.selectedStyles.isEmpty ? null : p.selectedStyles.first,
    );
    final visibilityFiltersLength = context.select<BeerProvider, int>(
      (p) => p.visibilityFilters.length,
    );
    final excludedAllergensLength = context.select<BeerProvider, int>(
      (p) => p.excludedAllergens.length,
    );
    final hasStyleFilter = context.select<BeerProvider, bool>(
      (p) => p.hasAvailableStyles,
    );

    final provider = context.read<BeerProvider>();

    final styleLabel = selectedStylesEmpty
        ? 'Style'
        : selectedStylesLength == 1
        ? selectedStylesFirst!
        : '$selectedStylesLength styles';
    // Formatted and sorted so the screen reader announces the same names a
    // sighted user sees, in a deterministic order (a Set has none). Reads the
    // live Set off `provider` (context.read, not a selector) — the rebuild
    // itself is already gated by the primitive selects above.
    //
    // That gating holds only because every category mutation changes the
    // Set's length: toggleCategory adds or removes exactly one entry, and
    // clearCategories empties it. A bulk setter that swapped one category for
    // another would keep the length identical, fire no select, and leave this
    // label stale — add a content-based select (e.g. the sorted joined names,
    // as _canonicalCategoryFilter already does) if one is ever introduced.
    final formattedCategories =
        provider.selectedCategories
            .map(BeverageTypeHelper.formatBeverageType)
            .toList()
          ..sort();
    final categoryLabel = selectedCategoriesEmpty
        ? 'Category'
        : selectedCategoriesLength == 1
        ? formattedCategories.first
        : '$selectedCategoriesLength categories';
    final categorySemanticLabel = formattedCategories.isEmpty
        ? 'Filter by category'
        : 'Filter by category: ${formattedCategories.join(', ')}';

    // Sorted before joining so the screen reader announces the styles in a
    // deterministic order (a Set has none) — the same reasoning as the
    // category path above, minus the formatting: styles are raw feed strings.
    // Read live off `provider`, not selected: the rebuild is already gated by
    // selectedStylesLength/selectedStylesFirst, and emptiness stays keyed to
    // that gating value so both FilterButton props agree on one source.
    final sortedStyles = provider.selectedStyles.toList()..sort();
    final styleSemanticLabel = selectedStylesEmpty
        ? 'Filter by style'
        : 'Filter by style: ${sortedStyles.join(', ')}';

    return PageTitle(
      pageTitle: currentFestivalName,
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: provider.loadDrinks,
                child: CustomScrollView(
                  slivers: [
                    // Search takes the app bar over rather than stacking a
                    // third row of chrome beneath it (#664): the field
                    // replaces FestivalHeader, the back arrow replaces the
                    // (absent) leading icon, and the overflow menu goes. The
                    // festival name, drink count, status badge and the menu's
                    // three items are unreachable for the duration — accepted,
                    // because a find is a short goal-directed mode and exiting
                    // is one tap in three places.
                    //
                    // floating/snap are suppressed while searching: a field
                    // that scrolls away mid-typing is wrong, so it pins
                    // instead. `floating || !snap` is SliverAppBar's own
                    // assertion, which is why both flags flip together.
                    SliverAppBar(
                      floating: !_showSearch,
                      snap: !_showSearch,
                      pinned: _showSearch,
                      // titleSpacing would otherwise add 16px on top of
                      // the 56px leading slot, leaving the field with a
                      // ~32px gap on its left against a 16px margin on its
                      // right — visibly off-centre. Zero it and pad the
                      // right instead, which also hands the hint back the
                      // width.
                      titleSpacing: _showSearch ? 0 : null,
                      leading: _showSearch
                          ? Semantics(
                              // Deliberately not 'Close search': the bottom
                              // SearchButton already uses that label while
                              // open, and two nodes sharing it would make
                              // find.bySemanticsLabel ambiguous in the tests
                              // that drive this screen.
                              label: 'Exit search',
                              hint:
                                  'Double tap to close search and return to '
                                  'the drinks list',
                              button: true,
                              excludeSemantics: true,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: _closeSearch,
                              ),
                            )
                          : null,
                      title: _showSearch
                          ? Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: _SearchField(
                                controller: _searchController,
                                onChanged: _onSearchChanged,
                                onClearQuery: _clearQuery,
                              ),
                            )
                          : const FestivalHeader(),
                      actions: _showSearch
                          ? null
                          : [buildOverflowMenu(context)],
                    ),
                    // Hidden while searching: it is a tap-through to
                    // festival info, not something needed mid-find, and it
                    // is the cheapest 34px (measured) of the chrome this
                    // issue is about. Returns the moment search closes.
                    if (!_showSearch)
                      SliverToBoxAdapter(
                        child: FestivalBanner(festivalId: widget.festivalId),
                      ),
                    SliverToBoxAdapter(
                      child: _RefreshStatus(
                        hasData: hasData,
                        isRefreshing: isRefreshing,
                        refreshNotice: refreshNotice,
                        onDismissNotice: provider.dismissRefreshNotice,
                      ),
                    ),
                    // provider.drinks must be observed by *identity*, not
                    // `==`. DrinkFilterController.recompute() assigns a fresh
                    // _filtered list on every change, but a plain
                    // context.select would compare the two lists with
                    // DeepCollectionEquality, which falls through to each
                    // element's own `==` — and Drink.== is id+festivalId
                    // scoped (drink.dart), so a userState-only write
                    // (rating/favourite/tasted/notes) compares equal and the
                    // rebuild is silently dropped, leaving a stale star chip
                    // on the card (#568). Scoped to this sliver rather than
                    // the whole build() because `drinks` is used only here.
                    Selector<BeerProvider, List<Drink>>(
                      selector: (_, p) => p.drinks,
                      shouldRebuild: (prev, next) => !identical(prev, next),
                      builder: (context, drinks, _) => _DrinksListSliver(
                        drinks: drinks,
                        isLoading: isLoading,
                        error: error,
                        searchQuery: searchQuery,
                        selectedCategoriesEmpty: selectedCategoriesEmpty,
                        onRetry: provider.loadDrinks,
                        onClearFilters: provider.clearCategories,
                        onDrinkTap: (drink) =>
                            _navigateToDetail(context, drink),
                        onFavoriteTap: provider.toggleFavorite,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom controls for filtering, sorting, and search - thumb friendly
            _BottomControls(
              categoryLabel: categoryLabel,
              categorySemanticLabel: categorySemanticLabel,
              categoryActive: !selectedCategoriesEmpty,
              hasStyleFilter: hasStyleFilter,
              styleLabel: styleLabel,
              styleSemanticLabel: styleSemanticLabel,
              styleActive: !selectedStylesEmpty,
              sortLabel: currentSort.label,
              sortSemanticLabel: 'Sort drinks by ${currentSort.label}',
              visibilityActiveCount:
                  visibilityFiltersLength + excludedAllergensLength,
              searchActive: _showSearch,
              searchHasQuery: searchQuery.isNotEmpty,
              onCategoryTap: () => showCategoryFilter(context),
              onStyleTap: () => showStyleFilter(context),
              onSortTap: () => showSortOptions(context),
              onVisibilityTap: () => showVisibilityFilter(context),
              onSearchToggle: _toggleSearch,
            ),
          ],
        ),
      ),
    );
  }
}

/// The search field that takes over the app bar's title while [_showSearch]
/// is true (#664). Purely presentational — the debounce timer, the query and
/// the visibility flag it mutates all live on [_DrinksScreenState].
///
/// Listens to [controller] so the clear button can appear only once there is
/// something to clear, which is also what keeps the hint's width budget
/// intact (see the note at [InputDecoration.hintText] below).
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClearQuery,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClearQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      // A TextField's accessible name is its hint only while it is empty —
      // once the user types, the node carries the value and no label at all,
      // so assistive tech can read back 'alpha' without ever saying what
      // control it belongs to. That matters more here than it would in a
      // form: the takeover has removed FestivalHeader, so this field is the
      // app bar. `container: true` is what makes the label stick to the
      // field's own node; a plain Semantics wrapper does not (it lands on an
      // ancestor node the screen reader never focuses) and neither does
      // InputDecoration.labelText — both were measured before choosing this.
      builder: (context, value, _) => Semantics(
        label: 'Search drinks',
        container: true,
        child: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            // Search covers five fields (SearchMatchService._searchableFields:
            // name, brewery, style, catalogue notes, the user's own note), and
            // this hint is the only place any of them is advertised. It names
            // the user's own note because that is the one nobody would guess is
            // searched; the catalogue description is searched too but is NOT
            // named here — the trailing ellipsis is all that stands in for it.
            //
            // That omission is a width budget, not an oversight. The budget
            // moved when the field took over the app bar (#664) but did not
            // shrink: the back arrow costs ~56px, and dropping the prefix
            // magnifier and hiding the clear button while empty give more than
            // that back. The no-overflow test in
            // drinks_screen_search_dismiss_test.dart measures the outcome at
            // 375px rather than trusting this arithmetic. If a field is added to
            // _searchableFields, decide here whether it displaces one of these.
            hintText: 'Search drinks, styles, notes...',
            // No prefix magnifier: while search is open the field *is* the app
            // bar, and the back arrow immediately to its left already says which
            // mode this is. The icon would be redundant chrome bought with the
            // hint's width.
            suffixIcon: value.text.isEmpty
                ? null
                : Semantics(
                    // Clears the query without leaving search, so a miss can be
                    // retried with another word. Exiting is the back arrow's
                    // job — see [_DrinksScreenState._clearQuery].
                    label: 'Clear search',
                    hint: 'Double tap to clear the search text',
                    button: true,
                    excludeSemantics: true,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close),
                      onPressed: onClearQuery,
                    ),
                  ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
            // Tighter than a standalone field: the whole control has to sit
            // inside the app bar's 56px toolbar.
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Thumb-friendly row of filter/sort/search controls pinned to the bottom of
/// the screen. All labels and semantic labels are computed by the host from
/// live provider reads (context.select-gated) and handed down as plain
/// strings — see the comment in [_DrinksScreenState.build] this logic moved
/// from for why reading the Sets directly is still safe there.
class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.categoryLabel,
    required this.categorySemanticLabel,
    required this.categoryActive,
    required this.hasStyleFilter,
    required this.styleLabel,
    required this.styleSemanticLabel,
    required this.styleActive,
    required this.sortLabel,
    required this.sortSemanticLabel,
    required this.visibilityActiveCount,
    required this.searchActive,
    required this.searchHasQuery,
    required this.onCategoryTap,
    required this.onStyleTap,
    required this.onSortTap,
    required this.onVisibilityTap,
    required this.onSearchToggle,
  });

  final String categoryLabel;
  final String categorySemanticLabel;
  final bool categoryActive;
  final bool hasStyleFilter;
  final String styleLabel;
  final String styleSemanticLabel;
  final bool styleActive;
  final String sortLabel;
  final String sortSemanticLabel;
  final int visibilityActiveCount;
  final bool searchActive;
  final bool searchHasQuery;
  final VoidCallback onCategoryTap;
  final VoidCallback onStyleTap;
  final VoidCallback onSortTap;
  final VoidCallback onVisibilityTap;
  final VoidCallback onSearchToggle;

  @override
  Widget build(BuildContext context) {
    // This row is genuinely over-subscribed at phone widths, so its spacing
    // is measured rather than chosen by eye. At 400 logical px the two 48px
    // square buttons, the 8px container padding and the four 4px gaps leave
    // 272px to split between the three FilterButtons. Measured against the
    // real bundled Nunito Sans at labelMedium, each button needs (label +
    // its own 16px padding + either the 18px leading glyph and its 8px gap,
    // or the 16px clear icon and its 2px gap):
    //
    //   category  '2 categories'  106.7px  <- widest, grows with selection
    //   style     '2 styles'       80.7px
    //   sort      'Name (A-Z)'    111.6px  <- cannot fit at any split
    //
    // The flex values below are therefore percentages of that 272px, not
    // arbitrary weights: 40/31/29. Category takes the largest share because
    // its label is the only one that grows with the filter; style takes
    // what it needs; sort takes the remainder. Sort is never active and
    // every DrinkSort label ('ABV (High to Low)') is wider than any share
    // this row can offer, so it ellipsizes by design — it is the right place
    // to take the slack from, and 29% still leaves it more text than it
    // rendered before this split existed.
    //
    // Widening the padding, the gaps, or the type scale spends this budget
    // and the labels start disappearing again (#579), so
    // drinks_screen_filter_bar_layout_test.dart pins the outcome.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 40,
            child: FilterButton(
              label: categoryLabel,
              semanticLabel: categorySemanticLabel,
              icon: Icons.filter_list,
              onPressed: onCategoryTap,
              isActive: categoryActive,
            ),
          ),
          if (hasStyleFilter) ...[
            const SizedBox(width: 4),
            Expanded(
              flex: 31,
              child: FilterButton(
                label: styleLabel,
                semanticLabel: styleSemanticLabel,
                icon: Icons.style,
                onPressed: onStyleTap,
                isActive: styleActive,
              ),
            ),
          ],
          const SizedBox(width: 4),
          Expanded(
            flex: 29,
            child: FilterButton(
              label: sortLabel,
              semanticLabel: sortSemanticLabel,
              icon: Icons.sort,
              onPressed: onSortTap,
              isActive: false,
            ),
          ),
          const SizedBox(width: 4),
          VisibilityFilterButton(
            activeCount: visibilityActiveCount,
            onPressed: onVisibilityTap,
          ),
          const SizedBox(width: 4),
          SearchButton(
            isActive: searchActive,
            hasQuery: searchHasQuery,
            onPressed: onSearchToggle,
          ),
        ],
      ),
    );
  }
}

/// Thin progress bar while a background refresh runs with data on screen, or
/// a dismissible notice when a refresh failed but cached data remains shown.
class _RefreshStatus extends StatelessWidget {
  const _RefreshStatus({
    required this.hasData,
    required this.isRefreshing,
    required this.refreshNotice,
    required this.onDismissNotice,
  });

  final bool hasData;
  final bool isRefreshing;
  final String? refreshNotice;
  final VoidCallback onDismissNotice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notice = refreshNotice;

    if (notice != null && hasData) {
      return Material(
        color: theme.colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off,
                size: 18,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  notice,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              Semantics(
                label: 'Dismiss saved data notice',
                hint: 'Double tap to dismiss',
                button: true,
                excludeSemantics: true,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  onPressed: onDismissNotice,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isRefreshing && hasData) {
      return Semantics(
        label: 'Refreshing drinks',
        liveRegion: true,
        child: const LinearProgressIndicator(minHeight: 2),
      );
    }

    return const SizedBox.shrink();
  }
}

/// The main drinks list sliver: loading spinner, error view, empty state, or
/// the populated [SliverList] of [DrinkCard]s, depending on [isLoading] /
/// [error] / [drinks].
class _DrinksListSliver extends StatelessWidget {
  const _DrinksListSliver({
    required this.drinks,
    required this.isLoading,
    required this.error,
    required this.searchQuery,
    required this.selectedCategoriesEmpty,
    required this.onRetry,
    required this.onClearFilters,
    required this.onDrinkTap,
    required this.onFavoriteTap,
  });

  final List<Drink> drinks;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final bool selectedCategoriesEmpty;
  final VoidCallback onRetry;
  final VoidCallback onClearFilters;
  final ValueChanged<Drink> onDrinkTap;
  final ValueChanged<Drink> onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    if (isLoading && drinks.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/app_icon.png', width: 80, height: 80),
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    if (error != null && drinks.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: CatalogueErrorView(error: error!, onRetry: onRetry),
        ),
      );
    }

    if (drinks.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Opacity(
                opacity: 0.5,
                child: Image.asset(
                  'assets/app_icon.png',
                  width: 80,
                  height: 80,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No drinks found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('Try adjusting your filters'),
              if (!selectedCategoriesEmpty) ...[
                const SizedBox(height: 16),
                Semantics(
                  label: 'Clear all category filters',
                  hint: 'Double tap to show every category',
                  button: true,
                  excludeSemantics: true,
                  child: OutlinedButton(
                    onPressed: onClearFilters,
                    child: const Text('Clear Filters'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final drink = drinks[index];
          return DrinkCard(
            key: ValueKey(drink.id),
            drink: drink,
            searchQuery: searchQuery,
            onTap: () => onDrinkTap(drink),
            onFavoriteTap: () => onFavoriteTap(drink),
          );
        }, childCount: drinks.length),
      ),
    );
  }
}
