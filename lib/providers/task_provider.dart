import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../data/repositories/task_repository.dart';
import '../services/notification_service.dart';
import '../services/alarm_service.dart';
import '../ai/cactus_service.dart';
import '../ai/action_modules/base_action.dart';
import '../core/utils/date_utils.dart';
import '../services/voice_capture_service.dart';

class TaskProvider extends ChangeNotifier {
  final TaskRepository repository;
  final CactusService cactusService;
  final NotificationService notificationService;
  final VoiceCaptureService _voiceCapture = VoiceCaptureService();

  List<Task> _tasks = [];
  DateTime _selectedDate = DateTime.now();
  DateTime _calendarMonth = DateTime.now();
  String _filter = 'all'; // 'all', 'pending', 'completed'
  bool _isLoading = false;

  // Voice & AI State for Task Creation
  bool _isListening = false;
  bool _isProcessingAI = false;
  String _currentVoiceTranscript = '';
  List<Task> _stagedTasks = [];
  Map<String, dynamic>? _clarificationPrompt;
  ActionResult? _lastActionResult;
  String _liveTranscript = '';
  String? _voiceError;
  bool _isTranscribing = false;

  TaskProvider({
    required this.repository,
    required this.cactusService,
    required this.notificationService,
  }) {
    _init();
  }

  // Getters
  List<Task> get allTasks => _tasks;
  DateTime get selectedDate => _selectedDate;
  DateTime get calendarMonth => _calendarMonth;
  String get filter => _filter;
  bool get isLoading => _isLoading;

  bool get isListening => _isListening;
  bool get isProcessingAI => _isProcessingAI;
  String get currentVoiceTranscript => _currentVoiceTranscript;
  List<Task> get stagedTasks => _stagedTasks;
  Map<String, dynamic>? get clarificationPrompt => _clarificationPrompt;
  ActionResult? get lastActionResult => _lastActionResult;
  String get liveTranscript => _liveTranscript;
  String? get voiceError => _voiceError;
  bool get isTranscribing => _isTranscribing;
  String? get lastNeedleNote => cactusService.lastNeedleNote;
  bool get isNeedleRunning => cactusService.isNeedleRunning;
  bool get isWhistleRunning => cactusService.isWhistleRunning;
  String get modelStatusMessage => cactusService.statusMessage;

  List<Task> get filteredTasks {
    switch (_filter) {
      case 'pending':
        return _tasks.where((t) => !t.isCompleted).toList();
      case 'completed':
        return _tasks.where((t) => t.isCompleted).toList();
      case 'all':
      default:
        return _tasks;
    }
  }

  List<Task> get tasksForSelectedDate {
    return _tasks.where((t) {
      if (t.dueDate == null) return false;
      return AppDateUtils.isSameDay(t.dueDate!, _selectedDate);
    }).toList();
  }

  int get pendingTasksCount => _tasks.where((t) => !t.isCompleted).length;
  int get completedTasksCount => _tasks.where((t) => t.isCompleted).length;

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    await repository.removePredefinedTasksIfPresent();
    await refreshTasks();

    _isLoading = false;
    notifyListeners();

    // Initialize on-device models in background without freezing main UI thread
    unawaited(cactusService.initializeEngine().then((_) {
      notifyListeners();
    }));
  }

  Future<void> refreshTasks() async {
    _tasks = await repository.getAllTasks();
    notifyListeners();
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void changeMonth(int monthOffset) {
    _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + monthOffset, 1);
    notifyListeners();
  }

  void setFilter(String newFilter) {
    _filter = newFilter;
    notifyListeners();
  }

  Future<void> addTask(Task task) async {
    final created = await repository.createTask(task);
    if (created.hasReminder) {
      await notificationService.scheduleTaskReminder(created);
    }
    if (created.hasAlarm) {
      await AlarmService.instance.scheduleTaskAlarm(created);
    }
    await refreshTasks();
  }

  Future<void> updateTask(Task task) async {
    await repository.updateTask(task);
    await notificationService.updateTaskReminder(task);
    if (task.hasAlarm && !task.isCompleted) {
      await AlarmService.instance.scheduleTaskAlarm(task);
    } else if (task.id != null) {
      await AlarmService.instance.cancelTaskAlarm(task.id!);
    }
    await refreshTasks();
  }

  Future<void> deleteTask(int id) async {
    await repository.deleteTask(id);
    await notificationService.cancelTaskReminder(id);
    await AlarmService.instance.cancelTaskAlarm(id);
    await refreshTasks();
  }

  Future<void> toggleTask(int id) async {
    final updated = await repository.toggleTask(id);
    if (updated != null) {
      if (updated.isCompleted) {
        await notificationService.cancelTaskReminder(id);
        await AlarmService.instance.cancelTaskAlarm(id);
      } else {
        if (updated.hasReminder) {
          await notificationService.scheduleTaskReminder(updated);
        }
        if (updated.hasAlarm) {
          await AlarmService.instance.scheduleTaskAlarm(updated);
        }
      }
    }
    await refreshTasks();
  }

  Future<void> clearAllTasks() async {
    for (final task in _tasks) {
      if (task.id != null) {
        await notificationService.cancelTaskReminder(task.id!);
        await AlarmService.instance.cancelTaskAlarm(task.id!);
      }
    }
    await AlarmService.instance.cancelAll();
    await repository.clearAll();
    await refreshTasks();
  }

  // AI & Voice Workflow
  void setListeningState(bool listening) {
    _isListening = listening;
    notifyListeners();
  }

  void setVoiceTranscript(String text) {
    _currentVoiceTranscript = text;
    notifyListeners();
  }

  void clearVoiceError() {
    _voiceError = null;
    notifyListeners();
  }

  /// Whistle (on-device STT) -> Needle (task creation) pipeline.
  /// Tap once to start recording; it stops on a tap or when you stop speaking.
  Future<void> toggleVoiceCapture() async {
    if (_isTranscribing) return;
    if (_isListening) {
      await _finishCapture();
      return;
    }

    _voiceError = null;
    _liveTranscript = '';

    final started = await _voiceCapture.start(
      onAutoStop: () => _finishCapture(),
    );
    if (!started) {
      _voiceError =
          'Microphone is unavailable. Allow microphone access in system settings, or use manual entry.';
      notifyListeners();
      return;
    }
    _isListening = true;
    notifyListeners();
  }

  Future<void> _finishCapture() async {
    if (!_isListening) return;
    _isListening = false;
    _isTranscribing = true;
    notifyListeners();

    try {
      final pcm = await _voiceCapture.stop();
      if (pcm.length < VoiceCaptureService.sampleRate ~/ 4) {
        _voiceError = "Didn't catch that. Tap the mic and try again.";
        return;
      }

      final text = await cactusService.transcribe(pcm);
      if (text.trim().isEmpty) {
        _voiceError = "Didn't catch that. Tap the mic and try again.";
        return;
      }
      _liveTranscript = text;
      _voiceError = null;
      _isTranscribing = false;
      notifyListeners();

      // If a clarification prompt is already awaiting time/details for a pending title,
      // combine the pending context with newly spoken clarification
      if (_clarificationPrompt != null && _clarificationPrompt!['pendingTitle'] != null) {
        final pendingTitle = _clarificationPrompt!['pendingTitle'] as String;
        await submitVoiceCommand('$pendingTitle $text');
      } else {
        await submitVoiceCommand(text);
      }
    } catch (e) {
      _voiceError = e is StateError ? e.message.toString() : 'Voice error: $e';
    } finally {
      _isTranscribing = false;
      notifyListeners();
    }
  }

  /// Submits voice command for on-device AI task draft extraction
  Future<void> submitVoiceCommand(String commandText) async {
    final clean = commandText.trim();
    if (clean.isEmpty) return;

    _isProcessingAI = true;
    _currentVoiceTranscript = clean;
    _voiceError = null;
    notifyListeners();

    try {
      final result = await cactusService.processVoiceCommand(clean);
      _lastActionResult = result;

      if (result.type == ActionResultType.tasksStagedForConfirmation) {
        // Task draft(s) created for user confirmation
        _stagedTasks = (result.data as List<dynamic>).cast<Task>();
        _clarificationPrompt = null;
      } else if (result.type == ActionResultType.clarificationNeeded) {
        // Insufficient information prompted by model
        _clarificationPrompt = result.data as Map<String, dynamic>?;
        _stagedTasks = [];
      } else {
        // If query/update/delete was spoken, remind user of voice-to-task creation
        _clarificationPrompt = {
          'question': result.message.isNotEmpty
              ? result.message
              : 'What task would you like to schedule?',
          'ambiguousField': 'title',
        };
        _stagedTasks = [];
      }
    } catch (e) {
      _lastActionResult = ActionResult.error('Error processing command: $e');
      _voiceError = 'Error processing command: $e';
    } finally {
      _isProcessingAI = false;
      notifyListeners();
    }
  }

  /// Updates an individual staged task in the draft list
  void updateStagedTask(int index, Task updatedTask) {
    if (index >= 0 && index < _stagedTasks.length) {
      _stagedTasks[index] = updatedTask;
      notifyListeners();
    }
  }

  /// Removes a task from the staged drafts
  void removeStagedTask(int index) {
    if (index >= 0 && index < _stagedTasks.length) {
      _stagedTasks.removeAt(index);
      if (_stagedTasks.isEmpty) {
        _currentVoiceTranscript = '';
      }
      notifyListeners();
    }
  }

  /// Confirm and save all staged tasks to SQLite & schedule notifications
  Future<void> confirmStagedTasks() async {
    for (final task in _stagedTasks) {
      await addTask(task);
    }
    _stagedTasks = [];
    _currentVoiceTranscript = '';
    _clarificationPrompt = null;
    notifyListeners();
  }

  /// Cancels and discards the staged drafts
  void cancelStagedTasks() {
    _stagedTasks = [];
    _clarificationPrompt = null;
    _currentVoiceTranscript = '';
    notifyListeners();
  }

  /// When user opts to save a clarification task without setting an alarm
  void saveClarificationTaskWithoutReminder(String title) {
    _clarificationPrompt = null;
    _stagedTasks = [
      Task(
        title: title,
        hasReminder: false,
        accentColor: 'cyan',
      ),
    ];
    notifyListeners();
  }
}
