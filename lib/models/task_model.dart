import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class Task {
  final int? id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final String? dueTime;
  final bool hasReminder;
  final bool hasAlarm;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? accentColor; // 'cyan', 'violet', 'grey'

  Task({
    this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.dueTime,
    this.hasReminder = true,
    this.hasAlarm = false,
    this.isCompleted = false,
    DateTime? createdAt,
    this.completedAt,
    this.accentColor = 'cyan',
  }) : createdAt = createdAt ?? DateTime.now();

  Task copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? dueDate,
    String? dueTime,
    bool? hasReminder,
    bool? hasAlarm,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? completedAt,
    String? accentColor,
    bool clearDueDate = false,
    bool clearDueTime = false,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      dueTime: clearDueTime ? null : (dueTime ?? this.dueTime),
      hasReminder: hasReminder ?? this.hasReminder,
      hasAlarm: hasAlarm ?? this.hasAlarm,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      accentColor: accentColor ?? this.accentColor,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'due_date': dueDate?.toIso8601String(),
      'due_time': dueTime,
      'has_reminder': hasReminder ? 1 : 0,
      'has_alarm': hasAlarm ? 1 : 0,
      'is_completed': isCompleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'accent_color': accentColor,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String?,
      dueDate: map['due_date'] != null
          ? DateTime.tryParse(map['due_date'] as String)
          : null,
      dueTime: map['due_time'] as String?,
      hasReminder: (map['has_reminder'] as int? ?? 1) == 1,
      hasAlarm: (map['has_alarm'] as int? ?? 0) == 1,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      completedAt: map['completed_at'] != null
          ? DateTime.tryParse(map['completed_at'] as String)
          : null,
      accentColor: map['accent_color'] as String? ?? 'cyan',
    );
  }

  Color getResolvedColor() {
    switch (accentColor) {
      case 'violet':
        return AppColors.nebulaViolet;
      case 'grey':
        return AppColors.moonlightGrey;
      case 'cyan':
      default:
        return AppColors.pulsarCyan;
    }
  }

  bool get isOverdue {
    if (isCompleted || dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDay = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return taskDay.isBefore(today);
  }
}
