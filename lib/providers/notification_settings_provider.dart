import 'package:flutter/material.dart';
import '../data/repositories/task_repository.dart';
import '../services/notification_service.dart';
import '../services/preferences_service.dart';

/// Drives the notification bell. This is ONLY a pause/resume switch for app
/// notifications; it never asks for any system permission.
///
/// - Paused: pending OS notifications are cancelled and new tasks do not schedule
///   one. Tasks themselves keep their reminder data.
/// - Resumed: every pending task whose reminder time is still in the future is
///   scheduled again, so a reminder that falls right after resuming still fires.
class NotificationSettingsProvider extends ChangeNotifier {
  final PreferencesService prefs;
  final NotificationService service;
  final TaskRepository repository;

  bool _enabled;

  NotificationSettingsProvider({
    required this.prefs,
    required this.service,
    required this.repository,
  }) : _enabled = prefs.notificationsEnabled {
    service.setEnabled(_enabled);
  }

  bool get enabled => _enabled;
  bool get shouldShowHint => !prefs.bellHintShown;

  Future<void> markHintShown() => prefs.setBellHintShown(true);

  /// Returns the new state.
  Future<bool> toggle() async {
    if (_enabled) {
      _enabled = false;
      service.setEnabled(false);
      await service.cancelAll();
    } else {
      _enabled = true;
      service.setEnabled(true);
      await service.rescheduleAll(await repository.getAllTasks());
    }
    await prefs.setNotificationsEnabled(_enabled);
    notifyListeners();
    return _enabled;
  }
}
