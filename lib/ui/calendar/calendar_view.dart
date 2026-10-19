import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/pulsar_logo.dart';
import '../../core/utils/date_utils.dart';
import 'widgets/calendar_grid.dart';
import 'widgets/calendar_task_card.dart';
import 'widgets/notification_bell_button.dart';
import '../details/task_details_screen.dart';
import '../settings/settings_screen.dart';

class CalendarView extends StatelessWidget {
  const CalendarView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedDayTasks = provider.tasksForSelectedDate;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        children: [
          // Top Bar: Pulsar Logo, Brand Title, Subtitle, Bell
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const PulsarLogo(size: 32),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pulsar',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.starlightWhite : AppColors.lightTextPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'YOUR DAY, IN ORBIT.',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                          color: isDark ? AppColors.moonlightGrey : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const NotificationBellButton(),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, size: 24),
                    color: isDark ? AppColors.starlightWhite : AppColors.lightTextPrimary,
                    tooltip: 'Settings',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Calendar Grid Section Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.nebulaNavy : AppColors.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.nebulaNavyBorder : AppColors.lightBorder,
                width: 1,
              ),
            ),
            child: CalendarGrid(
              currentMonth: provider.calendarMonth,
              selectedDate: provider.selectedDate,
              tasks: provider.allTasks,
              onSelectDate: (date) => provider.selectDate(date),
              onPreviousMonth: () => provider.changeMonth(-1),
              onNextMonth: () => provider.changeMonth(1),
            ),
          ),

          const SizedBox(height: 24),

          // Selected Date Section Header: "Tue, 13 Oct 2026" - "3 tasks"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppDateUtils.fullDateFormat.format(provider.selectedDate),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.starlightWhite : AppColors.lightTextPrimary,
                ),
              ),
              Text(
                '${selectedDayTasks.where((t) => t.isCompleted).length}/${selectedDayTasks.length} done',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.moonlightGrey : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Task items for the selected day
          if (selectedDayTasks.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.bedtime_outlined,
                    size: 40,
                    color: isDark
                        ? AppColors.moonlightGrey.withValues(alpha: 0.4)
                        : AppColors.lightTextSecondary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No tasks scheduled for this date.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.moonlightGrey : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            ...selectedDayTasks.map((task) {
              return CalendarTaskCard(
                task: task,
                onToggle: () => provider.toggleTask(task.id!),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TaskDetailsScreen(task: task),
                    ),
                  );
                },
              );
            }),

          const SizedBox(height: 80), // Padding for bottom navbar & FAB
        ],
      ),
    );
  }
}
