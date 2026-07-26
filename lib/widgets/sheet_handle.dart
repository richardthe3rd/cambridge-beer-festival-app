import 'package:flutter/material.dart';

/// Drag handle shown at the top of every modal bottom sheet in this app
/// (filter sheets, festival selector, settings, theme selector).
///
/// [handleKey] is applied to the inner [Container] rather than to this widget,
/// so callers that key the drag handle for tests keep finding a [Container]
/// with that key — matching the pre-refactor widget tree, where the key lived
/// directly on the hand-rolled `Container`. Keying the widget itself via [key]
/// remains available and behaves normally.
class SheetHandle extends StatelessWidget {
  const SheetHandle({this.handleKey, super.key});

  /// Key applied to the inner container, for tests locating the handle.
  final Key? handleKey;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        key: handleKey,
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
