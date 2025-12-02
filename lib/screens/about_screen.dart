import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/providers.dart';

/// Screen showing app information, version, and links
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  // App metadata (loaded dynamically from package info)
  String appVersion = 'Loading...';
  String buildNumber = '';
  static const String appName = 'Cambridge Beer Festival';
  static const String githubUrl = 'https://github.com/richardthe3rd/cambridge-beer-festival-app';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      appVersion = packageInfo.version;
      buildNumber = packageInfo.buildNumber;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BeerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            _buildAppInfo(context),
            _buildDataInfo(context, provider),
            _buildSettings(context, provider),
            _buildLinks(context),
            _buildLegalInfo(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      color: theme.colorScheme.primaryContainer,
      child: Column(
        children: [
          Icon(
            Icons.local_drink,
            size: 64,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(height: 16),
          Text(
            _AboutScreenState.appName,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Version $appVersion ($buildNumber)',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfo(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Text(
            'A Flutter app for browsing drinks at the Cambridge Beer Festival. '
            'Browse beers, ciders, meads, wines, and more. Save your favorites, '
            'rate drinks, and plan your festival experience.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDataInfo(BuildContext context, BeerProvider provider) {
    final theme = Theme.of(context);
    final lastRefresh = provider.lastDrinksRefresh;

    String refreshText;
    if (lastRefresh == null) {
      refreshText = 'Not yet loaded';
    } else {
      final now = DateTime.now();
      final difference = now.difference(lastRefresh);

      if (difference.inMinutes < 1) {
        refreshText = 'Just now';
      } else if (difference.inHours < 1) {
        refreshText = '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else if (difference.inDays < 1) {
        refreshText = '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else {
        refreshText = DateFormat('MMM d, yyyy \'at\' h:mm a').format(lastRefresh);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Data', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Last Updated',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        refreshText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Current Festival',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          provider.currentFestival.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Drinks',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${provider.allDrinks.length}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSettings(BuildContext context, BeerProvider provider) {
    final theme = Theme.of(context);
    final themeMode = provider.themeMode;

    String themeLabel;
    IconData themeIcon;

    switch (themeMode) {
      case ThemeMode.light:
        themeLabel = 'Light';
        themeIcon = Icons.light_mode;
      case ThemeMode.dark:
        themeLabel = 'Dark';
        themeIcon = Icons.dark_mode;
      case ThemeMode.system:
        themeLabel = 'System';
        themeIcon = Icons.brightness_auto;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Semantics(
            label: 'Change theme, currently $themeLabel mode',
            hint: 'Double tap to change theme',
            button: true,
            child: Card(
              child: ListTile(
                leading: Icon(themeIcon),
                title: const Text('Theme'),
                subtitle: Text('$themeLabel mode'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemeSelector(context, provider),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLinks(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Links', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Semantics(
            label: 'View source code on GitHub',
            hint: 'Double tap to open GitHub repository in browser',
            button: true,
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Source Code'),
                subtitle: const Text('View on GitHub'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _openGitHub(context),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Report an issue on GitHub',
            hint: 'Double tap to open GitHub issues page in browser',
            button: true,
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.bug_report),
                title: const Text('Report an Issue'),
                subtitle: const Text('Found a bug? Let us know'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _openIssues(context),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLegalInfo(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Legal', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Semantics(
            label: 'View open source licenses',
            hint: 'Double tap to view software licenses',
            button: true,
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Open Source Licenses'),
                subtitle: const Text('View licenses for dependencies'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLicensePage(context),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This app is provided as-is for informational purposes. '
            'Drink data is sourced from the Cambridge Beer Festival. '
            'Please drink responsibly.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _openGitHub(BuildContext context) async {
    final url = Uri.parse(githubUrl);

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open GitHub')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error opening GitHub')),
        );
      }
    }
  }

  void _openIssues(BuildContext context) async {
    final url = Uri.parse('$githubUrl/issues');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open GitHub Issues')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error opening GitHub Issues')),
        );
      }
    }
  }

  void _showLicensePage(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: _AboutScreenState.appName,
      applicationVersion: '$appVersion ($buildNumber)',
      applicationIcon: const Icon(Icons.local_drink, size: 48),
    );
  }

  void _showThemeSelector(BuildContext context, BeerProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _ThemeSelectorSheet(provider: provider),
    );
  }
}

/// Theme selector bottom sheet
class _ThemeSelectorSheet extends StatelessWidget {
  final BeerProvider provider;

  const _ThemeSelectorSheet({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Theme', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          RadioGroup<ThemeMode>(
            groupValue: provider.themeMode,
            onChanged: (value) {
              if (value != null) {
                provider.setThemeMode(value);
                Navigator.pop(context);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Radio<ThemeMode>(value: ThemeMode.system),
                  title: const Text('System'),
                  subtitle: const Text('Follow device settings'),
                  trailing: const Icon(Icons.brightness_auto),
                  onTap: () {
                    provider.setThemeMode(ThemeMode.system);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Radio<ThemeMode>(value: ThemeMode.light),
                  title: const Text('Light'),
                  subtitle: const Text('Always use light theme'),
                  trailing: const Icon(Icons.light_mode),
                  onTap: () {
                    provider.setThemeMode(ThemeMode.light);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Radio<ThemeMode>(value: ThemeMode.dark),
                  title: const Text('Dark'),
                  subtitle: const Text('Always use dark theme'),
                  trailing: const Icon(Icons.dark_mode),
                  onTap: () {
                    provider.setThemeMode(ThemeMode.dark);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
