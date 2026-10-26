import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../../models/task_model.dart';
import '../data/repositories/task_repository.dart';
import 'alarm_service.dart';

const String kAlarmActionDismiss = 'alarm_dismiss';
const String kAlarmActionDone = 'alarm_done';
const String kAlarmActionSnooze = 'alarm_snooze';
const int kAlarmCompanionOffset = 1000000;

/// Handles taps/actions on the alarm companion notification. Runs headless
/// (app closed) as well as in the foreground.
Future<void> handleAlarmNotificationResponse(NotificationResponse r) async {
  final payload = r.payload;
  if (payload == null || !payload.startsWith('alarm:')) return;
  final body = payload.substring(6);
  final sep = body.indexOf('|');
  final id = int.tryParse(sep == -1 ? body : body.substring(0, sep));
  final title = sep == -1 ? 'Task Alarm' : body.substring(sep + 1);
  if (id == null) return;

  final action = r.actionId;
  // Plain tap on the body just opens the app (ring screen shows automatically).
  if (action == null || action.isEmpty) return;

  await NotificationService.instance.initialize();
  await AlarmService.instance.initialize();

  if (action == kAlarmActionSnooze) {
    await AlarmService.instance.snoozeAlarm(id, title: title);
  } else {
    await AlarmService.instance.stopRingingAlarm(id);
    if (action == kAlarmActionDone) {
      try {
        await TaskRepository().toggleTask(id);
      } catch (e) {
        debugPrint('Alarm action: failed to complete task $id: $e');
      }
    }
  }
  NotificationService.instance.onExternalChange?.call();
}

@pragma('vm:entry-point')
Future<void> alarmNotificationBackgroundHandler(NotificationResponse r) =>
    handleAlarmNotificationResponse(r);

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _enabled = true;

  /// Invoked after a notification action changed task data (to refresh UI).
  VoidCallback? onExternalChange;

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
          handleAlarmNotificationResponse(response);
        },
        onDidReceiveBackgroundNotificationResponse:
            alarmNotificationBackgroundHandler,
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

  /// Schedules a companion notification at alarm time with action buttons
  /// (Dismiss & Mark Done / Dismiss / Snooze) that work without opening the app.
  Future<void> scheduleAlarmCompanion(int taskId, String title, DateTime at) async {
    if (!_initialized || kIsWeb) return;
    try {
      final snoozeMin = await AlarmService.instance.getSnoozeMinutes();
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'pulsar_alarm_actions',
          'Alarm Actions',
          channelDescription: 'Quick actions for ringing task alarms',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: false,
          autoCancel: true,
          timeoutAfter: 600000,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(kAlarmActionDone, 'Dismiss & Done',
                cancelNotification: true),
            AndroidNotificationAction(kAlarmActionDismiss, 'Dismiss',
                cancelNotification: true),
            AndroidNotificationAction(kAlarmActionSnooze, 'Snooze ${snoozeMin}m',
                cancelNotification: true),
          ],
        ),
      );
      await _notificationsPlugin.zonedSchedule(
        id: kAlarmCompanionOffset + taskId,
        title: '⏰ $title',
        body: 'Alarm ringing • choose an action',
        scheduledDate: tz.TZDateTime.from(at, tz.UTC),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'alarm:$taskId|$title',
      );
    } catch (e) {
      debugPrint('Error scheduling alarm companion: $e');
    }
  }

  Future<void> cancelAlarmCompanion(int taskId) async {
    if (!_initialized || kIsWeb) return;
    try {
      await _notificationsPlugin.cancel(id: kAlarmCompanionOffset + taskId);
    } catch (e) {
      debugPrint('Error cancelling alarm companion: $e');
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
