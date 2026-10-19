import 'dart:typed_data';

/// Result of loading the on-device models.
class NeedleLoadResult {
  final bool engineSupported;
  final bool needleLoaded;
  final bool whistleLoaded;
  final String? error;
  const NeedleLoadResult({
    required this.engineSupported,
    required this.needleLoaded,
    required this.whistleLoaded,
    this.error,
  });
}

/// Web stub for NeedleEngine.
/// The native C++ Cactus engine (libneedle.a) requires ARM64 Android.
/// On Web / browser environments, this stub safely falls back to offline rules.
class NeedleEngine {
  NeedleEngine._();
  static final NeedleEngine instance = NeedleEngine._();

  bool get needleLoaded => false;
  bool get whistleLoaded => false;

  NeedleLoadResult load({
    required String needlePath,
    required String whistlePath,
  }) {
    return const NeedleLoadResult(
      engineSupported: false,
      needleLoaded: false,
      whistleLoaded: false,
      error: 'On-device C++ engine is not available on Web (using offline rules).',
    );
  }

  Future<String> transcribe(
    Float32List pcm, {
    String? language = 'en',
    String? keywords,
  }) {
    return Future.error(
      StateError('Speech-to-text is not supported on Web. Use manual entry or type a command.'),
    );
  }

  Future<Map<String, dynamic>> complete({
    required String input,
    required String systemPrompt,
    required String toolsJson,
  }) {
    return Future.error(
      StateError('Needle native model is not available on Web.'),
    );
  }
}
