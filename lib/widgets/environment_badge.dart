import 'package:flutter/material.dart';
import '../services/environment_service.dart';

/// Badge that displays the current environment (staging/preview) when not in production
/// Only visible on non-production environments to help testers identify the environment
class EnvironmentBadge extends StatelessWidget {
  final String? environmentName;
  
  const EnvironmentBadge({super.key, this.environmentName});

  /// Convert environment name to title case for display
  String _toTitleCase(String text) {
    if (text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    // Get environment name - use provided parameter or detect from service
    final envName = environmentName ?? EnvironmentService.getEnvironmentName();
    
    // Only show badge if there's an environment name (non-production)
    // When environmentName is explicitly provided (for tests), always show
    // When using service detection, only show if not production
    if (environmentName == null && EnvironmentService.isProduction()) {
      return const SizedBox.shrink();
    }
    
    // If no environment name at all, don't show badge
    if (envName.isEmpty) {
      return const SizedBox.shrink();
    }

    // Different colors for different environments
    Color badgeColor;
    Color textColor;
    
    // Normalize to lowercase for case-insensitive matching
    switch (envName.toLowerCase()) {
      case 'staging':
        badgeColor = Colors.orange;
        textColor = Colors.white;
        break;
      case 'preview':
        badgeColor = Colors.purple;
        textColor = Colors.white;
        break;
      case 'development':
        badgeColor = Colors.blue;
        textColor = Colors.white;
        break;
      default:
        badgeColor = Colors.grey;
        textColor = Colors.white;
    }

    return Positioned(
      bottom: 68, // Position above the NavigationBar (60px height + 8px margin)
      left: 0,
      child: SafeArea(
        child: Semantics(
          label: 'Environment badge: ${_toTitleCase(envName)}. This is a ${envName.toLowerCase()} environment, not production.',
          excludeSemantics: true,
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.science_outlined,
                  size: 16,
                  color: textColor,
                ),
                const SizedBox(width: 6),
                Text(
                  _toTitleCase(envName),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
