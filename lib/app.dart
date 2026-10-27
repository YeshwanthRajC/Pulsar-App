import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/task_provider.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'services/alarm_service.dart';
import 'services/notification_service.dart';
import 'ui/alarm/alarm_ring_screen.dart';
import 'ui/home/home_screen.dart';

class PulsarApp extends StatefulWidget {
  const PulsarApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<PulsarApp> createState() => _PulsarAppState();
}

class _PulsarAppState extends State<PulsarApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AlarmService.instance.appInForeground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    AlarmService.instance.syncRingingState();
    NotificationService.instance.onExternalChange = () {
      final ctx = PulsarApp.navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ctx.read<TaskProvider>().refreshTasks();
      }
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.instance.onExternalChange = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AlarmService.instance.appInForeground = (state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) {
      // Alarm may have started/been dismissed (e.g. via notification) while away.
      AlarmService.instance.syncRingingState();
      NotificationService.instance.onExternalChange?.call();
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
      // While an alarm rings, the ring screen takes over the whole app; the
      // normal UI is only reachable after dismiss / snooze.
      builder: (context, child) {
        return ValueListenableBuilder<AlarmSettings?>(
          valueListenable: AlarmService.instance.ringingAlarmNotifier,
          builder: (context, ringing, _) {
            final showHome = child ?? const SizedBox.shrink();
            return Stack(
              children: [
                if (!AlarmService.instance.openedForAlarm)
                  showHome
                else
                  const ColoredBox(color: AppColors.cosmicBlack),
                if (ringing != null)
                  Positioned.fill(
                    child: AlarmRingScreen(
                      key: ValueKey(ringing.id),
                      alarmSettings: ringing,
                      onDismissAndComplete: () async {
                        await context.read<TaskProvider>().toggleTask(ringing.id);
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
