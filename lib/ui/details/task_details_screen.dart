import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_utils.dart';

class TaskDetailsScreen extends StatefulWidget {
  final Task task;

  const TaskDetailsScreen({super.key, required this.task});

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  late Task _currentTask;
  bool _isEditing = false;
  late TextEditingController _titleController;
  late TextEditingController _descController;
  String? _editingDueTime;
  double _sliderMinutes = 600.0; // Default 10:00 AM (10 * 60)

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task;
    _titleController = TextEditingController(text: _currentTask.title);
    _descController = TextEditingController(
      text: _currentTask.description ?? '',
    );
    _editingDueTime = _currentTask.dueTime;
    _sliderMinutes = _timeStringToMinutes(_currentTask.dueTime);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTimeOfDay(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    try {
      final parts = timeStr.trim().split(' ');
      if (parts.length == 2) {
        final timeParts = parts[0].split(':');
        int hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final period = parts[1].toUpperCase();
        if (period == 'PM' && hour < 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (_) {}
    return null;
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  double _timeStringToMinutes(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return 600.0;
    final tod = _parseTimeOfDay(timeStr);
    if (tod == null) return 600.0;
    return (tod.hour * 60 + tod.minute).toDouble();
  }

  String _minutesToTimeString(double minutes) {
    int totalMins = (minutes.round() / 15).round() * 15;
    if (totalMins >= 1440) totalMins = 1425;
    final hour24 = totalMins ~/ 60;
    final minute = totalMins % 60;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    int hour12 = hour24 % 12;
    if (hour12 == 0) hour12 = 12;
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hour12:$minuteStr $period';
  }

  Future<void> _pickTime(BuildContext context) async {
    final tod =
        _parseTimeOfDay(_editingDueTime ?? _currentTask.dueTime) ??
        const TimeOfDay(hour: 10, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: tod,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppColors.pulsarCyan,
                    surface: AppColors.nebulaNavy,
                    onSurface: AppColors.starlightWhite,
                  )
                : const ColorScheme.light(
                    primary: AppColors.lightCyan,
                    surface: Colors.white,
                    onSurface: AppColors.lightTextPrimary,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted = _formatTimeOfDay(picked);
      setState(() {
        _editingDueTime = formatted;
        _sliderMinutes = (picked.hour * 60 + picked.minute).toDouble();
      });
    }
  }

  void _saveEdits() {
    final updated = _currentTask.copyWith(
      title: _titleController.text.trim().isEmpty
          ? _currentTask.title
          : _titleController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      dueTime: _editingDueTime,
      clearDueTime: _editingDueTime == null,
    );
    setState(() {
      _currentTask = updated;
      _isEditing = false;
    });
    context.read<TaskProvider>().updateTask(updated);
  }

  void _toggleReminder(bool val) {
    final updated = _currentTask.copyWith(
      hasReminder: val,
      hasAlarm: val ? false : _currentTask.hasAlarm,
    );
    setState(() {
      _currentTask = updated;
    });
    context.read<TaskProvider>().updateTask(updated);
  }

  void _toggleAlarm(bool val) {
    final updated = _currentTask.copyWith(
      hasAlarm: val,
      hasReminder: val ? false : _currentTask.hasReminder,
    );
    setState(() {
      _currentTask = updated;
    });
    context.read<TaskProvider>().updateTask(updated);
  }

  void _toggleCompletion() {
    final updated = _currentTask.copyWith(
      isCompleted: !_currentTask.isCompleted,
      completedAt: !_currentTask.isCompleted ? DateTime.now() : null,
    );
    setState(() {
      _currentTask = updated;
    });
    context.read<TaskProvider>().updateTask(updated);
  }

  void _deleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text(
          'Are you sure you want to delete "${_currentTask.title}"?',
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
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<TaskProvider>().deleteTask(_currentTask.id!);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Widget _buildQuickTimeChip(String label, double minutes, bool isDark) {
    final isSelected = _editingDueTime == label;
    final primaryColor = isDark ? AppColors.pulsarCyan : AppColors.lightCyan;

    return InkWell(
      onTap: () {
        setState(() {
          _sliderMinutes = minutes;
          _editingDueTime = label;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.2)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? primaryColor
                : (isDark
                      ? AppColors.moonlightGrey
                      : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Task Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit_outlined),
            onPressed: () {
              if (_isEditing) {
                _saveEdits();
              } else {
                setState(() {
                  _isEditing = true;
                  _editingDueTime = _currentTask.dueTime;
                  _sliderMinutes = _timeStringToMinutes(_currentTask.dueTime);
                });
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Task Title and Status Indicator
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _toggleCompletion,
                child: Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _currentTask.getResolvedColor(),
                      width: 2.2,
                    ),
                    color: _currentTask.isCompleted
                        ? _currentTask.getResolvedColor()
                        : Colors.transparent,
                  ),
                  child: _currentTask.isCompleted
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: isDark ? AppColors.cosmicBlack : Colors.white,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _isEditing
                    ? TextField(
                        controller: _titleController,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Task Title',
                        ),
                      )
                    : Text(
                        _currentTask.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.starlightWhite
                              : AppColors.lightTextPrimary,
                          decoration: _currentTask.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Date Tile (Read-Only)
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
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  color: isDark ? AppColors.pulsarCyan : AppColors.lightCyan,
                  size: 20,
                ),
                const SizedBox(width: 14),
                Text(
                  _currentTask.dueDate != null
                      ? AppDateUtils.fullDateFormat.format(
                          _currentTask.dueDate!,
                        )
                      : 'No date specified',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.starlightWhite
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Time Tile (Editable via Slider when _isEditing is true)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.nebulaNavy : AppColors.lightCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isEditing
                    ? (isDark
                          ? AppColors.pulsarCyan.withValues(alpha: 0.6)
                          : AppColors.lightCyan.withValues(alpha: 0.6))
                    : (isDark
                          ? AppColors.nebulaNavyBorder
                          : AppColors.lightBorder),
                width: _isEditing ? 1.5 : 1.0,
              ),
              boxShadow: _isEditing
                  ? [
                      BoxShadow(
                        color:
                            (isDark
                                    ? AppColors.pulsarCyan
                                    : AppColors.lightCyan)
                                .withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: _isEditing
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Clock Icon, Label & Time Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_outlined,
                                color: isDark
                                    ? AppColors.pulsarCyan
                                    : AppColors.lightCyan,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Due Time',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.moonlightGrey
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () => _pickTime(context),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (isDark
                                            ? AppColors.pulsarCyan
                                            : AppColors.lightCyan)
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color:
                                      (isDark
                                              ? AppColors.pulsarCyan
                                              : AppColors.lightCyan)
                                          .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _editingDueTime ?? 'Set time',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? AppColors.pulsarCyan
                                          : AppColors.lightCyan,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.edit_calendar,
                                    size: 14,
                                    color: isDark
                                        ? AppColors.pulsarCyan
                                        : AppColors.lightCyan,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Time Slider (0 to 1425 minutes in 15-min increments)
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: isDark
                              ? AppColors.pulsarCyan
                              : AppColors.lightCyan,
                          inactiveTrackColor: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFE2E8F0),
                          thumbColor: isDark
                              ? AppColors.pulsarCyan
                              : AppColors.lightCyan,
                          overlayColor:
                              (isDark
                                      ? AppColors.pulsarCyan
                                      : AppColors.lightCyan)
                                  .withValues(alpha: 0.2),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 9,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 18,
                          ),
                          trackHeight: 4,
                          valueIndicatorColor: isDark
                              ? AppColors.pulsarCyan
                              : AppColors.lightCyan,
                          valueIndicatorTextStyle: TextStyle(
                            color: isDark
                                ? AppColors.cosmicBlack
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        child: Slider(
                          value: _sliderMinutes.clamp(0.0, 1425.0),
                          min: 0,
                          max: 1425,
                          divisions: 95,
                          label: _minutesToTimeString(_sliderMinutes),
                          onChanged: (val) {
                            setState(() {
                              _sliderMinutes = val;
                              _editingDueTime = _minutesToTimeString(val);
                            });
                          },
                        ),
                      ),

                      // Slider Range Labels: 12:00 AM ... 12:00 PM ... 11:45 PM
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '12:00 AM',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? AppColors.moonlightGrey
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            Text(
                              '12:00 PM',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? AppColors.moonlightGrey
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            Text(
                              '11:45 PM',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? AppColors.moonlightGrey
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Quick Time Preset Chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildQuickTimeChip('9:00 AM', 540, isDark),
                          _buildQuickTimeChip('12:00 PM', 720, isDark),
                          _buildQuickTimeChip('6:00 PM', 1080, isDark),
                          _buildQuickTimeChip('7:00 PM', 1140, isDark),
                          _buildQuickTimeChip('9:00 PM', 1260, isDark),
                          if (_editingDueTime != null)
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _editingDueTime = null;
                                  _sliderMinutes = 600;
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.errorRed.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.errorRed.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Clear time',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.errorRed,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(
                        Icons.access_time_outlined,
                        color: isDark
                            ? AppColors.pulsarCyan
                            : AppColors.lightCyan,
                        size: 20,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        _currentTask.dueTime ?? 'No time specified',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.starlightWhite
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 12),

          // Reminder Toggle Switch
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.nebulaNavy : AppColors.lightCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _currentTask.hasReminder
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
                  color: _currentTask.hasReminder
                      ? (isDark ? AppColors.pulsarCyan : AppColors.lightCyan)
                      : (isDark
                            ? AppColors.moonlightGrey
                            : AppColors.lightTextSecondary),
                  size: 20,
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
                value: _currentTask.hasReminder,
                onChanged: _toggleReminder,
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
                color: _currentTask.hasAlarm
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
                  color: _currentTask.hasAlarm
                      ? (isDark ? AppColors.pulsarCyan : AppColors.lightCyan)
                      : (isDark
                            ? AppColors.moonlightGrey
                            : AppColors.lightTextSecondary),
                  size: 20,
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
                value: _currentTask.hasAlarm,
                onChanged: _toggleAlarm,
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

          const SizedBox(height: 16),

          // Description Container
          Text(
            'Notes & Description',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.moonlightGrey
                  : AppColors.lightTextSecondary,
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
            child: _isEditing
                ? TextField(
                    controller: _descController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Add description...',
                      border: InputBorder.none,
                      filled: false,
                    ),
                  )
                : Text(
                    _currentTask.description?.isNotEmpty == true
                        ? _currentTask.description!
                        : 'No description provided for this task.',
                    style: TextStyle(
                      fontSize: 14,
                      color: _currentTask.description?.isNotEmpty == true
                          ? (isDark
                                ? AppColors.starlightWhite
                                : AppColors.lightTextPrimary)
                          : (isDark
                                ? AppColors.moonlightGrey
                                : AppColors.lightTextSecondary),
                      height: 1.4,
                    ),
                  ),
          ),

          const SizedBox(height: 36),

          // Bottom Action Buttons: Delete Task & Mark as Completed
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _deleteTask,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.errorRed,
                    size: 18,
                  ),
                  label: const Text(
                    'Delete Task',
                    style: TextStyle(
                      color: AppColors.errorRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.errorRed),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _toggleCompletion,
                  icon: Icon(
                    _currentTask.isCompleted ? Icons.undo : Icons.check,
                    size: 18,
                  ),
                  label: Text(
                    _currentTask.isCompleted
                        ? 'Mark Pending'
                        : 'Mark Completed',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? AppColors.pulsarCyan
                        : AppColors.lightCyan,
                    foregroundColor: isDark
                        ? AppColors.cosmicBlack
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
