import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../../models/task_model.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _enabled = true;

  NotificationService._init();

  bool get enabled => _enabled;
  void setEnabled(bool value) => _enabled = value;

  Future<void> cancelAll() async {
    if (!_initialized || kIsWeb) return;
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Error cancelling all notifications: $e');
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      tzdata.initializeTimeZones();
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );

      _initialized = true;
      // NOTE: system permissions are intentionally NOT requested here; they are
      // requested exactly once on first launch (see main.dart).
    } catch (e) {
      debugPrint('NotificationService init error (platform may not support): $e');
    }
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          final granted = await androidImpl.requestNotificationsPermission();
          return granted ?? false;
        }
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
    return true;
  }

  Future<void> scheduleTaskReminder(Task task) async {
    if (!_initialized || !_enabled || task.id == null || !task.hasReminder) return;
    if (task.dueDate == null || task.dueTime == null) return;

    try {
      // Calculate notification time deterministically
      final timeParts = _parseTimeParts(task.dueTime!);
      if (timeParts == null) return;

      final reminderDateTime = DateTime(
        task.dueDate!.year,
        task.dueDate!.month,
        task.dueDate!.day,
        timeParts.hour,
        timeParts.minute,
      );

      // Only schedule if time is in the future
      if (reminderDateTime.isBefore(DateTime.now())) {
        debugPrint('Task reminder time is in the past, skipping schedule');
        return;
      }

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'pulsar_task_reminders',
        'Task Reminders',
        channelDescription: 'Notifications for upcoming VoiceTask AI tasks',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      final scheduled = tz.TZDateTime.from(reminderDateTime, tz.UTC);

      Future<void> schedule(AndroidScheduleMode mode) =>
          _notificationsPlugin.zonedSchedule(
            id: task.id!,
            title: task.title,
            body: 'Task due at ${task.dueTime}',
            scheduledDate: scheduled,
            notificationDetails: details,
            androidScheduleMode: mode,
            payload: task.id.toString(),
          );

      try {
        await schedule(AndroidScheduleMode.exactAllowWhileIdle);
      } catch (_) {
        // Exact alarms not permitted on this device; fall back to inexact timing.
        await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
      }

      debugPrint('Scheduled reminder for "${task.title}" at $reminderDateTime');
    } catch (e) {
      debugPrint('Error scheduling task reminder: $e');
    }
  }

  /// Called when notifications are resumed: schedules every pending task whose
  /// reminder time is still in the future (past ones are skipped automatically).
  Future<void> rescheduleAll(List<Task> tasks) async {
    for (final task in tasks) {
      if (!task.isCompleted && task.hasReminder) {
        await scheduleTaskReminder(task);
      }
    }
  }

  Future<void> cancelTaskReminder(int taskId) async {
    if (!_initialized) return;
    try {
      await _notificationsPlugin.cancel(id: taskId);
      debugPrint('Cancelled notification for task ID $taskId');
    } catch (e) {
      debugPrint('Error cancelling notification: $e');
    }
  }

  Future<void> updateTaskReminder(Task task) async {
    if (task.id == null) return;
    await cancelTaskReminder(task.id!);
    if (!task.isCompleted && task.hasReminder) {
      await scheduleTaskReminder(task);
    }
  }

  _TimeParts? _parseTimeParts(String timeStr) {
    try {
      final parsed = DateFormat('h:mm a').parse(timeStr.trim());
      return _TimeParts(parsed.hour, parsed.minute);
    } catch (_) {
      try {
        final parsed = DateFormat('H:mm').parse(timeStr.trim());
        return _TimeParts(parsed.hour, parsed.minute);
      } catch (_) {
        return null;
      }
    }
  }
}

class _TimeParts {
  final int hour;
  final int minute;
  _TimeParts(this.hour, this.minute);
}
