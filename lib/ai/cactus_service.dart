import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../data/repositories/task_repository.dart';
import 'cactus_config.dart';
import 'action_router.dart';
import 'action_modules/base_action.dart';
import '../services/voice_enhancement_service.dart';
import 'needle_engine.dart';
import 'needle_intent_parser.dart';
import '../core/utils/date_utils.dart';

enum ModelStatus {
  loading,
  ready, // both on-device models are running
  partial, // one model running
  unavailable, // models could not run on this device
}

/// On-device AI pipeline (100% offline):
///   microphone PCM -> Whistle (speech-to-text) -> Needle (tool calling)
///   -> Action Router -> deterministic Action Modules.
///
/// Both models are bundled in the APK and run through the Cactus engine
/// (libneedle.a) via FFI. Nothing is downloaded and no network is used.
class CactusService {
  final TaskRepository repository;
  late final ActionRouter actionRouter;

  final NeedleEngine _engine = NeedleEngine.instance;

  ModelStatus _modelStatus = ModelStatus.loading;
  String _statusMessage = 'Loading on-device models...';
  String? _loadError;
  String? _lastNeedleNote;

  CactusService({required this.repository}) {
    actionRouter = ActionRouter(repository: repository);
  }

  ModelStatus get modelStatus => _modelStatus;
  String get statusMessage => _statusMessage;
  String? get loadError => _loadError;
  bool get isNeedleRunning => _engine.needleLoaded;
  bool get isWhistleRunning => _engine.whistleLoaded;

  /// Note about the last command (e.g. which engine decided), for diagnostics.
  String? get lastNeedleNote => _lastNeedleNote;

  /// Copies a bundled asset to app storage the first time (or when the bundled
  /// file changed size), so the engine can memory-map it.
  Future<String?> _extractBundledAsset(String assetPath, String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final target = File('${dir.path}/$fileName');
      final data = await rootBundle.load(assetPath);
      if (!await target.exists() || await target.length() != data.lengthInBytes) {
        await target.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
      }
      return target.path;
    } catch (e) {
      debugPrint('Bundled asset error ($assetPath): $e');
      return null;
    }
  }

  Future<void>? _initFuture;

  /// Extracts the bundled models and loads them into the Cactus engine.
  Future<void> initializeEngine() {
    return _initFuture ??= _doInitializeEngine();
  }

  Future<void> _doInitializeEngine() async {
    if (kIsWeb) {
      _modelStatus = ModelStatus.unavailable;
      _statusMessage = 'Web mode: using offline rules';
      return;
    }
    _modelStatus = ModelStatus.loading;
    try {
      final whistlePath = await _extractBundledAsset(
          CactusConfig.whistleAssetPath, CactusConfig.whistleFilename);
      final needlePath = await _extractBundledAsset(
          CactusConfig.needleAssetPath, CactusConfig.needleFilename);

      if (whistlePath == null || needlePath == null) {
        _modelStatus = ModelStatus.unavailable;
        _loadError = 'Bundled model files are missing from the app.';
        _statusMessage = 'On-device models missing; using basic offline rules';
        return;
      }

      final result = _engine.load(needlePath: needlePath, whistlePath: whistlePath);
      _loadError = result.error;

      if (result.needleLoaded && result.whistleLoaded) {
        _modelStatus = ModelStatus.ready;
        _statusMessage = 'Whistle + Needle running on-device (offline)';
      } else if (result.needleLoaded || result.whistleLoaded) {
        _modelStatus = ModelStatus.partial;
        _statusMessage = result.needleLoaded
            ? 'Needle running on-device; Whistle unavailable'
            : 'Whistle running on-device; Needle unavailable';
      } else {
        _modelStatus = ModelStatus.unavailable;
        _statusMessage = result.engineSupported
            ? 'Models failed to load; using basic offline rules'
            : 'On-device AI needs an ARM64 phone; using basic offline rules';
      }
      debugPrint('Cactus engine: $_statusMessage ${_loadError ?? ''}');
    } catch (e) {
      _modelStatus = ModelStatus.unavailable;
      _loadError = '$e';
      _statusMessage = 'Models failed to load; using basic offline rules';
    }
  }

  /// Diagnostics for the Settings screen.
  Future<Map<String, dynamic>> getModelDiagnostics() async {
    if (kIsWeb) {
      return {
        'whistleLocal': false,
        'whistleSize': 0,
        'needleLocal': false,
        'needleSize': 0,
        'whistleRunning': false,
        'needleRunning': false,
        'error': null,
        'statusMessage': 'Web mode: using offline rules',
      };
    }
    final dir = await getApplicationDocumentsDirectory();
    final whistleFile = File('${dir.path}/${CactusConfig.whistleFilename}');
    final needleFile = File('${dir.path}/${CactusConfig.needleFilename}');
    return {
      'whistleLocal': await whistleFile.exists(),
      'whistleSize': await whistleFile.exists() ? await whistleFile.length() : 0,
      'needleLocal': await needleFile.exists(),
      'needleSize': await needleFile.exists() ? await needleFile.length() : 0,
      'whistleRunning': isWhistleRunning,
      'needleRunning': isNeedleRunning,
      'error': _loadError,
      'statusMessage': _statusMessage,
    };
  }

  /// Whistle stage: PCM clip -> transcript, entirely on-device.
  /// Throws if Whistle is not running (caller shows a message).
  Future<String> transcribe(
    Float32List pcm, {
    String? language = 'en',
    String? keywords,
  }) async {
    if (_initFuture != null) {
      await _initFuture;
    }
    if (!_engine.whistleLoaded) {
      throw StateError(
          'Whistle speech model is not running on this device. Use manual entry or type a command.');
    }

    String effectiveKeywords = keywords ?? '';
    if (effectiveKeywords.isEmpty) {
      try {
        final existingTasks = await repository.getAllTasks();
        effectiveKeywords =
            VoiceEnhancementService.instance.buildKeywords(tasks: existingTasks);
      } catch (_) {
        effectiveKeywords = VoiceEnhancementService.instance.buildKeywords();
      }
    }

    final rawText = await _engine.transcribe(
      pcm,
      language: language,
      keywords: effectiveKeywords,
    );
    final text = VoiceEnhancementService.instance.postProcessTranscript(rawText);
    debugPrint('Whistle transcript (enhanced): "$text" (raw: "$rawText")');
    return text;
  }

  String _systemPrompt() {
    final now = DateTime.now();
    final date = DateFormat('yyyy-MM-dd EEE HH:mm').format(now);
    return 'date: $date; locale: en-IN; device: phone';
  }

  /// Needle stage: transcript text -> tool calls -> Action Modules.
  /// Needle decides which action to run; if the engine can't run on this
  /// device the built-in keyword parser is used instead (flagged in
  Future<ActionResult> processVoiceCommand(String transcribedText) async {
    final cleanInput = transcribedText.trim();
    if (cleanInput.isEmpty) {
      return ActionResult.error('Voice input was empty. Please try speaking again.');
    }

    // Conversational greetings & capability queries in chat
    final lower = cleanInput.toLowerCase();
    final isGreeting = RegExp(
      r'^(hi|hello|hey|help|who are you|what can you do|how do i use|how does this work)\b',
      caseSensitive: false,
    ).hasMatch(lower);

    if (isGreeting) {
      _lastNeedleNote = 'Pulsar On-Device AI';
      return ActionResult.clarificationNeeded(
        question: '👋 Hi! What task would you like to schedule? Try saying "Remind me to call Mom tomorrow at 7 PM" or "Submit report on Friday".',
        ambiguousField: 'title',
      );
    }

    if (_initFuture != null) {
      await _initFuture;
    }

    try {
      ToolCallRequest? request;

      if (_engine.needleLoaded) {
        final response = await _engine.complete(
          input: cleanInput,
          systemPrompt: _systemPrompt(),
          toolsJson: actionRouter.buildNeedleToolsJson(),
        );
        final calls = (response['function_calls'] as List<dynamic>?) ?? const [];
        final suppressed = (response['suppressed_calls'] as List<dynamic>?) ?? const [];
        _lastNeedleNote = 'Processed on-device with Needle AI';
        debugPrint('Needle on-device response: $response');

        request = actionRouter.requestFromNeedleCalls(calls);
        // If high-confidence calls list was empty, check if suppressed calls contain a valid action
        if (request == null && suppressed.isNotEmpty) {
          request = actionRouter.requestFromNeedleCalls(suppressed);
        }
        if (request == null) {
          // If Needle model didn't return a call, try deterministic companion parser
          final fallback = NeedleIntentParser.parse(cleanInput);
          if (fallback.actionName != 'request_clarification') {
            request = fallback;
          } else {
            return ActionResult.clarificationNeeded(
              question: suppressed.isNotEmpty
                  ? 'I am not sure what you meant by "$cleanInput". Could you rephrase it?'
                  : 'I could not find a task action in "$cleanInput". Try something like "remind me to call Mom tomorrow at 6 PM".',
              ambiguousField: 'title',
            );
          }
        }
      } else {
        _lastNeedleNote = null;
        request = NeedleIntentParser.parse(cleanInput);
      }

      // Never invent dates/times: a reminder with no when needs clarification.
      if (request.actionName == 'create_task') {
        final tasks = (request.arguments['tasks'] as List<dynamic>?) ?? const [];
        final isReminderUtterance = RegExp(
          r'\b(remind|reminder|alert|alarm|notify|wake)\b',
          caseSensitive: false,
        ).hasMatch(cleanInput);

        // Grounding with deterministic parsing from cleanInput:
        // Needle is a 35MB quantized model. If cleanInput contains an explicit,
        // unambiguous time or date, verify that single tasks are anchored to it.
        final explicitTime = AppDateUtils.parseTimeString(cleanInput);

        for (final t in tasks) {
          if (t is Map) {
            final remind = t['hasReminder'] == true || isReminderUtterance;
            if (remind) {
              t['hasReminder'] = true;
            }

            // Single task time anchoring: correct AM/PM model quantization slips
            if (tasks.length == 1 && explicitTime != null) {
              final modelTime = (t['dueTime'] ?? '').toString().trim();
              if (modelTime.isEmpty) {
                t['dueTime'] = explicitTime;
              } else {
                final modelParsed = AppDateUtils.parseTimeString(modelTime);
                if (modelParsed != null && explicitTime != modelParsed) {
                  final cleanLower = cleanInput.toLowerCase();
                  final hasAm = cleanLower.contains('am') || cleanLower.contains('morning');
                  final hasPm = cleanLower.contains('pm') || cleanLower.contains('evening') || cleanLower.contains('night');
                  if ((hasAm && !hasPm && explicitTime.endsWith('AM')) ||
                      (hasPm && !hasAm && explicitTime.endsWith('PM'))) {
                    t['dueTime'] = explicitTime;
                  }
                }
              }
            }

            // Single task relative date anchoring: ensure explicit date is retained
            if (tasks.length == 1 && (t['dueDate'] ?? '').toString().trim().isEmpty) {
              final cleanLower = cleanInput.toLowerCase();
              for (final token in [
                'day after tomorrow',
                'tomorrow morning',
                'tomorrow evening',
                'tomorrow',
                'today',
                'tonight',
                'this weekend',
                'weekend',
                'monday',
                'tuesday',
                'wednesday',
                'thursday',
                'friday',
                'saturday',
                'sunday',
              ]) {
                if (cleanLower.contains(token)) {
                  t['dueDate'] = token;
                  break;
                }
              }
            }

            // If Needle trimmed the action verb e.g. "Temple" when user said "go to Temple"
            final currentTitle = (t['title'] ?? '').toString().trim();
            final cleanLower = cleanInput.toLowerCase();
            if (currentTitle.isNotEmpty &&
                !cleanLower.startsWith(currentTitle.toLowerCase()) &&
                cleanLower.contains('go to ${currentTitle.toLowerCase()}')) {
              t['title'] = 'Go to $currentTitle';
            }

            final hasWhen = (t['dueDate'] ?? '').toString().trim().isNotEmpty ||
                (t['dueTime'] ?? '').toString().trim().isNotEmpty;
            if (remind && !hasWhen) {
              return ActionResult.clarificationNeeded(
                question:
                    'When should I remind you to "${t['title']}"? Please specify a day or time.',
                ambiguousField: 'time',
                pendingTitle: t['title'] as String?,
              );
            }
          }
        }
      }

      debugPrint('Dispatching action: ${request.actionName} ${request.arguments}');
      return await actionRouter.executeAction(
        actionName: request.actionName,
        arguments: request.arguments,
      );
    } catch (e) {
      debugPrint('Error processing command: $e');
      return ActionResult.error('Error processing command: $e');
    }
  }
}
