import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../calendar/calendar_view.dart';
import '../add_task/add_task_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  void _openAddTask(BuildContext context, {int initialTab = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(initialTabIndex: initialTab),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: const CalendarView(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cosmicBlack : AppColors.lightCard,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.nebulaNavyBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _openAddTask(context, initialTab: 0),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          isDark ? AppColors.pulsarCyan : AppColors.lightCyan,
                          isDark ? AppColors.pulsarCyanDark : const Color(0xFF0284C7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isDark ? AppColors.pulsarCyan : AppColors.lightCyan)
                              .withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.add,
                      size: 28,
                      color: isDark ? AppColors.cosmicBlack : Colors.white,
                    ),
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
