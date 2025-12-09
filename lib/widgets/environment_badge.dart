import 'package:flutter/material.dart';
import '../services/environment_service.dart';

/// Badge that displays the current environment (staging/preview) when not in production
/// Only visible on non-production environments to help testers identify the environment
class EnvironmentBadge extends StatelessWidget {
  const EnvironmentBadge({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show badge in non-production environments
    if (EnvironmentService.isProduction()) {
      return const SizedBox.shrink();
    }

    final environmentName = EnvironmentService.getEnvironmentName();
    final theme = Theme.of(context);

    // Different colors for different environments
    Color badgeColor;
    Color textColor;
    
    switch (environmentName) {
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
      top: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
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
                environmentName.toUpperCase(),
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
    );
  }
}
