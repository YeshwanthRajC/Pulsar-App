import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:alarm/alarm.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/task_model.dart';
import '../data/repositories/task_repository.dart';
import 'notification_service.dart';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

/// Offset for the Android AlarmManager ids used for ring-timeout events.
const int kAlarmTimeoutOffset = 2000000;

/// Runs from the OS (AlarmManager) even if the app process is dead: silences
/// an alarm that has rung for the configured duration.
@pragma('vm:entry-point')
Future<void> alarmTimeoutCallback(int id) async {
  final taskId = id - kAlarmTimeoutOffset;
  await NotificationService.instance.initialize();
  await AlarmService.instance.initialize();
  await AlarmService.instance.stopRingingAlarm(taskId);
}

class AlarmService {
  static final AlarmService instance = AlarmService._init();
  bool _initialized = false;
  bool _enabled = true;

  StreamSubscription? _ringSubscription;
  final ValueNotifier<AlarmSettings?> ringingAlarmNotifier =
      ValueNotifier<AlarmSettings?>(null);

  /// Tracks alarms stopped programmatically from within Dart (e.g. from UI buttons,
  /// timeout, or snooze) so that notification action button clicks can be distinguished
  /// and mark the task as done.
  final Set<int> _programmaticallyStoppedAlarms = {};
  final Set<int> _recentlyCompletedTaskIds = {};

  /// Flag set when the user explicitly chooses 'Dismiss without completing' in the Alarm UI.
  bool isDismissingWithoutComplete = false;

  /// True if the current alarm was entered from outside the app (e.g. from
  /// clicking the notification bar or launched while an alarm is ringing).
  bool openedForAlarm = false;

  /// Tracks whether the app was in the foreground before the current alarm started.
  bool appInForeground = false;

  AlarmService._init();

  static const String _keyTimeout = 'alarm_timeout_minutes';
  static const String _keySnooze = 'alarm_snooze_minutes';
  static const List<int> timeoutOptions = [3, 5, 10, 15];
  static const List<int> snoozeOptions = [5, 10, 15, 30];

  Timer? _autoStopTimer;

  Future<int> getTimeoutMinutes() async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    return p.getInt(_keyTimeout) ?? 5;
  }

  Future<void> setTimeoutMinutes(int minutes) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keyTimeout, minutes);
  }

  Future<int> getSnoozeMinutes() async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    return p.getInt(_keySnooze) ?? 10;
  }

  Future<void> setSnoozeMinutes(int minutes) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keySnooze, minutes);
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Registers an OS-level timer that stops the alarm [timeout] after it
  /// starts ringing, independent of whether the app process is alive.
  Future<void> _scheduleNativeTimeout(int taskId, DateTime ringTime) async {
    if (!_isAndroid) return;
    try {
      final minutes = await getTimeoutMinutes();
      await AndroidAlarmManager.oneShotAt(
        ringTime.add(Duration(minutes: minutes)),
        kAlarmTimeoutOffset + taskId,
        alarmTimeoutCallback,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
        rescheduleOnReboot: false,
      );
    } catch (e) {
      debugPrint('[AlarmService] Failed to schedule native timeout: $e');
    }
  }

  Future<void> _cancelNativeTimeout(int taskId) async {
    if (!_isAndroid) return;
    try {
      await AndroidAlarmManager.cancel(kAlarmTimeoutOffset + taskId);
    } catch (e) {
      debugPrint('[AlarmService] Failed to cancel native timeout: $e');
    }
  }

  /// Automatically silences the ringing alarm once the configured ring
  /// duration (counted from the alarm's scheduled time) has elapsed.
  Future<void> _armAutoStop(AlarmSettings settings) async {
    _autoStopTimer?.cancel();
    final timeout = Duration(minutes: await getTimeoutMinutes());
    var remaining = timeout - DateTime.now().difference(settings.dateTime);
    if (remaining.isNegative) remaining = Duration.zero;
    _autoStopTimer = Timer(remaining, () {
      debugPrint('[AlarmService] Ring timeout reached for #${settings.id}');
      _programmaticallyStoppedAlarms.add(settings.id);
      stopRingingAlarm(settings.id, markDone: false);
      Future.delayed(const Duration(milliseconds: 600), () {
        _programmaticallyStoppedAlarms.remove(settings.id);
      });
    });
  }

  Future<void> _markTaskDone(int taskId) async {
    if (_recentlyCompletedTaskIds.contains(taskId)) return;
    _recentlyCompletedTaskIds.add(taskId);
    Future.delayed(const Duration(seconds: 3), () {
      _recentlyCompletedTaskIds.remove(taskId);
    });

    try {
      final repo = TaskRepository();
      final task = await repo.getTaskById(taskId);
      if (task != null && !task.isCompleted) {
        await repo.updateTask(task.copyWith(
          isCompleted: true,
          completedAt: DateTime.now(),
        ));
        debugPrint('[AlarmService] Task #$taskId successfully marked completed.');
        NotificationService.instance.onExternalChange?.call();
      }
    } catch (e) {
      debugPrint('[AlarmService] Error marking task #$taskId done: $e');
    }
  }

  bool get isInitialized => _initialized;
  bool get enabled => _enabled;
  void setEnabled(bool value) => _enabled = value;

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      await Alarm.init();
      if (_isAndroid) {
        await AndroidAlarmManager.initialize();
      }
      _initialized = true;

      // Listen to ringing alarms
      _ringSubscription?.cancel();
      _ringSubscription = Alarm.ringing.listen((alarmSet) async {
        if (alarmSet.alarms.isNotEmpty) {
          final settings = alarmSet.alarms.first;
          debugPrint(
            '[AlarmService] Alarm ringing: ${settings.id} - ${settings.notificationSettings.title}',
          );
          if (!appInForeground) {
            openedForAlarm = true;
          }
          ringingAlarmNotifier.value = settings;
          _armAutoStop(settings);
        } else {
          _autoStopTimer?.cancel();
          final previousAlarm = ringingAlarmNotifier.value;
          ringingAlarmNotifier.value = null;

          if (previousAlarm != null) {
            final taskId = previousAlarm.id;
            if (!_programmaticallyStoppedAlarms.contains(taskId) &&
                !isDismissingWithoutComplete) {
              debugPrint(
                '[AlarmService] Alarm #$taskId stopped via notification action -> marking task done',
              );
              await _markTaskDone(taskId);
            }
          }
          isDismissingWithoutComplete = false;
        }
      });

      await syncRingingState();
      debugPrint('[AlarmService] Alarm engine initialized successfully');
    } catch (e) {
      debugPrint(
        '[AlarmService] Initialization failed (platform might not support alarm): $e',
      );
    }
  }

  /// Re-checks the native layer for a currently ringing alarm (cold start from
  /// notification tap, resume from background, etc.) and updates the notifier.
  Future<void> syncRingingState() async {
    if (!_initialized || kIsWeb) return;
    try {
      final alarms = await Alarm.getAlarms();
      AlarmSettings? ringing;
      for (final a in alarms) {
        if (await Alarm.isRinging(a.id)) {
          ringing = a;
          break;
        }
      }
      ringingAlarmNotifier.value = ringing;
      if (ringing != null) {
        if (!appInForeground) {
          openedForAlarm = true;
        }
        _armAutoStop(ringing);
      } else {
        _autoStopTimer?.cancel();
      }
    } catch (e) {
      debugPrint('[AlarmService] syncRingingState error: $e');
    }
  }

  Future<bool> checkPermissions() async {
    if (kIsWeb || !_initialized) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await Permission.scheduleExactAlarm.isGranted;
      }
      return true;
    } catch (e) {
      debugPrint('[AlarmService] Error checking alarm permissions: $e');
      return true;
    }
  }

  /// Schedules a loud, continuous alarm for a task.
  Future<void> scheduleTaskAlarm(Task task) async {
    if (!_initialized || !_enabled || task.id == null || !task.hasAlarm) return;
    if (task.dueDate == null || task.dueTime == null) return;

    try {
      final timeParts = _parseTimeParts(task.dueTime!);
      if (timeParts == null) return;

      final alarmDateTime = DateTime(
        task.dueDate!.year,
        task.dueDate!.month,
        task.dueDate!.day,
        timeParts.hour,
        timeParts.minute,
      );

      // Only schedule future alarms
      if (alarmDateTime.isBefore(DateTime.now())) {
        debugPrint(
          '[AlarmService] Alarm time ${task.dueTime} is in past, skipping',
        );
        return;
      }

      final alarmSettings = AlarmSettings(
        id: task.id!,
        dateTime: alarmDateTime,
        assetAudioPath: 'assets/audio/alarm.wav',
        loopAudio: true,
        vibrate: true,
        volumeSettings: const VolumeSettings.fixed(
          volume: 0.9,
          volumeEnforced: true,
        ),
        notificationSettings: NotificationSettings(
          title: '⏰ Alarm: ${task.title}',
          body: 'Click the notification for other options',
          stopButton: 'Dismiss',
        ),
        androidFullScreenIntent: true,
        androidStopAlarmOnTermination: false,
        warningNotificationOnKill: true,
      );

      await Alarm.set(alarmSettings: alarmSettings);
      await _scheduleNativeTimeout(task.id!, alarmDateTime);
      // Clean any old companion notification so only single alarm notification shows
      await NotificationService.instance.cancelAlarmCompanion(task.id!);
      debugPrint(
        '[AlarmService] Scheduled alarm #${task.id} for $alarmDateTime',
      );
    } catch (e) {
      debugPrint(
        '[AlarmService] Failed to schedule alarm for task #${task.id}: $e',
      );
    }
  }

  /// Cancels an active or scheduled alarm for a task.
  Future<void> cancelTaskAlarm(int taskId) async {
    if (!_initialized || kIsWeb) return;
    _programmaticallyStoppedAlarms.add(taskId);
    try {
      await Alarm.stop(taskId);
      await _cancelNativeTimeout(taskId);
      await NotificationService.instance.cancelAlarmCompanion(taskId);
      if (ringingAlarmNotifier.value?.id == taskId) {
        ringingAlarmNotifier.value = null;
      }
      debugPrint('[AlarmService] Cancelled alarm for task #$taskId');
    } catch (e) {
      debugPrint('[AlarmService] Error cancelling alarm #$taskId: $e');
    } finally {
      Future.delayed(const Duration(milliseconds: 600), () {
        _programmaticallyStoppedAlarms.remove(taskId);
      });
    }
  }

  /// Snoozes an active alarm for [minutes] minutes.
  Future<void> snoozeAlarm(int taskId, {int? minutes, String? title}) async {
    if (!_initialized || kIsWeb) return;
    _programmaticallyStoppedAlarms.add(taskId);
    try {
      await Alarm.stop(taskId);
      await _cancelNativeTimeout(taskId);
      await NotificationService.instance.cancelAlarmCompanion(taskId);
      if (ringingAlarmNotifier.value?.id == taskId) {
        ringingAlarmNotifier.value = null;
      }
      title = title
          ?.replaceFirst('⏰ Alarm: ', '')
          .replaceFirst('⏰ Snoozed: ', '');

      minutes ??= await getSnoozeMinutes();
      final snoozeTime = DateTime.now().add(Duration(minutes: minutes));
      final alarmSettings = AlarmSettings(
        id: taskId,
        dateTime: snoozeTime,
        assetAudioPath: 'assets/audio/alarm.wav',
        loopAudio: true,
        vibrate: true,
        volumeSettings: const VolumeSettings.fixed(
          volume: 0.9,
          volumeEnforced: true,
        ),
        notificationSettings: NotificationSettings(
          title: '⏰ Snoozed: ${title ?? "Task Alarm"}',
          body: 'Click the notification for other options',
          stopButton: 'Dismiss',
        ),
        androidFullScreenIntent: true,
        androidStopAlarmOnTermination: false,
        warningNotificationOnKill: true,
      );

      await Alarm.set(alarmSettings: alarmSettings);
      await _scheduleNativeTimeout(taskId, snoozeTime);
      debugPrint('[AlarmService] Snoozed alarm #$taskId to $snoozeTime');
    } catch (e) {
      debugPrint('[AlarmService] Error snoozing alarm #$taskId: $e');
    } finally {
      Future.delayed(const Duration(milliseconds: 600), () {
        _programmaticallyStoppedAlarms.remove(taskId);
      });
    }
  }

  /// Stops an actively ringing alarm.
  Future<void> stopRingingAlarm(int taskId, {bool markDone = false}) async {
    _programmaticallyStoppedAlarms.add(taskId);
    try {
      await cancelTaskAlarm(taskId);
      if (markDone) {
        await _markTaskDone(taskId);
      }
    } finally {
      Future.delayed(const Duration(milliseconds: 600), () {
        _programmaticallyStoppedAlarms.remove(taskId);
      });
    }
  }

  /// Cancels all scheduled alarms in the system.
  Future<void> cancelAll() async {
    if (!_initialized || kIsWeb) return;
    try {
      final alarms = await Alarm.getAlarms();
      for (final alarm in alarms) {
        await Alarm.stop(alarm.id);
      }
      ringingAlarmNotifier.value = null;
    } catch (e) {
      debugPrint('[AlarmService] Error cancelling all alarms: $e');
    }
  }

  void dispose() {
    _ringSubscription?.cancel();
    ringingAlarmNotifier.dispose();
  }

  ({int hour, int minute})? _parseTimeParts(String timeStr) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');

      final digitsOnly = clean.replaceAll(RegExp(r'[^0-9:]'), '');
      final parts = digitsOnly.split(':');
      if (parts.isEmpty) return null;

      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;

      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;

      return (hour: hour, minute: minute);
    } catch (e) {
      debugPrint('[AlarmService] Failed to parse time: $timeStr ($e)');
      return null;
    }
  }
}
