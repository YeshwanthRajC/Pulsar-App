import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _keyDarkMode = 'is_dark_mode';
  static const String _keyNotificationsEnabled = 'notifications_enabled';
  static const String _keyModelDownloaded = 'cactus_model_downloaded';
  static const String _keyBellHintShown = 'bell_hint_shown';
  static const String _keyPermissionsRequested = 'system_permissions_requested';

  static PreferencesService? _instance;
  final SharedPreferences _prefs;

  PreferencesService._(this._prefs);

  static Future<PreferencesService> getInstance() async {
    if (_instance == null) {
      final prefs = await SharedPreferences.getInstance();
      _instance = PreferencesService._(prefs);
    }
    return _instance!;
  }

  bool get isDarkMode => _prefs.getBool(_keyDarkMode) ?? true;
  Future<void> setDarkMode(bool value) async =>
      await _prefs.setBool(_keyDarkMode, value);

  bool get notificationsEnabled => _prefs.getBool(_keyNotificationsEnabled) ?? true;
  Future<void> setNotificationsEnabled(bool value) async =>
      await _prefs.setBool(_keyNotificationsEnabled, value);

  bool get isModelDownloaded => _prefs.getBool(_keyModelDownloaded) ?? false;
  Future<void> setModelDownloaded(bool value) async =>
      await _prefs.setBool(_keyModelDownloaded, value);

  bool get bellHintShown => _prefs.getBool(_keyBellHintShown) ?? false;
  Future<void> setBellHintShown(bool value) async =>
      await _prefs.setBool(_keyBellHintShown, value);

  bool get permissionsRequested => _prefs.getBool(_keyPermissionsRequested) ?? false;
  Future<void> setPermissionsRequested(bool value) async =>
      await _prefs.setBool(_keyPermissionsRequested, value);

  static const String _keyAlarmTutorialShown = 'alarm_tutorial_shown';
  bool get alarmTutorialShown => _prefs.getBool(_keyAlarmTutorialShown) ?? false;
  Future<void> setAlarmTutorialShown(bool value) async =>
      await _prefs.setBool(_keyAlarmTutorialShown, value);
}
