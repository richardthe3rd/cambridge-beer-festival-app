/// Sort options for the drinks list
enum DrinkSort { nameAsc, nameDesc, abvHigh, abvLow, brewery, style }

/// Human-readable labels for [DrinkSort] values, shown in the sort UI.
extension DrinkSortLabel on DrinkSort {
  String get label {
    switch (this) {
      case DrinkSort.nameAsc:
        return 'Name (A-Z)';
      case DrinkSort.nameDesc:
        return 'Name (Z-A)';
      case DrinkSort.abvHigh:
        return 'ABV (High to Low)';
      case DrinkSort.abvLow:
        return 'ABV (Low to High)';
      case DrinkSort.brewery:
        return 'Brewery (A-Z)';
      case DrinkSort.style:
        return 'Style (A-Z)';
    }
  }
}
