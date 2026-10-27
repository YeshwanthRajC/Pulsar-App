import 'package:flutter/services.dart';

class AppControl {
  static const MethodChannel _channel =
      MethodChannel('com.pulsar.voicetask/app_control');

  /// Closes the application immediately, moving the task to the back and finishing
  /// the activity so the user returns to their previous screen / launcher without
  /// opening or diverting into the main app.
  static Future<void> closeApp() async {
    try {
      await _channel.invokeMethod('closeApp');
    } catch (_) {
      await SystemNavigator.pop();
    }
  }
}
