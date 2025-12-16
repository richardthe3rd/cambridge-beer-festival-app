import 'package:flutter/material.dart';

/// A vertical alphabet scrollbar widget for quick navigation through A-Z sorted lists
/// 
/// Displays letters A-Z vertically and allows users to tap on a letter to jump
/// to items starting with that letter in the list.
class AlphabetScrollbar extends StatefulWidget {
  /// Callback when a letter is tapped, receives the tapped letter
  final void Function(String letter) onLetterTapped;
  
  /// Set of letters that have items in the list (optional)
  /// Letters not in this set will be displayed with reduced opacity
  final Set<String>? availableLetters;

  const AlphabetScrollbar({
    super.key,
    required this.onLetterTapped,
    this.availableLetters,
  });

  @override
  State<AlphabetScrollbar> createState() => _AlphabetScrollbarState();
}

class _AlphabetScrollbarState extends State<AlphabetScrollbar> {
  String? _activeLetter;

  static const _alphabet = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
  ];

  void _handleLetterTap(String letter) {
    setState(() {
      _activeLetter = letter;
    });
    widget.onLetterTapped(letter);
    
    // Clear active letter after animation
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _activeLetter = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      width: 24,
      margin: const EdgeInsets.only(right: 4, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _alphabet.map((letter) {
          final isAvailable = widget.availableLetters?.contains(letter) ?? true;
          final isActive = _activeLetter == letter;
          
          return Expanded(
            child: Semantics(
              label: 'Jump to letter $letter',
              hint: isAvailable 
                  ? 'Double tap to scroll to drinks starting with $letter'
                  : 'No drinks starting with $letter',
              button: true,
              enabled: isAvailable,
              child: GestureDetector(
                onTap: isAvailable ? () => _handleLetterTap(letter) : null,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primary.withValues(alpha: 0.3)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isAvailable
                            ? (isActive 
                                ? theme.colorScheme.primary 
                                : theme.colorScheme.onSurface)
                            : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
