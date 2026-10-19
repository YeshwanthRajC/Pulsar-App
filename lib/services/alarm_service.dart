import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:alarm/alarm.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/task_model.dart';

class AlarmService {
  static final AlarmService instance = AlarmService._init();
  bool _initialized = false;
  bool _enabled = true;

  StreamSubscription? _ringSubscription;
  final ValueNotifier<AlarmSettings?> ringingAlarmNotifier =
      ValueNotifier<AlarmSettings?>(null);

  AlarmService._init();

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
      _initialized = true;

      // Listen to ringing alarms
      _ringSubscription?.cancel();
      _ringSubscription = Alarm.ringing.listen((alarmSet) {
        if (alarmSet.alarms.isNotEmpty) {
          final settings = alarmSet.alarms.first;
          debugPrint('[AlarmService] Alarm ringing: ${settings.id} - ${settings.notificationSettings.title}');
          ringingAlarmNotifier.value = settings;
        } else {
          ringingAlarmNotifier.value = null;
        }
      });

      debugPrint('[AlarmService] Alarm engine initialized successfully');
    } catch (e) {
      debugPrint('[AlarmService] Initialization failed (platform might not support alarm): $e');
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
        debugPrint('[AlarmService] Alarm time ${task.dueTime} is in past, skipping');
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
          body: 'Pulsar Alarm • Tap to dismiss or snooze',
          stopButton: 'Dismiss',
          androidSnoozeButton: 'Snooze 10m',
        ),
        androidFullScreenIntent: true,
        warningNotificationOnKill: true,
      );

      await Alarm.set(alarmSettings: alarmSettings);
      debugPrint('[AlarmService] Scheduled alarm #${task.id} for $alarmDateTime');
    } catch (e) {
      debugPrint('[AlarmService] Failed to schedule alarm for task #${task.id}: $e');
    }
  }

  /// Cancels an active or scheduled alarm for a task.
  Future<void> cancelTaskAlarm(int taskId) async {
    if (!_initialized || kIsWeb) return;
    try {
      await Alarm.stop(taskId);
      if (ringingAlarmNotifier.value?.id == taskId) {
        ringingAlarmNotifier.value = null;
      }
      debugPrint('[AlarmService] Cancelled alarm for task #$taskId');
    } catch (e) {
      debugPrint('[AlarmService] Error cancelling alarm #$taskId: $e');
    }
  }

  /// Snoozes an active alarm for [minutes] minutes.
  Future<void> snoozeAlarm(int taskId, {int minutes = 10, String? title}) async {
    if (!_initialized || kIsWeb) return;
    try {
      await Alarm.stop(taskId);
      if (ringingAlarmNotifier.value?.id == taskId) {
        ringingAlarmNotifier.value = null;
      }

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
          body: 'Pulsar Alarm • Due now',
          stopButton: 'Dismiss',
          androidSnoozeButton: 'Snooze 10m',
        ),
        androidFullScreenIntent: true,
        warningNotificationOnKill: true,
      );

      await Alarm.set(alarmSettings: alarmSettings);
      debugPrint('[AlarmService] Snoozed alarm #$taskId to $snoozeTime');
    } catch (e) {
      debugPrint('[AlarmService] Error snoozing alarm #$taskId: $e');
    }
  }

  /// Stops an actively ringing alarm.
  Future<void> stopRingingAlarm(int taskId) async {
    await cancelTaskAlarm(taskId);
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
