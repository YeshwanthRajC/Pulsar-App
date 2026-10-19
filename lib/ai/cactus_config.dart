/// Configuration for the bundled on-device AI models.
/// - Cactus Whistle: 16.9 MB speech-to-text (7 languages), runs on CPU.
/// - Cactus Needle: compact tool-calling model that picks the app action.
/// Both are packaged inside the APK and run through the Cactus engine
/// (libneedle.a) over FFI. There are no download URLs on purpose: the app never
/// fetches a model and never touches the network for AI.
class CactusConfig {
  /// Bundled asset paths (inside the APK)
  static const String whistleAssetPath = 'assets/models/whistle.cact';
  static const String needleAssetPath = 'assets/models/needle.cact';

  /// On-device filenames (the engine memory-maps these)
  static const String whistleFilename = 'whistle.cact';
  static const String needleFilename = 'needle.cact';

  /// Model metadata
  static const String whistleDescription =
      'Cactus Whistle • speech-to-text • 16.9 MB • runs on-device (CPU)';
  static const String needleDescription =
      'Cactus Needle • tool-calling model • picks the task action from your words';
}
