import 'package:collection/collection.dart';

import '../../models/models.dart';

/// Owns in-memory festival registry state: the festivals list, the current
/// selection, staleness timestamps, and beverage-type comparison.
///
/// Pure application logic: no Flutter, persistence, async, or analytics
/// dependencies, so it can be unit-tested in isolation. [BeerProvider] composes
/// this controller and handles the cross-cutting concerns (persistence,
/// analytics, change notification, and async I/O) around it.
///
/// All mutators are synchronous and side-effect free; callers are responsible
/// for persisting and broadcasting changes.
class FestivalController {
  List<Festival> _festivals = [];
  Festival? _currentFestival;

  /// When the festivals list was last successfully refreshed from the network.
  ///
  /// Exposed as a public field so callers (tests and [BeerProvider]) can
  /// inject a timestamp for testing the staleness logic.
  DateTime? lastFestivalsRefresh;

  /// When a festivals refresh was last attempted (success or failure).
  ///
  /// Exposed as a public field for the same reason as [lastFestivalsRefresh].
  DateTime? lastFestivalsRefreshAttempt;

  static const Duration _festivalsStalenessThreshold = Duration(hours: 24);

  // --- Getters ---

  /// Unmodifiable view of the loaded festivals.
  List<Festival> get festivals => List.unmodifiable(_festivals);

  /// The currently selected festival.
  ///
  /// Returns [_currentFestival] if set, otherwise the first festival in the
  /// list, or the first [DefaultFestivals.all] entry as a final fallback.
  Festival get currentFestival =>
      _currentFestival ??
      _festivals.firstOrNull ??
      DefaultFestivals.all.firstWhere(
        (f) => f.isActive,
        orElse: () => DefaultFestivals.all.first,
      );

  /// True when the festivals list is non-empty.
  bool get hasFestivals => _festivals.isNotEmpty;

  /// Festivals sorted by date: live first, then upcoming (soonest first),
  /// then past (most recent first). Delegates to [Festival.sortByDate].
  List<Festival> get sortedFestivals => Festival.sortByDate(_festivals);

  /// True when the festivals data is stale and should be refreshed.
  ///
  /// Stale means: never refreshed, or last refreshed more than 24 hours ago.
  bool get isFestivalsDataStale {
    if (lastFestivalsRefresh == null) return true;
    return DateTime.now().difference(lastFestivalsRefresh!) >
        _festivalsStalenessThreshold;
  }

  // --- Source management ---

  /// Replace the festivals list and update internal state.
  ///
  /// - Updates [lastFestivalsRefresh] to now.
  /// - Re-points [_currentFestival] to the refreshed object if already
  ///   selected (matched by id), so any updated metadata (e.g. new beverage
  ///   types) is reflected immediately.
  /// - Applies [defaultFestival] only if [_currentFestival] is still null
  ///   after the re-point step.
  ///
  /// Returns true when the current festival's beverage types changed (so the
  /// caller knows to trigger a drinks reload), false otherwise.
  bool setSource(List<Festival> festivals, {Festival? defaultFestival}) {
    _festivals = festivals;
    lastFestivalsRefresh = DateTime.now();

    // Re-point the current selection at the refreshed object if the id matches.
    // Capture old beverage types before re-pointing so we can compare.
    final previousBeverageTypes = _currentFestival?.availableBeverageTypes;
    if (_currentFestival != null) {
      final refreshed = _festivals.firstWhereOrNull(
        (f) => f.id == _currentFestival!.id,
      );
      if (refreshed != null) {
        _currentFestival = refreshed;
      }
    }

    // Apply the default only when no selection exists.
    if (_currentFestival == null && defaultFestival != null) {
      _currentFestival = defaultFestival;
    }

    // Report whether the beverage types actually changed.
    if (previousBeverageTypes == null) return false;
    return !_sameBeverageTypes(
      previousBeverageTypes,
      _currentFestival?.availableBeverageTypes,
    );
  }

  /// Restore the festivals list from cache without updating [lastFestivalsRefresh].
  ///
  /// Used during app initialization to populate the UI from cached data. Does
  /// not record a refresh timestamp, allowing [isFestivalsDataStale] to remain
  /// true and [refreshIfStale()] to immediately try the network. Re-points
  /// [_currentFestival] to the refreshed object if a festival is already
  /// selected (matched by id).
  void setCachedFestivals(List<Festival> festivals) {
    _festivals = festivals;

    // Re-point the current selection at the refreshed object if the id matches.
    if (_currentFestival != null) {
      final refreshed = _festivals.firstWhereOrNull(
        (f) => f.id == _currentFestival!.id,
      );
      if (refreshed != null) {
        _currentFestival = refreshed;
      }
    }
  }

  /// Set the fallback festivals list (e.g. from cache) without touching
  /// [lastFestivalsRefresh]. Records [lastFestivalsRefreshAttempt] instead.
  void setFallbackFestivals(
    List<Festival> festivals, {
    Festival? defaultFestival,
  }) {
    _festivals = festivals;
    if (_currentFestival == null && defaultFestival != null) {
      _currentFestival = defaultFestival;
    }
    lastFestivalsRefreshAttempt = DateTime.now();
  }

  // --- Selection management ---

  /// Explicitly set the current festival.
  void selectFestival(Festival festival) {
    _currentFestival = festival;
  }

  /// Restore the previous selection from a saved festival id.
  ///
  /// Looks up [savedId] in the current festivals list and sets
  /// [_currentFestival] if found. No-op (no exception) if [savedId] is null,
  /// empty, or not found in the list.
  void restoreSelection(String? savedId) {
    if (savedId == null || savedId.isEmpty) return;
    final found = _festivals.firstWhereOrNull((f) => f.id == savedId);
    if (found != null) {
      _currentFestival = found;
    }
  }

  /// Set [_currentFestival] to [defaultFestival] only when no festival is
  /// currently selected. No-op when already selected or [defaultFestival] is
  /// null.
  void applyFallback({Festival? defaultFestival}) {
    if (_currentFestival != null) return;
    if (defaultFestival == null) return;
    _currentFestival = defaultFestival;
  }

  // --- Timestamp management ---

  /// Record that a festivals refresh was attempted (success or failure).
  void recordAttempt() {
    lastFestivalsRefreshAttempt = DateTime.now();
  }

  // --- Query helpers ---

  /// True when [festivalId] refers to a festival in the current list.
  ///
  /// Returns false for null, empty, or unrecognised ids.
  bool isValidFestivalId(String? festivalId) {
    if (festivalId == null || festivalId.isEmpty) return false;
    return _festivals.any((f) => f.id == festivalId);
  }

  /// Return the festival with [festivalId], or null if not found.
  Festival? getFestivalById(String festivalId) {
    return _festivals.firstWhereOrNull((f) => f.id == festivalId);
  }

  // --- Lifecycle ---

  /// Clear the festivals list.
  void clearFestivals() {
    _festivals = [];
  }

  // --- Private helpers ---

  /// Compares two beverage-type lists as unordered sets, so a harmless
  /// reordering in the registry doesn't trigger a needless drinks refetch.
  static bool _sameBeverageTypes(List<String>? a, List<String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    final setA = a.toSet();
    final setB = b.toSet();
    return setA.length == setB.length && setA.containsAll(setB);
  }
}
