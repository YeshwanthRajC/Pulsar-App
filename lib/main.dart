import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'providers/notification_settings_provider.dart';
import 'app.dart';
import 'data/repositories/task_repository.dart';
import 'services/notification_service.dart';
import 'services/alarm_service.dart';
import 'services/preferences_service.dart';
import 'ai/cactus_service.dart';
import 'providers/theme_provider.dart';
import 'providers/task_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferencesService = await PreferencesService.getInstance();

  // Initialize Local Notifications (does not prompt)
  final notificationService = NotificationService.instance;
  await notificationService.initialize();

  // Initialize Alarm Service for loud continuous alarms
  final alarmService = AlarmService.instance;
  await alarmService.initialize();

  // System permissions (notifications, then microphone) are requested exactly once,
  // on the very first launch. The in-app bell never asks for them again.
  if (!preferencesService.permissionsRequested && !kIsWeb) {
    await notificationService.requestPermissions();
    try {
      await Permission.microphone.request();
    } catch (e) {
      debugPrint('Microphone permission request error: $e');
    }
    await preferencesService.setPermissionsRequested(true);
  }

  final taskRepository = TaskRepository();
  final cactusService = CactusService(repository: taskRepository);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<NotificationSettingsProvider>(
          create: (_) => NotificationSettingsProvider(
            prefs: preferencesService,
            repository: taskRepository,
            service: notificationService,
          ),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(preferencesService),
        ),
        ChangeNotifierProvider<TaskProvider>(
          create: (_) => TaskProvider(
            repository: taskRepository,
            cactusService: cactusService,
            notificationService: notificationService,
          ),
        ),
      ],
      child: const PulsarApp(),
    ),
  );
}
