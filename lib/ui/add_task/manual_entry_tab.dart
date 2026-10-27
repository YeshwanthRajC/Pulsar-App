import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_utils.dart';

class ManualEntryTab extends StatefulWidget {
  final VoidCallback onTaskSaved;

  const ManualEntryTab({super.key, required this.onTaskSaved});

  @override
  State<ManualEntryTab> createState() => _ManualEntryTabState();
}

class _ManualEntryTabState extends State<ManualEntryTab> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 18, minute: 0);
  bool _hasReminder = true;
  bool _hasAlarm = false;
  final String _selectedColor = 'cyan';

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark ? ThemeData.dark() : ThemeData.light(),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark ? ThemeData.dark() : ThemeData.light(),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
  }

  void _saveTask() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a task title.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final task = Task(
      title: title,
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      dueDate: _selectedDate,
      dueTime: _formatTimeOfDay(_selectedTime),
      hasReminder: _hasReminder,
      hasAlarm: _hasAlarm,
      accentColor: _selectedColor,
    );

    context.read<TaskProvider>().addTask(task);
    widget.onTaskSaved();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        // Title Input
        Text(
          'Title',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.starlightWhite
                : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            hintText: 'e.g. Complete assignment',
          ),
        ),

        const SizedBox(height: 18),

        // Description Input (Optional)
        Text(
          'Description (optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.starlightWhite
                : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Add more details...'),
        ),

        const SizedBox(height: 18),

        // Date Picker Tile
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
              leading: Icon(
                Icons.calendar_today_outlined,
                color: isDark ? AppColors.pulsarCyan : AppColors.lightCyan,
              ),
              title: Text(
                'Date',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.moonlightGrey
                      : AppColors.lightTextSecondary,
                ),
              ),
              subtitle: Text(
                AppDateUtils.fullDateFormat.format(_selectedDate),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.starlightWhite
                      : AppColors.lightTextPrimary,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => _pickDate(context),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Time Picker Tile
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
              leading: Icon(
                Icons.access_time_outlined,
                color: isDark ? AppColors.pulsarCyan : AppColors.lightCyan,
              ),
              title: Text(
                'Time',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.moonlightGrey
                      : AppColors.lightTextSecondary,
                ),
              ),
              subtitle: Text(
                _formatTimeOfDay(_selectedTime),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.starlightWhite
                      : AppColors.lightTextPrimary,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => _pickTime(context),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Reminder Toggle Switch
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.nebulaNavy : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hasReminder
                  ? (isDark ? AppColors.pulsarCyan : AppColors.lightCyan)
                  : (isDark
                        ? AppColors.nebulaNavyBorder
                        : AppColors.lightBorder),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: SwitchListTile(
              secondary: Icon(
                Icons.notifications_outlined,
                color: _hasReminder
                    ? (isDark ? AppColors.pulsarCyan : AppColors.lightCyan)
                    : (isDark
                          ? AppColors.moonlightGrey
                          : AppColors.lightTextSecondary),
              ),
              title: Text(
                'Reminder',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.starlightWhite
                      : AppColors.lightTextPrimary,
                ),
              ),
              value: _hasReminder,
              onChanged: (val) {
                setState(() {
                  _hasReminder = val;
                  if (val) _hasAlarm = false;
                });
              },
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Loud Alarm Toggle Switch
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.nebulaNavy : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hasAlarm
                  ? (isDark ? AppColors.pulsarCyan : AppColors.lightCyan)
                  : (isDark
                        ? AppColors.nebulaNavyBorder
                        : AppColors.lightBorder),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: SwitchListTile(
              secondary: Icon(
                Icons.alarm_rounded,
                color: _hasAlarm
                    ? (isDark ? AppColors.pulsarCyan : AppColors.lightCyan)
                    : (isDark
                          ? AppColors.moonlightGrey
                          : AppColors.lightTextSecondary),
              ),
              title: Text(
                'Alarm',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.starlightWhite
                      : AppColors.lightTextPrimary,
                ),
              ),
              subtitle: Text(
                'Rings loud alarm when due',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.moonlightGrey
                      : AppColors.lightTextSecondary,
                ),
              ),
              value: _hasAlarm,
              onChanged: (val) {
                setState(() {
                  _hasAlarm = val;
                  if (val) _hasReminder = false;
                });
              },
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Tooltip / Explanatory hint below options
        Tooltip(
          message: 'Select either Reminder or Alarm. Both the options will provide a reminder/alert for your task.',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: isDark
                      ? AppColors.moonlightGrey
                      : AppColors.lightTextSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Select either Reminder or Alarm. Both the options will provide a reminder/alert for your task.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.moonlightGrey
                          : AppColors.lightTextSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Save Task Primary Cyan Button
        ElevatedButton(
          onPressed: _saveTask,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark
                ? AppColors.pulsarCyan
                : AppColors.lightCyan,
            foregroundColor: isDark ? AppColors.cosmicBlack : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Save Task',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }
}
