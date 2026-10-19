import 'package:flutter/material.dart';
import '../../../models/task_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart';

class CalendarTaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const CalendarTaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dotColor = task.getResolvedColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.nebulaNavy : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.nebulaNavyBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Radio/Status indicator
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: task.isCompleted ? dotColor : dotColor.withValues(alpha: 0.8),
                        width: 2,
                      ),
                      color: task.isCompleted ? dotColor : Colors.transparent,
                    ),
                    child: task.isCompleted
                        ? Icon(
                            Icons.check,
                            size: 14,
                            color: isDark ? AppColors.cosmicBlack : Colors.white,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 14),

                // Title and Time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: task.isCompleted
                              ? (isDark ? AppColors.moonlightGrey : AppColors.lightTextSecondary)
                              : (isDark ? AppColors.starlightWhite : AppColors.lightTextPrimary),
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppDateUtils.formatTaskDateTime(task.dueDate, task.dueTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.moonlightGrey : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Alarm or Reminder bell icon
                if (task.hasAlarm)
                  Icon(
                    Icons.alarm_rounded,
                    size: 18,
                    color: isDark ? AppColors.pulsarCyan : AppColors.lightCyan,
                  )
                else if (task.hasReminder)
                  Icon(
                    Icons.notifications_outlined,
                    size: 18,
                    color: task.dueTime != null ? AppColors.warningOrange : AppColors.moonlightGrey,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
