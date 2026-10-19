import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// Captures 16 kHz mono PCM from the microphone for Whistle (on-device STT).
/// No speech goes to any recognizer service: raw samples stay in memory and
/// are handed straight to the on-device Whistle model.
class VoiceCaptureService {
  static const int sampleRate = 16000;
  static const int maxSeconds = 30; // Whistle runs one pass up to 30 s.

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  final BytesBuilder _bytes = BytesBuilder(copy: false);
  Timer? _maxTimer;
  void Function()? _onAutoStop;

  bool _recording = false;
  bool _heardSpeech = false;
  int _silentSamples = 0;

  bool get isRecording => _recording;

  /// Returns false if the microphone is unavailable / permission denied.
  /// [onAutoStop] fires when speech ended (silence) or the max length is hit.
  Future<bool> start({required void Function() onAutoStop}) async {
    try {
      if (!await _recorder.hasPermission()) return false;
      _bytes.clear();
      _heardSpeech = false;
      _silentSamples = 0;
      _onAutoStop = onAutoStop;

      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      ));
      _recording = true;
      _sub = stream.listen(_onChunk);
      _maxTimer = Timer(const Duration(seconds: maxSeconds), _autoStop);
      return true;
    } catch (e) {
      debugPrint('Mic start error: $e');
      _recording = false;
      return false;
    }
  }

  void _onChunk(Uint8List chunk) {
    _bytes.add(chunk);

    // Lightweight voice-activity detection: stop ~1.4 s after speech ends.
    final samples = chunk.lengthInBytes ~/ 2;
    if (samples == 0) return;
    final data = chunk.buffer.asByteData(chunk.offsetInBytes, samples * 2);
    double sum = 0;
    for (var i = 0; i < samples; i++) {
      final v = data.getInt16(i * 2, Endian.little) / 32768.0;
      sum += v * v;
    }
    final rms = sum / samples;
    if (rms > 0.0004) {
      // roughly > -34 dBFS
      _heardSpeech = true;
      _silentSamples = 0;
    } else if (_heardSpeech) {
      _silentSamples += samples;
      if (_silentSamples > sampleRate * 1.4) _autoStop();
    }
  }

  void _autoStop() {
    final cb = _onAutoStop;
    _onAutoStop = null;
    cb?.call();
  }

  /// Stops recording and returns the clip as float PCM in [-1, 1]
  /// (empty when nothing speech-like was captured).
  Future<Float32List> stop() async {
    _maxTimer?.cancel();
    _onAutoStop = null;
    try {
      await _recorder.stop();
    } catch (e) {
      debugPrint('Mic stop error: $e');
    }
    await _sub?.cancel();
    _sub = null;
    _recording = false;

    final raw = _bytes.takeBytes();
    if (!_heardSpeech) return Float32List(0);
    final n = raw.lengthInBytes ~/ 2;
    final bd = raw.buffer.asByteData(raw.offsetInBytes, n * 2);
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      out[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return _conditionAudio(out);
  }

  /// Conditions audio for Whistle STT:
  /// 1. DC offset removal
  /// 2. Silence trimming (leaving small natural margins)
  /// 3. Peak normalization to optimal acoustic model range (-18 to -14 dBFS)
  Float32List _conditionAudio(Float32List samples) {
    if (samples.length < 1600) return samples;

    // 1. Remove DC offset
    double sum = 0.0;
    for (var i = 0; i < samples.length; i++) {
      sum += samples[i];
    }
    final mean = sum / samples.length;
    for (var i = 0; i < samples.length; i++) {
      samples[i] -= mean;
    }

    // 2. Trim leading and trailing silence
    const double silenceThreshold = 0.008;
    int startIdx = 0;
    for (var i = 0; i < samples.length; i++) {
      if (samples[i].abs() > silenceThreshold) {
        startIdx = (i - 1200).clamp(0, samples.length - 1);
        break;
      }
    }

    int endIdx = samples.length - 1;
    for (var i = samples.length - 1; i >= 0; i--) {
      if (samples[i].abs() > silenceThreshold) {
        endIdx = (i + 1200).clamp(0, samples.length - 1);
        break;
      }
    }

    final trimmed = (startIdx < endIdx && (endIdx - startIdx) > 1600)
        ? Float32List.sublistView(samples, startIdx, endIdx + 1)
        : samples;

    // 3. Peak Normalization: scale up quiet speech so Whistle receives optimal amplitude
    double maxAbs = 0.0;
    for (var i = 0; i < trimmed.length; i++) {
      final abs = trimmed[i].abs();
      if (abs > maxAbs) maxAbs = abs;
    }

    if (maxAbs > 0.015 && maxAbs < 0.85) {
      final gain = (0.88 / maxAbs).clamp(1.0, 4.5);
      for (var i = 0; i < trimmed.length; i++) {
        trimmed[i] = (trimmed[i] * gain).clamp(-1.0, 1.0);
      }
    }

    return trimmed;
  }

  Future<void> cancel() async {
    _maxTimer?.cancel();
    _onAutoStop = null;
    try {
      await _recorder.cancel();
    } catch (_) {}
    await _sub?.cancel();
    _sub = null;
    _recording = false;
    _bytes.clear();
  }

  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
  }
}
