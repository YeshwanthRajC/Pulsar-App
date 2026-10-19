import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/task_provider.dart';
import 'services/alarm_service.dart';
import 'ui/alarm/alarm_ring_screen.dart';
import 'ui/home/home_screen.dart';

class PulsarApp extends StatefulWidget {
  const PulsarApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<PulsarApp> createState() => _PulsarAppState();
}

class _PulsarAppState extends State<PulsarApp> {
  @override
  void initState() {
    super.initState();
    AlarmService.instance.ringingAlarmNotifier.addListener(_onAlarmRinging);
  }

  @override
  void dispose() {
    AlarmService.instance.ringingAlarmNotifier.removeListener(_onAlarmRinging);
    super.dispose();
  }

  void _onAlarmRinging() {
    final ringing = AlarmService.instance.ringingAlarmNotifier.value;
    if (ringing != null) {
      final navContext = PulsarApp.navigatorKey.currentContext;
      if (navContext != null) {
        Navigator.of(navContext).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => AlarmRingScreen(
              alarmSettings: ringing,
              onDismissAndComplete: () {
                navContext.read<TaskProvider>().toggleTask(ringing.id);
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      navigatorKey: PulsarApp.navigatorKey,
      title: 'Pulsar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const HomeScreen(),
    );
  }
}
