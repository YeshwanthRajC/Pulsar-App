import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class AlarmTutorialDialog extends StatelessWidget {
  const AlarmTutorialDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isDark ? AppColors.nebulaNavy : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? AppColors.pulsarCyan.withValues(alpha: 0.4) : AppColors.lightCyan,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with glowing icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.pulsarCyan.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.alarm_on_rounded,
                    color: AppColors.pulsarCyan,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Alarm Controls',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.starlightWhite : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Swipe Right instruction card
            _buildActionCard(
              isDark: isDark,
              icon: Icons.swipe_right_rounded,
              iconColor: isDark ? AppColors.pulsarCyan : AppColors.lightCyan,
              title: 'Swipe Right 👉 Dismiss & Done',
              description: 'Silences the alarm and marks your task as completed.',
            ),

            const SizedBox(height: 10),

            // Swipe Left instruction card
            _buildActionCard(
              isDark: isDark,
              icon: Icons.swipe_left_rounded,
              iconColor: AppColors.warningOrange,
              title: 'Swipe Left 👈 Snooze',
              description: 'Silences the alarm and automatically alerts you again after your chosen snooze time.',
            ),

            const SizedBox(height: 14),

            // Pro Tip Box for Settings Customization
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: AppColors.pulsarCyan,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.moonlightGrey : AppColors.lightTextSecondary,
                          height: 1.35,
                        ),
                        children: [
                          TextSpan(
                            text: 'Customization Tip: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.starlightWhite : AppColors.lightTextPrimary,
                            ),
                          ),
                          const TextSpan(
                            text: 'You can adjust your Ring Duration (3–15 min) and Snooze Time (5–30 min) anytime in ',
                          ),
                          TextSpan(
                            text: 'Settings → Alarm',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.pulsarCyan : AppColors.lightCyan,
                            ),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Got It primary button
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.pulsarCyan : AppColors.lightCyan,
                foregroundColor: isDark ? AppColors.cosmicBlack : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Got It',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: isDark ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.starlightWhite : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.moonlightGrey : AppColors.lightTextSecondary,
                    height: 1.3,
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
