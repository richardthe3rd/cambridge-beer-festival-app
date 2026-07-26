import 'package:flutter/material.dart';

/// Drag handle shown at the top of every modal bottom sheet in this app
/// (filter sheets, festival selector, settings, theme selector).
///
/// The key passed to this widget is applied to the inner [Container] rather
/// than to [SheetHandle] itself, so callers that key the drag handle for
/// tests (`SheetHandle(key: Key('some_drag_handle'))`) can keep finding a
/// [Container] with that key — matching the pre-refactor widget tree where
/// the key lived directly on the hand-rolled `Container`.
class SheetHandle extends StatelessWidget {
  const SheetHandle({Key? key}) : _handleKey = key, super(key: null);

  final Key? _handleKey;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        key: _handleKey,
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
