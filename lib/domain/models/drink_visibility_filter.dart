/// Visibility filter options for the drinks list.
///
/// Each value represents a filter that can be independently toggled.
/// Multiple filters are applied with AND logic (all conditions must be met).
enum DrinkVisibilityFilter {
  /// Hide drinks that are sold out or not yet available
  availableOnly,

  /// Hide drinks the user has already tasted
  notTasted,

  /// Show only drinks marked as vegan
  veganOnly,
}
