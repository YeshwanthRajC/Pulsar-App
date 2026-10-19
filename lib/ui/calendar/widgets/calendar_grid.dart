import 'package:flutter/material.dart';
import '../../../models/task_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart';

class CalendarGrid extends StatelessWidget {
  final DateTime currentMonth;
  final DateTime selectedDate;
  final List<Task> tasks;
  final Function(DateTime) onSelectDate;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const CalendarGrid({
    super.key,
    required this.currentMonth,
    required this.selectedDate,
    required this.tasks,
    required this.onSelectDate,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = AppDateUtils.getDaysInMonthGrid(currentMonth);
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Column(
      children: [
        // Month Navigation Header: < October 2026 >
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppDateUtils.monthYearFormat.format(currentMonth),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.starlightWhite : AppColors.lightTextPrimary,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 24),
                    color: isDark ? AppColors.moonlightGrey : AppColors.lightTextSecondary,
                    onPressed: onPreviousMonth,
                    splashRadius: 20,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 24),
                    color: isDark ? AppColors.moonlightGrey : AppColors.lightTextSecondary,
                    onPressed: onNextMonth,
                    splashRadius: 20,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Weekday Names
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekdays.map((day) {
              return SizedBox(
                width: 36,
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.moonlightGrey : AppColors.lightTextSecondary,
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Calendar Days Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.0,
          ),
          itemBuilder: (context, index) {
            final day = days[index];
            final isCurrentMonth = day.month == currentMonth.month;
            final isSelected = AppDateUtils.isSameDay(day, selectedDate);
            final dayTasks = tasks.where((t) {
              if (t.dueDate == null) return false;
              return AppDateUtils.isSameDay(t.dueDate!, day);
            }).toList();

            return GestureDetector(
              onTap: () => onSelectDate(day),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? (isDark ? AppColors.pulsarCyan : AppColors.lightCyan)
                      : Colors.transparent,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? (isDark ? AppColors.cosmicBlack : Colors.white)
                            : (!isCurrentMonth
                                ? (isDark
                                    ? AppColors.moonlightGrey.withValues(alpha: 0.35)
                                    : AppColors.lightTextSecondary.withValues(alpha: 0.35))
                                : (isDark
                                    ? AppColors.starlightWhite
                                    : AppColors.lightTextPrimary)),
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Indicator dot for tasks
                    if (dayTasks.isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? (isDark ? AppColors.cosmicBlack : Colors.white)
                                  : (dayTasks.any((t) => t.accentColor == 'violet')
                                      ? AppColors.nebulaViolet
                                      : (isDark ? AppColors.pulsarCyan : AppColors.lightCyan)),
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox(height: 4),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
