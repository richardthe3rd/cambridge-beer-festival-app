import 'package:flutter/material.dart';
import '../models/models.dart';
import 'star_rating.dart';

/// The "Your take" card — everything that is the *user's* relationship to a
/// drink, gathered in one place directly under the identity hero: whether they
/// want to try it, their star rating, and their tasting note.
///
/// The drink's own facts live in the hero; nothing here describes the drink
/// itself. Actions are delegated to callbacks so the screen keeps ownership of
/// the provider and analytics.
class YourTakeCard extends StatelessWidget {
  final Drink drink;

  /// Toggle the want-to-try flag.
  final VoidCallback onWantToTryTap;

  /// Set (or clear, with null) the star rating.
  final ValueChanged<int?> onRatingChanged;

  /// Open the note editor.
  final VoidCallback onEditNote;

  const YourTakeCard({
    required this.drink,
    required this.onWantToTryTap,
    required this.onRatingChanged,
    required this.onEditNote,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      // A subtle outline so this "yours" card reads as a distinct panel
      // against the surface — especially in dark mode.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Your take',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                _buildWantToTry(theme),
              ],
            ),
            const SizedBox(height: 12),
            _buildRating(theme),
            const SizedBox(height: 12),
            _buildNoteRow(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildWantToTry(ThemeData theme) {
    final active = drink.isFavorite;
    final color = active
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      label: active
          ? 'Remove ${drink.name} from want to try'
          : 'Add ${drink.name} to want to try',
      button: true,
      toggled: active,
      child: InkWell(
        onTap: onWantToTryTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: active
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            border: Border.all(
              color: active
                  ? theme.colorScheme.primary.withValues(alpha: 0.5)
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? Icons.bookmark : Icons.bookmark_border,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                'Want to Try',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRating(ThemeData theme) {
    return Row(
      children: [
        StarRating(
          rating: drink.rating,
          isEditable: true,
          starSize: 30,
          onRatingChanged: onRatingChanged,
        ),
        if (drink.rating == null) ...[
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tap a star to rate',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNoteRow(ThemeData theme) {
    final notes = drink.userNotes;
    final hasNotes = notes != null && notes.isNotEmpty;

    return Semantics(
      label: hasNotes
          ? 'Edit your notes for ${drink.name}'
          : 'Add your notes for ${drink.name}',
      button: true,
      child: InkWell(
        key: const ValueKey('user-notes-editor'),
        onTap: onEditNote,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  hasNotes ? notes : 'Tap to add your notes',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: hasNotes
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                    fontStyle: hasNotes ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.edit,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
