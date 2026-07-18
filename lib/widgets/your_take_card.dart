import 'dart:async';
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
///
/// Notes are edited in place: tapping the note row opens an inline, borderless
/// [TextField]. Typing debounces to an autosave (no explicit Save/Cancel), and
/// losing focus flushes immediately so a save is never lost to a stray tap
/// elsewhere on the screen.
class YourTakeCard extends StatefulWidget {
  final Drink drink;

  /// Toggle the want-to-try flag.
  final VoidCallback onWantToTryTap;

  /// Set (or clear, with null) the star rating.
  final ValueChanged<int?> onRatingChanged;

  /// Persist the note text (trimmed; empty becomes null).
  final Future<void> Function(String? notes) onNotesChanged;

  /// Called when inline note editing starts (true) or ends (false), so the
  /// host screen can clear competing chrome — e.g. a floating action button
  /// that would otherwise sit over the field once the keyboard is up.
  final ValueChanged<bool>? onEditingChanged;

  const YourTakeCard({
    required this.drink,
    required this.onWantToTryTap,
    required this.onRatingChanged,
    required this.onNotesChanged,
    this.onEditingChanged,
    super.key,
  });

  /// How long to wait after the last keystroke before autosaving. Exposed for
  /// tests so they can advance virtual time deterministically instead of
  /// guessing at a real-world delay.
  @visibleForTesting
  static const Duration notesDebounceDuration = Duration(milliseconds: 600);

  /// How long the "Saved" indicator stays visible after a successful save.
  @visibleForTesting
  static const Duration savedIndicatorDuration = Duration(seconds: 2);

  @override
  State<YourTakeCard> createState() => _YourTakeCardState();
}

class _YourTakeCardState extends State<YourTakeCard> {
  late final TextEditingController _notesController;
  final FocusNode _notesFocusNode = FocusNode();
  Timer? _debounceTimer;
  Timer? _savedIndicatorTimer;
  bool _isEditing = false;
  bool _showSaved = false;
  String? _lastSavedNotes;
  bool _hasPendingEdit = false;

  @override
  void initState() {
    super.initState();
    _lastSavedNotes = widget.drink.userNotes;
    _notesController = TextEditingController(text: _lastSavedNotes ?? '');
    _notesFocusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant YourTakeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An autosave's own provider rebuild must not stomp text the user is
    // actively typing — only resync from upstream while not editing.
    if (!_isEditing && widget.drink.userNotes != oldWidget.drink.userNotes) {
      _lastSavedNotes = widget.drink.userNotes;
      _notesController.text = _lastSavedNotes ?? '';
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _savedIndicatorTimer?.cancel();
    // Best-effort flush: if there's an edit whose save hasn't landed yet
    // (including clearing the note to empty), fire it now rather than
    // silently dropping the user's last edit.
    final normalized = _normalizedControllerText;
    if (_hasPendingEdit && normalized != _lastSavedNotes) {
      unawaited(widget.onNotesChanged(normalized));
    }
    _notesFocusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// The controller text as it would be persisted: trimmed, empty → null.
  String? get _normalizedControllerText {
    final trimmed = _notesController.text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _handleFocusChange() {
    if (!_notesFocusNode.hasFocus && _isEditing) {
      unawaited(_flushSave());
      setState(() => _isEditing = false);
      widget.onEditingChanged?.call(false);
    }
  }

  void _beginEditing() {
    setState(() => _isEditing = true);
    _notesFocusNode.requestFocus();
    widget.onEditingChanged?.call(true);
  }

  void _onFieldChanged(String value) {
    _hasPendingEdit = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      YourTakeCard.notesDebounceDuration,
      () => unawaited(_flushSave()),
    );
  }

  Future<void> _flushSave() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    final normalized = _normalizedControllerText;
    _hasPendingEdit = false;
    if (normalized == _lastSavedNotes) return;
    final previous = _lastSavedNotes;
    _lastSavedNotes = normalized;
    try {
      await widget.onNotesChanged(normalized);
    } catch (_) {
      // The write failed — keep the edit pending so the next flush (debounce,
      // blur, or dispose) retries it, and don't claim "Saved".
      _lastSavedNotes = previous;
      _hasPendingEdit = true;
      return;
    }
    // If the user typed again while this save was in flight, the newest text
    // is not persisted yet — claiming "Saved" now would be a lie. The pending
    // edit's own flush will show the indicator when it lands.
    if (!mounted || _hasPendingEdit) return;
    _savedIndicatorTimer?.cancel();
    setState(() => _showSaved = true);
    _savedIndicatorTimer = Timer(YourTakeCard.savedIndicatorDuration, () {
      if (mounted) setState(() => _showSaved = false);
    });
  }

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
            _buildNoteSection(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildWantToTry(ThemeData theme) {
    final active = widget.drink.isFavorite;
    final color = active
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      label: active
          ? 'Remove ${widget.drink.name} from want to try'
          : 'Add ${widget.drink.name} to want to try',
      button: true,
      toggled: active,
      child: InkWell(
        onTap: widget.onWantToTryTap,
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
          rating: widget.drink.rating,
          isEditable: true,
          starSize: 30,
          onRatingChanged: widget.onRatingChanged,
        ),
        if (widget.drink.rating == null) ...[
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

  Widget _buildNoteSection(ThemeData theme) {
    if (_isEditing) {
      return Container(
        padding: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('user-notes-field'),
              controller: _notesController,
              focusNode: _notesFocusNode,
              autofocus: true,
              minLines: 1,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'What did you think?',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: _onFieldChanged,
            ),
            SizedBox(
              height: 16,
              // Only mount the live region while it has something to say —
              // the same conditional pattern as the refresh indicator in
              // drinks_screen.dart. A persistent node with an empty label
              // would sit in the semantics tree saying nothing.
              child: _showSaved
                  ? Semantics(
                      liveRegion: true,
                      label: 'Saved',
                      child: Text(
                        'Saved',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }

    // Render the optimistic local value, not widget.drink.userNotes — on blur
    // the card returns to display mode before the async save (and the
    // provider rebuild it triggers) has landed, and the note the user just
    // typed must not flash back to its previous state in that window.
    final notes = _lastSavedNotes;
    final hasNotes = notes != null && notes.isNotEmpty;

    return Semantics(
      label: hasNotes
          ? 'Edit your notes for ${widget.drink.name}'
          : 'Add your notes for ${widget.drink.name}',
      button: true,
      hint: 'Double tap to edit in place. Autosaves as you type.',
      child: InkWell(
        key: const ValueKey('user-notes-editor'),
        onTap: _beginEditing,
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
