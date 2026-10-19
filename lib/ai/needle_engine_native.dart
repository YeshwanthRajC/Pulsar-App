import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

typedef _SupportedC = Int32 Function();
typedef _SupportedD = int Function();
typedef _LoadFileC = Int32 Function(Pointer<Utf8>);
typedef _LoadFileD = int Function(Pointer<Utf8>);
typedef _ModelsC = Int32 Function();
typedef _ModelsD = int Function();
typedef _LastErrorC = Pointer<Utf8> Function();
typedef _LastErrorD = Pointer<Utf8> Function();
typedef _InitC = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef _InitD = int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef _ResetC = Void Function();
typedef _ResetD = void Function();
typedef _CompleteC = Int32 Function(
    Pointer<Utf8>, Pointer<Float>, Int32, Int32, Pointer<Utf8>, Int32);
typedef _CompleteD = int Function(
    Pointer<Utf8>, Pointer<Float>, int, int, Pointer<Utf8>, int);
typedef _TranscribeC = Int32 Function(Pointer<Float>, Int32, Pointer<Utf8>,
    Pointer<Utf8>, Int32, Pointer<Utf8>, Int32);
typedef _TranscribeD = int Function(Pointer<Float>, int, Pointer<Utf8>,
    Pointer<Utf8>, int, Pointer<Utf8>, int);

const int _kText = 1;
const int _kSpeech = 2;
const int _kOutCapacity = 16384;

class _Bindings {
  final DynamicLibrary lib;
  late final _SupportedD supported =
      lib.lookupFunction<_SupportedC, _SupportedD>('pulsar_engine_supported');
  late final _LoadFileD loadFile =
      lib.lookupFunction<_LoadFileC, _LoadFileD>('pulsar_load_file');
  late final _ModelsD models =
      lib.lookupFunction<_ModelsC, _ModelsD>('needle_models');
  late final _LastErrorD lastError =
      lib.lookupFunction<_LastErrorC, _LastErrorD>('needle_last_error');
  late final _InitD init = lib.lookupFunction<_InitC, _InitD>('needle_init');
  late final _ResetD reset =
      lib.lookupFunction<_ResetC, _ResetD>('needle_reset');
  late final _CompleteD complete =
      lib.lookupFunction<_CompleteC, _CompleteD>('needle_complete');
  late final _TranscribeD transcribe =
      lib.lookupFunction<_TranscribeC, _TranscribeD>('needle_transcribe');

  _Bindings(this.lib);

  String errorText() {
    try {
      final p = lastError();
      return p == nullptr ? 'unknown error' : p.toDartString();
    } catch (_) {
      return 'unknown error';
    }
  }
}

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

/// Dart FFI wrapper over the official Cactus engine (libneedle.a, linked into
/// libpulsar_needle.so). Runs Whistle (speech-to-text) and Needle (tool calling)
/// fully on-device. No network access of any kind.
///
/// The engine holds one process-global, non-thread-safe model per kind, so all
/// calls are serialized and run in a short-lived isolate to keep the UI smooth.
class NeedleEngine {
  NeedleEngine._();
  static final NeedleEngine instance = NeedleEngine._();

  bool _needleLoaded = false;
  bool _whistleLoaded = false;
  Future<void> _queue = Future.value();

  bool get needleLoaded => _needleLoaded;
  bool get whistleLoaded => _whistleLoaded;

  static _Bindings? _open() {
    if (!Platform.isAndroid) return null;
    try {
      return _Bindings(DynamicLibrary.open('libpulsar_needle.so'));
    } catch (e) {
      debugPrint('libpulsar_needle.so not available: $e');
      return null;
    }
  }

  /// Loads both .cact files from disk into the engine.
  NeedleLoadResult load({
    required String needlePath,
    required String whistlePath,
  }) {
    final b = _open();
    if (b == null || b.supported() != 1) {
      return const NeedleLoadResult(
        engineSupported: false,
        needleLoaded: false,
        whistleLoaded: false,
        error: 'On-device engine is not available for this CPU architecture '
            '(it needs an ARM64 device).',
      );
    }

    String? error;
    for (final path in [needlePath, whistlePath]) {
      if (!File(path).existsSync()) {
        error = 'Model file missing: $path';
        continue;
      }
      final p = path.toNativeUtf8();
      try {
        final rc = b.loadFile(p);
        if (rc < 0) {
          error = 'Failed to load ${path.split(RegExp(r'[\\/]')).last} '
              '(code $rc): ${b.errorText()}';
        }
      } finally {
        malloc.free(p);
      }
    }

    final mask = b.models();
    _needleLoaded = (mask & _kText) != 0;
    _whistleLoaded = (mask & _kSpeech) != 0;
    return NeedleLoadResult(
      engineSupported: true,
      needleLoaded: _needleLoaded,
      whistleLoaded: _whistleLoaded,
      error: error,
    );
  }

  Future<T> _serialized<T>(Future<T> Function() job) {
    final next = _queue.then((_) => job());
    _queue = next.then((_) {}, onError: (_) {});
    return next;
  }

  /// Whistle: 16 kHz mono float PCM in [-1, 1] -> transcript text.
  /// Uses [language] ('en' by default) and [keywords] for keyword biasing.
  Future<String> transcribe(
    Float32List pcm, {
    String? language = 'en',
    String? keywords,
  }) {
    if (!_whistleLoaded) {
      return Future.error(StateError('Whistle model is not loaded'));
    }
    return _serialized(() => Isolate.run(
          () => _transcribeSync(pcm, language: language, keywords: keywords),
        ));
  }

  /// Needle: text + tool schemas -> parsed JSON response
  /// ({function_calls: [...], confidence, ...}).
  Future<Map<String, dynamic>> complete({
    required String input,
    required String systemPrompt,
    required String toolsJson,
  }) {
    if (!_needleLoaded) {
      return Future.error(StateError('Needle model is not loaded'));
    }
    return _serialized(() => Isolate.run(
        () => _completeSync(input, systemPrompt, toolsJson)));
  }
}

String _transcribeSync(
  Float32List pcm, {
  String? language,
  String? keywords,
}) {
  final b = _NeedleEngineIsolate.bindings();
  final buf = malloc<Float>(pcm.length);
  final out = malloc<Uint8>(_kOutCapacity).cast<Utf8>();
  final langPtr = language != null ? language.toNativeUtf8() : nullptr;
  final kwPtr = keywords != null ? keywords.toNativeUtf8() : nullptr;
  try {
    buf.asTypedList(pcm.length).setAll(0, pcm);
    final rc = b.transcribe(
      buf,
      pcm.length,
      langPtr,
      kwPtr,
      0,
      out,
      _kOutCapacity,
    );
    if (rc < 0) throw StateError('Whistle transcription failed: ${b.errorText()}');
    final json = jsonDecode(out.toDartString()) as Map<String, dynamic>;
    return (json['text'] as String? ?? '').trim();
  } finally {
    malloc.free(buf);
    malloc.free(out);
    if (langPtr != nullptr) malloc.free(langPtr);
    if (kwPtr != nullptr) malloc.free(kwPtr);
  }
}

Map<String, dynamic> _completeSync(
    String input, String systemPrompt, String toolsJson) {
  final b = _NeedleEngineIsolate.bindings();
  final sys = systemPrompt.toNativeUtf8();
  final tools = toolsJson.toNativeUtf8();
  final text = input.toNativeUtf8();
  final out = malloc<Uint8>(_kOutCapacity).cast<Utf8>();
  try {
    final initRc = b.init(sys, tools, nullptr);
    if (initRc < 0) throw StateError('needle_init failed: ${b.errorText()}');
    b.reset();
    final rc = b.complete(text, nullptr, 0, 192, out, _kOutCapacity);
    if (rc < 0) throw StateError('Needle completion failed: ${b.errorText()}');
    return jsonDecode(out.toDartString()) as Map<String, dynamic>;
  } finally {
    malloc.free(sys);
    malloc.free(tools);
    malloc.free(text);
    malloc.free(out);
  }
}

class _NeedleEngineIsolate {
  static _Bindings bindings() =>
      _Bindings(DynamicLibrary.open('libpulsar_needle.so'));
}
