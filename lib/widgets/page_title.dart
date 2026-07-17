import 'package:flutter/material.dart';

/// Sets the browser tab / OS task-switcher title for the screen it wraps.
///
/// On web this drives `document.title`, so the browser tab reads something
/// useful (e.g. "Adnams Ghost Ship · Cambridge Beer Festival 2025") instead of
/// falling back to the raw URL. On mobile it updates the app's entry in the OS
/// task switcher. It renders no visual output of its own — it only wraps [child]
/// in a [Title] widget — so it has no effect on goldens.
///
/// [pageTitle] is the page-specific part. When [contextLabel] is non-empty it is
/// appended after a middot separator, giving a consistent
/// "{page} · {context}" shape across screens; pass the festival name as
/// [contextLabel] on festival-scoped screens.
class PageTitle extends StatelessWidget {
  const PageTitle({
    required this.pageTitle,
    this.contextLabel,
    required this.child,
    super.key,
  });

  /// The page-specific part of the title (drink name, "My Festival", etc.).
  final String pageTitle;

  /// Optional trailing context appended after a separator — typically the
  /// festival name. When null or empty, only [pageTitle] is shown.
  final String? contextLabel;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final suffix = contextLabel;
    final title = (suffix == null || suffix.isEmpty)
        ? pageTitle
        : '$pageTitle · $suffix';
    // Colour is used only for the OS task-switcher tint on mobile (ignored on
    // web). Theme.of never returns null — it falls back to a default theme when
    // no ancestor is present — so this is safe even in a minimal test tree.
    return Title(
      title: title,
      color: Theme.of(context).colorScheme.primary,
      child: child,
    );
  }
}
