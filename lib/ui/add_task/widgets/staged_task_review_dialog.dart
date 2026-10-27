import 'package:flutter/material.dart';

import '../../../models/task_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart';

class StagedTaskReviewDialog extends StatefulWidget {
  final List<Task> tasks;
  final Function(int index, Task updatedTask)? onTaskUpdated;
  final Function(int index)? onTaskRemoved;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const StagedTaskReviewDialog({
    super.key,
    required this.tasks,
    this.onTaskUpdated,
    this.onTaskRemoved,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<StagedTaskReviewDialog> createState() => _StagedTaskReviewDialogState();
}

class _StagedTaskReviewDialogState extends State<StagedTaskReviewDialog> {
  List<Task> _editableTasks = [];
  List<TextEditingController> _titleControllers = [];

  @override
  void initState() {
    super.initState();
    _syncTasksFromWidget();
  }

  @override
  void didUpdateWidget(covariant StagedTaskReviewDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tasks != widget.tasks) {
      _syncTasksFromWidget();
    }
  }

  void _syncTasksFromWidget() {
    for (final controller in _titleControllers) {
      controller.dispose();
    }
    _editableTasks = List<Task>.from(widget.tasks);
    _titleControllers = _editableTasks
        .map((t) => TextEditingController(text: t.title))
        .toList();
  }

  @override
  void dispose() {
    for (final controller in _titleControllers) {
      controller.dispose();
    }
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

  void _updateTask(int index, Task updated) {
    setState(() {
      _editableTasks[index] = updated;
    });
    widget.onTaskUpdated?.call(index, updated);
  }

  Future<void> _pickTime(int index, BuildContext context) async {
    final current = _editableTasks[index];
    TimeOfDay initial = const TimeOfDay(hour: 19, minute: 0); // 7:00 PM default
    if (current.dueTime != null) {
      final parsed = _parseTimeOfDay(current.dueTime!);
      if (parsed != null) initial = parsed;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
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
      _updateTask(
        index,
        current.copyWith(dueTime: formatted, hasReminder: !current.hasAlarm),
      );
    }
  }

  Future<void> _pickDate(int index, BuildContext context) async {
    final current = _editableTasks[index];
    final now = DateTime.now();
    final initial = current.dueDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
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
      _updateTask(index, current.copyWith(dueDate: picked));
    }
  }

  void _quickSetTime(int index, String? timeStr) {
    final current = _editableTasks[index];
    if (timeStr == null) {
      _updateTask(index, current.copyWith(clearDueTime: true));
    } else {
      _updateTask(
        index,
        current.copyWith(dueTime: timeStr, hasReminder: !current.hasAlarm),
      );
    }
  }

  void _quickSetDate(int index, DateTime? date) {
    final current = _editableTasks[index];
    if (date == null) {
      _updateTask(index, current.copyWith(clearDueDate: true));
    } else {
      _updateTask(index, current.copyWith(dueDate: date));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.nebulaNavy : AppColors.lightCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.pulsarCyan.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.pulsarCyan.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.pulsarCyan.withValues(alpha: 0.2),
                  AppColors.nebulaViolet.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.pulsarCyan.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: AppColors.pulsarCyan,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  _editableTasks.length > 1
                      ? '${_editableTasks.length} TASKS DRAFTED'
                      : 'TASK DRAFT READY',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.pulsarCyan,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Text(
            'Confirm & Update Task Details',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.starlightWhite
                  : AppColors.lightTextPrimary,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Review AI suggestions below. Tap any field to modify before saving.',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.moonlightGrey
                  : AppColors.lightTextSecondary,
            ),
          ),

          const SizedBox(height: 16),

          // Render each staged task as an editable card
          for (int i = 0; i < _editableTasks.length; i++)
            _buildEditableTaskCard(i, isDark),

          const SizedBox(height: 16),

          // Action Buttons: Discard Draft / Confirm & Save
          Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close, size: 16),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Discard'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? AppColors.moonlightGrey
                        : AppColors.lightTextSecondary,
                    side: BorderSide(
                      color: isDark
                          ? AppColors.nebulaNavyBorder
                          : AppColors.lightBorder,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.pulsarCyan, AppColors.pulsarCyanDark],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.pulsarCyan.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Apply title controller contents before saving
                      for (int idx = 0; idx < _editableTasks.length; idx++) {
                        final updatedTitle = _titleControllers[idx].text.trim();
                        if (updatedTitle.isNotEmpty) {
                          _updateTask(
                            idx,
                            _editableTasks[idx].copyWith(title: updatedTitle),
                          );
                        }
                      }
                      widget.onConfirm();
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _editableTasks.length > 1
                            ? 'Confirm & Save All (${_editableTasks.length})'
                            : 'Confirm & Save Task',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: AppColors.cosmicBlack,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 8,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditableTaskCard(int index, bool isDark) {
    final task = _editableTasks[index];
    final titleController = _titleControllers[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: Indicator & Title Input & Optional Delete
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: titleController,
                  onChanged: (newTitle) {
                    _updateTask(
                      index,
                      task.copyWith(
                        title: newTitle.trim().isEmpty ? task.title : newTitle,
                      ),
                    );
                  },
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.starlightWhite
                        : AppColors.lightTextPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    hintText: 'Task Title',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppColors.pulsarCyan,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              if (_editableTasks.length > 1) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppColors.errorRed,
                  ),
                  tooltip: 'Remove Task Draft',
                  onPressed: () {
                    if (widget.onTaskRemoved != null) {
                      widget.onTaskRemoved!(index);
                    } else {
                      setState(() {
                        _editableTasks.removeAt(index);
                        _titleControllers.removeAt(index);
                      });
                    }
                  },
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // Date & Time Interactive Selector
          Row(
            children: [
              // Date Chip
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(index, context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: task.dueDate != null
                            ? AppColors.pulsarCyan.withValues(alpha: 0.5)
                            : (isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: task.dueDate != null
                              ? AppColors.pulsarCyan
                              : (isDark
                                    ? AppColors.moonlightGrey
                                    : AppColors.lightTextSecondary),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            task.dueDate != null
                                ? AppDateUtils.shortDateFormat.format(
                                    task.dueDate!,
                                  )
                                : 'No date',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: task.dueDate != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isDark
                                  ? AppColors.starlightWhite
                                  : AppColors.lightTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 16,
                          color: isDark
                              ? AppColors.moonlightGrey
                              : AppColors.lightTextSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Time Chip (Editable: User can easily change 7:00 PM to 9:00 PM)
              Expanded(
                child: InkWell(
                  onTap: () => _pickTime(index, context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: task.dueTime != null
                            ? AppColors.pulsarCyan.withValues(alpha: 0.5)
                            : (isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: task.dueTime != null
                              ? AppColors.pulsarCyan
                              : (isDark
                                    ? AppColors.moonlightGrey
                                    : AppColors.lightTextSecondary),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            task.dueTime ?? 'Set time',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: task.dueTime != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isDark
                                  ? AppColors.starlightWhite
                                  : AppColors.lightTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 16,
                          color: isDark
                              ? AppColors.moonlightGrey
                              : AppColors.lightTextSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Quick Time & Date Adjustment Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Quick Date Shortcuts
              _buildSmallChip(
                label: 'Today',
                isSelected:
                    task.dueDate != null &&
                    AppDateUtils.isSameDay(task.dueDate!, DateTime.now()),
                onTap: () => _quickSetDate(index, DateTime.now()),
                isDark: isDark,
              ),
              _buildSmallChip(
                label: 'Tomorrow',
                isSelected:
                    task.dueDate != null &&
                    AppDateUtils.isSameDay(
                      task.dueDate!,
                      DateTime.now().add(const Duration(days: 1)),
                    ),
                onTap: () => _quickSetDate(
                  index,
                  DateTime.now().add(const Duration(days: 1)),
                ),
                isDark: isDark,
              ),
              // Quick Time Shortcuts - e.g. change 7:00 PM to 9:00 PM or custom hours
              _buildSmallChip(
                label: '9:00 PM',
                isSelected: task.dueTime == '9:00 PM',
                onTap: () => _quickSetTime(index, '9:00 PM'),
                isDark: isDark,
                accentColor: AppColors.pulsarCyan,
              ),
              _buildSmallChip(
                label: '7:00 PM',
                isSelected: task.dueTime == '7:00 PM',
                onTap: () => _quickSetTime(index, '7:00 PM'),
                isDark: isDark,
              ),
              _buildSmallChip(
                label: '6:00 PM',
                isSelected: task.dueTime == '6:00 PM',
                onTap: () => _quickSetTime(index, '6:00 PM'),
                isDark: isDark,
              ),
              _buildSmallChip(
                label: '10:00 AM',
                isSelected: task.dueTime == '10:00 AM',
                onTap: () => _quickSetTime(index, '10:00 AM'),
                isDark: isDark,
              ),
              if (task.dueTime != null)
                _buildSmallChip(
                  label: 'Clear time',
                  isSelected: false,
                  onTap: () => _quickSetTime(index, null),
                  isDark: isDark,
                  isDestructive: true,
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Reminder & Alarm Toggle Cards (Responsive, compact, no overflow, mutually exclusive)
          Row(
            children: [
              // Reminder Toggle Card
              Expanded(
                child: _buildToggleCard(
                  title: 'Reminder',
                  activeIcon: Icons.notifications_active,
                  inactiveIcon: Icons.notifications_none,
                  value: task.hasReminder,
                  activeColor: AppColors.warningOrange,
                  onChanged: (val) {
                    _updateTask(
                      index,
                      task.copyWith(
                        hasReminder: val,
                        hasAlarm: val ? false : task.hasAlarm,
                      ),
                    );
                  },
                  isDark: isDark,
                ),
              ),

              const SizedBox(width: 8),

              // Alarm Toggle Card
              Expanded(
                child: _buildToggleCard(
                  title: 'Alarm',
                  activeIcon: Icons.alarm,
                  inactiveIcon: Icons.alarm_off,
                  value: task.hasAlarm,
                  activeColor: isDark
                      ? AppColors.pulsarCyan
                      : AppColors.lightCyan,
                  onChanged: (val) {
                    _updateTask(
                      index,
                      task.copyWith(
                        hasAlarm: val,
                        hasReminder: val ? false : task.hasReminder,
                      ),
                    );
                  },
                  isDark: isDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Tooltip / Explanatory hint below options
          Tooltip(
            message: 'Select either Reminder or Alarm. Both the options will provide a reminder/alert for your task.',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 13,
                  color: isDark
                      ? AppColors.moonlightGrey
                      : AppColors.lightTextSecondary,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Select either Reminder or Alarm. Both the options will provide a reminder/alert for your task.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.moonlightGrey
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleCard({
    required String title,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          decoration: BoxDecoration(
            color: value
                ? activeColor.withValues(alpha: isDark ? 0.12 : 0.08)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: value
                  ? activeColor.withValues(alpha: 0.5)
                  : (isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
              width: value ? 1.2 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                value ? activeIcon : inactiveIcon,
                size: 15,
                color: value ? activeColor : AppColors.moonlightGrey,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: value
                        ? (isDark
                              ? AppColors.starlightWhite
                              : AppColors.lightTextPrimary)
                        : AppColors.moonlightGrey,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _buildMiniSwitch(
                value: value,
                activeColor: activeColor,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniSwitch({
    required bool value,
    required Color activeColor,
    required bool isDark,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      width: 28,
      height: 16,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: value
            ? activeColor
            : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    Color? accentColor,
    bool isDestructive = false,
  }) {
    final effectiveColor =
        accentColor ?? (isDark ? AppColors.pulsarCyan : AppColors.lightCyan);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? effectiveColor.withValues(alpha: 0.2)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? effectiveColor
                : (isDestructive
                      ? AppColors.errorRed.withValues(alpha: 0.3)
                      : (isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0))),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? effectiveColor
                : (isDestructive
                      ? AppColors.errorRed
                      : (isDark
                            ? AppColors.moonlightGrey
                            : AppColors.lightTextSecondary)),
          ),
        ),
      ),
    );
  }
}
