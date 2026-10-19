import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../providers/task_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../ai/cactus_config.dart';
import '../../ai/cactus_service.dart' show ModelStatus;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _confirmEraseAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Erase All Data?'),
        content: const Text(
          'This will permanently delete all tasks and reset the application to its default state. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Erase Everything',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<TaskProvider>().clearAllTasks();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All local task data has been erased.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Section: Appearance
          Text(
            'Appearance',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.moonlightGrey
                  : AppColors.lightTextSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.nebulaNavy : AppColors.lightCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? AppColors.nebulaNavyBorder
                    : AppColors.lightBorder,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: SwitchListTile(
                secondary: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: isDark ? AppColors.pulsarCyan : AppColors.lightCyan,
                ),
                title: Text(
                  'Light Mode',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.starlightWhite
                        : AppColors.lightTextPrimary,
                  ),
                ),
                subtitle: Text(
                  'Switch to light theme',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.moonlightGrey
                        : AppColors.lightTextSecondary,
                  ),
                ),
                value: !isDark,
                onChanged: (isLight) {
                  themeProvider.setDarkMode(!isLight);
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Section: On-Device AI Models
          Text(
            'Cactus On-Device AI',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.moonlightGrey
                  : AppColors.lightTextSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.nebulaNavy : AppColors.lightCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? AppColors.nebulaNavyBorder
                    : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.psychology_outlined,
                      color: AppColors.nebulaViolet,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'AI Engine Status',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.starlightWhite
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const Spacer(),
                    Builder(
                      builder: (context) {
                        final status = context
                            .read<TaskProvider>()
                            .cactusService
                            .modelStatus;
                        final running = status == ModelStatus.ready;
                        final label = switch (status) {
                          ModelStatus.ready => 'On-device',
                          ModelStatus.partial => 'Partial',
                          ModelStatus.loading => 'Loading',
                          ModelStatus.unavailable => 'Fallback rules',
                        };
                        final color = running
                            ? AppColors.successGreen
                            : AppColors.warningOrange;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  CactusConfig.whistleDescription,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.moonlightGrey
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  CactusConfig.needleDescription,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.moonlightGrey
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.verified_outlined, size: 16),
                        label: const Text(
                          'Verify Bundled Models (Offline APK)',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? AppColors.pulsarCyan
                              : AppColors.lightCyan,
                          side: BorderSide(
                            color: isDark
                                ? AppColors.pulsarCyan
                                : AppColors.lightCyan,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final provider = context.read<TaskProvider>();
                          final diagnostics = await provider.cactusService
                              .getModelDiagnostics();
                          if (!context.mounted) return;

                          final hasWhistle =
                              diagnostics['whistleRunning'] as bool? ?? false;
                          final hasNeedle =
                              diagnostics['needleRunning'] as bool? ?? false;
                          final engineError = diagnostics['error'] as String?;
                          final whistleMb =
                              ((diagnostics['whistleSize'] as int? ?? 0) /
                                      (1024 * 1024))
                                  .toStringAsFixed(1);
                          final needleMb =
                              ((diagnostics['needleSize'] as int? ?? 0) /
                                      (1024 * 1024))
                                  .toStringAsFixed(1);

                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: isDark
                                  ? AppColors.nebulaNavy
                                  : AppColors.lightCard,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: Row(
                                children: [
                                  Icon(
                                    Icons.offline_bolt,
                                    color: AppColors.pulsarCyan,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'On-Device AI Status',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? AppColors.starlightWhite
                                          : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Both models are bundled in the app and run on this phone. No server, no internet, no external API:',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? AppColors.starlightWhite.withValues(
                                              alpha: 0.9,
                                            )
                                          : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildModelRow(
                                    'whistle.cact (Speech-to-Text)',
                                    hasWhistle
                                        ? '$whistleMb MB, running on-device'
                                        : 'Not running on this device',
                                    hasWhistle,
                                    isDark,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildModelRow(
                                    'needle.cact (Tool Calling)',
                                    hasNeedle
                                        ? '$needleMb MB, running on-device'
                                        : 'Not running: basic keyword rules in use',
                                    hasNeedle,
                                    isDark,
                                  ),
                                  if (engineError != null) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      engineError,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.warningOrange,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text(
                                    'Close',
                                    style: TextStyle(
                                      color: AppColors.pulsarCyan,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section: Data & Privacy
          Text(
            'Data Management',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.moonlightGrey
                  : AppColors.lightTextSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.nebulaNavy : AppColors.lightCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? AppColors.nebulaNavyBorder
                    : AppColors.lightBorder,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.errorRed,
                ),
                title: const Text(
                  'Erase All Data',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.errorRed,
                  ),
                ),
                subtitle: Text(
                  'Delete all tasks and reset the app',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.moonlightGrey
                        : AppColors.lightTextSecondary,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppColors.errorRed,
                ),
                onTap: () => _confirmEraseAll(context),
              ),
            ),
          ),

          const SizedBox(height: 36),

          // Footer info
          Center(
            child: Column(
              children: [
                Text(
                  'Pulsar',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.starlightWhite
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Offline-First • Privacy Preserved',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.moonlightGrey
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildModelRow(
    String title,
    String subtitle,
    bool isReady,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cosmicBlack.withValues(alpha: 0.5)
            : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isReady
              ? AppColors.successGreen.withValues(alpha: 0.3)
              : (isDark ? AppColors.nebulaNavyBorder : AppColors.lightBorder),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isReady ? Icons.check_circle : Icons.info_outline,
            size: 18,
            color: isReady ? AppColors.successGreen : AppColors.pulsarCyan,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.starlightWhite
                        : AppColors.lightTextPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.moonlightGrey
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
