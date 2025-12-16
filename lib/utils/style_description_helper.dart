import 'dart:convert';
import 'package:flutter/services.dart';

/// Helper class for getting beer style descriptions
///
/// Provides descriptive text for different beer styles based on the
/// Cambridge Beer Festival style guide.
class StyleDescriptionHelper {
  static Map<String, String>? _styleDescriptions;
  static bool _isLoaded = false;

  /// Load style descriptions from the JSON asset file
  /// 
  /// This is called automatically on first use, but can be called
  /// explicitly to preload the data.
  static Future<void> _loadDescriptions() async {
    if (_isLoaded) return;
    
    try {
      final jsonString = await rootBundle.loadString('assets/style_descriptions.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString) as Map<String, dynamic>;
      
      _styleDescriptions = {};
      for (final entry in jsonData.entries) {
        if (entry.value is String && (entry.value as String).isNotEmpty) {
          _styleDescriptions![entry.key.toLowerCase()] = entry.value as String;
        }
      }
      
      _isLoaded = true;
    } catch (e) {
      // If file doesn't exist or can't be loaded, use empty map
      _styleDescriptions = {};
      _isLoaded = true;
    }
  }

  /// Get the description for a beer style
  /// 
  /// Returns null if no description is available for the style.
  /// Loads descriptions from JSON file on first call.
  static Future<String?> getStyleDescription(String? style) async {
    if (style == null) return null;
    
    // Load descriptions if not already loaded
    await _loadDescriptions();
    
    // Normalize the style name for lookup (case-insensitive)
    final normalizedStyle = style.toLowerCase().trim();
    
    return _styleDescriptions?[normalizedStyle];
  }
  
  /// Get the description for a beer style synchronously
  /// 
  /// Returns null if descriptions haven't been loaded yet or if no description exists.
  /// Use this only after calling getStyleDescription at least once, or when you're sure
  /// the data is loaded.
  static String? getStyleDescriptionSync(String? style) {
    if (style == null || _styleDescriptions == null) return null;
    
    // Normalize the style name for lookup (case-insensitive)
    final normalizedStyle = style.toLowerCase().trim();
    
    return _styleDescriptions![normalizedStyle];
  }
}
