import 'base_tool.dart';
import '../../data/repositories/task_repository.dart';
import '../../models/task_model.dart';
import '../../core/utils/date_utils.dart';

class CreateTaskTool extends BaseTool {
  @override
  String get name => 'create_task';

  @override
  String get description =>
      'Extracts and stages one or more structured tasks (title, date, time, reminder) from natural voice or text commands for user confirmation.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'tasks': {
            'type': 'array',
            'description':
                'List of tasks to create. Supports multiple tasks extracted from a single command.',
            'items': {
              'type': 'object',
              'properties': {
                'title': {
                  'type': 'string',
                  'description': 'The concise title of the task.',
                },
                'description': {
                  'type': 'string',
                  'description': 'Optional extra details about the task.',
                },
                'dueDate': {
                  'type': 'string',
                  'description':
                      'Relative phrase (e.g. tomorrow, next Friday) or ISO date.',
                },
                'dueTime': {
                  'type': 'string',
                  'description':
                      'Specific time (e.g. 6:00 PM, 10:00 AM). Do NOT invent if not specified.',
                },
                'hasReminder': {
                  'type': 'boolean',
                  'description': 'Whether a reminder notification should be set.',
                },
                'hasAlarm': {
                  'type': 'boolean',
                  'description': 'Whether a loud continuous alarm clock should be set.',
                },
              },
              'required': ['title'],
            },
          },
        },
        'required': ['tasks'],
      };

  @override
  Future<ActionResult> execute({
    required Map<String, dynamic> arguments,
    required TaskRepository repository,
  }) async {
    final rawTasksList = arguments['tasks'];
    final List<Map<String, dynamic>> items = [];

    if (rawTasksList is List) {
      for (final item in rawTasksList) {
        if (item is Map<String, dynamic>) {
          items.add(item);
        } else if (item is Map) {
          items.add(Map<String, dynamic>.from(item));
        }
      }
    } else if (arguments.containsKey('title')) {
      // Single task shorthand
      items.add(arguments);
    }

    if (items.isEmpty) {
      return ActionResult.clarificationNeeded(
        question: 'I could not detect a task title. What would you like to get done?',
        ambiguousField: 'title',
        toolName: name,
      );
    }

    final List<Task> stagedTasks = [];

    for (final item in items) {
      final title = (item['title'] as String?)?.trim() ?? '';
      if (title.isEmpty) {
        return ActionResult.clarificationNeeded(
          question: 'What is the title of the task you would like to schedule?',
          ambiguousField: 'title',
          toolName: name,
        );
      }

      // Deterministic Date Parsing
      DateTime? parsedDate;
      final rawDate = item['dueDate'] as String?;
      if (rawDate != null && rawDate.isNotEmpty) {
        parsedDate = AppDateUtils.parseRelativeDate(rawDate) ??
            DateTime.tryParse(rawDate);
      }

      // Deterministic Time Parsing - NEVER invent missing times
      String? parsedTime;
      final rawTime = item['dueTime'] as String?;
      if (rawTime != null && rawTime.isNotEmpty) {
        parsedTime = AppDateUtils.parseTimeString(rawTime) ?? rawTime;
      }
      // If time was not provided separately, check if embedded in title
      parsedTime ??= AppDateUtils.parseTimeString(title);

      var cleanTitle = title;
      if (parsedTime != null) {
        cleanTitle = cleanTitle
            .replaceAll(
              RegExp(r'\b(?:at|by|before|for)\s*\d{1,2}(?:[:.]\d{2})?\s*(?:am|pm)?\b', caseSensitive: false),
              '',
            )
            .replaceAll(
              RegExp(r'\b\d{1,2}(?:[:.]\d{2})?\s*(?:am|pm)\b', caseSensitive: false),
              '',
            )
            .replaceAll(
              RegExp(r'\b(?:in the\s+)?(?:morning|afternoon|evening|night)\b', caseSensitive: false),
              '',
            );
      }
      cleanTitle = cleanTitle
          .replaceAll(RegExp(r'\b(?:at|by|on|for|before)\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'^[.,;!]+'), '')
          .replaceAll(RegExp(r'[.,;!]+$'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      // Strip leading "to " if leftover from infinitive
      cleanTitle = cleanTitle.replaceFirst(RegExp(r'^to\s+', caseSensitive: false), '');

      if (cleanTitle.isEmpty) {
        cleanTitle = title;
      } else {
        cleanTitle = cleanTitle[0].toUpperCase() + cleanTitle.substring(1);
      }

      final rawHasAlarm = item['hasAlarm'] as bool? ??
          (item['isAlarm'] as bool? ??
              (title.toLowerCase().contains('alarm') ||
                  title.toLowerCase().contains('wake me up') ||
                  title.toLowerCase().contains('wake up')));
      final rawHasReminder = item['hasReminder'] as bool? ?? (parsedTime != null);
      final hasAlarm = rawHasAlarm;
      final hasReminder = hasAlarm ? false : rawHasReminder;
      final description = item['description'] as String?;

      final task = Task(
        title: cleanTitle,
        description: description,
        dueDate: parsedDate,
        dueTime: parsedTime,
        hasReminder: hasReminder,
        hasAlarm: hasAlarm,
        accentColor: stagedTasks.isEmpty ? 'cyan' : 'violet',
      );

      stagedTasks.add(task);
    }

    final count = stagedTasks.length;
    final message = count == 1
        ? 'Staged 1 task for review: "${stagedTasks.first.title}"'
        : 'Staged $count tasks from your command for review.';

    return ActionResult.stagedForReview(
      message: message,
      stagedTasks: stagedTasks,
      toolName: name,
    );
  }
}
