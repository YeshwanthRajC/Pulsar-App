import '../core/utils/date_utils.dart';

class ToolCallRequest {
  final String actionName;
  final Map<String, dynamic> arguments;

  ToolCallRequest({required this.actionName, required this.arguments});
}

/// Fallback and companion deterministic parser for Cactus Needle.
/// Guarantees that whether running through CactusLM native FFI or offline parsing,
/// the exact same Action Modules are called with deterministic parameter validation.
class NeedleIntentParser {
  /// Parses transcribed speech or text into an Action Module Tool Call
  static ToolCallRequest parse(String text) {
    final clean = text.trim();
    final lower = clean.toLowerCase();

    // 1. Check for Retrieval Query Intent (e.g. "What are all the tasks for today?", "Tasks for this week", "What did I do yesterday?")
    if (_isRetrievalIntent(lower)) {
      String filter = 'today';
      String? status;
      String? keyword;

      // Check status filters first
      final isCompletedQuery = lower.contains('complete') ||
          lower.contains('completed') ||
          lower.contains('finish') ||
          lower.contains('finished') ||
          lower.contains('done') ||
          lower.contains('did i do') ||
          lower.contains('what did i accomplish');
      final isPendingQuery = lower.contains('pending') || lower.contains('left to do') || lower.contains('remaining');
      final isOverdueQuery = lower.contains('overdue') || lower.contains('late') || lower.contains('missed');

      if (isCompletedQuery) status = 'completed';
      if (isPendingQuery) status = 'pending';
      if (isOverdueQuery) status = 'overdue';

      // Determine period
      final pastDaysRegex = RegExp(
        r'\b(?:in\s+the\s+)?(?:last|past)\s+(\d+|one|two|three|four|five|six|seven|eight|nine|ten)\s+days?\b',
        caseSensitive: false,
      );
      final nextDaysRegex = RegExp(
        r'\b(?:in\s+the\s+)?next\s+(\d+|one|two|three|four|five|six|seven|eight|nine|ten)\s+days?\b',
        caseSensitive: false,
      );

      final pastMatch = pastDaysRegex.firstMatch(lower);
      final nextMatch = nextDaysRegex.firstMatch(lower);

      if (pastMatch != null) {
        final days = _parseNumberWord(pastMatch.group(1)!);
        filter = 'last_${days}_days';
      } else if (nextMatch != null) {
        final days = _parseNumberWord(nextMatch.group(1)!);
        filter = 'next_${days}_days';
      } else if (lower.contains('this week') || lower.contains('current week') || lower.contains('for the week')) {
        filter = 'this_week';
      } else if (lower.contains('next week')) {
        filter = 'next_week';
      } else if (lower.contains('last week')) {
        filter = 'last_week';
      } else if (lower.contains('this month') || lower.contains('current month')) {
        filter = 'this_month';
      } else if (lower.contains('next month')) {
        filter = 'next_month';
      } else if (lower.contains('this weekend') || lower.contains('weekend')) {
        filter = 'weekend';
      } else if (lower.contains('tomorrow')) {
        filter = 'tomorrow';
      } else if (lower.contains('yesterday')) {
        filter = 'yesterday';
      } else if (lower.contains('today') || lower.contains('for today')) {
        filter = 'today';
      } else if (lower.contains('upcoming') || lower.contains('coming up') || lower.contains('future')) {
        filter = 'upcoming';
      } else if (lower.contains('monday')) {
        filter = 'monday';
      } else if (lower.contains('tuesday')) {
        filter = 'tuesday';
      } else if (lower.contains('wednesday')) {
        filter = 'wednesday';
      } else if (lower.contains('thursday')) {
        filter = 'thursday';
      } else if (lower.contains('friday')) {
        filter = 'friday';
      } else if (lower.contains('saturday')) {
        filter = 'saturday';
      } else if (lower.contains('sunday')) {
        filter = 'sunday';
      } else if (isOverdueQuery) {
        filter = 'overdue';
      } else if (isCompletedQuery) {
        filter = 'completed';
      } else if (isPendingQuery) {
        filter = 'pending';
      } else if (lower.contains('all') || lower.contains('everything')) {
        filter = 'all';
      }

      // Check for keyword query (e.g. "about DSA", "with groceries", "for assignment")
      final keywordMatch = RegExp(r'\b(?:about|matching|named|titled|keyword)\s+([a-zA-Z0-9_\s]+)', caseSensitive: false)
          .firstMatch(clean);
      if (keywordMatch != null) {
        keyword = keywordMatch.group(1)?.trim();
      }

      final Map<String, dynamic> arguments = {'filter': filter};
      if (status != null) arguments['status'] = status;
      if (keyword != null && keyword.isNotEmpty) arguments['keyword'] = keyword;

      return ToolCallRequest(
        actionName: 'retrieve_tasks',
        arguments: arguments,
      );
    }

    // 2. Check for Update / Completion Intent (e.g. "Mark call Mom as completed", "Mark workout as done")
    final updateMatch = RegExp(
      r'^(?:mark\s+)?(?:task\s+)?(.+?)\s+(?:as\s+)?(completed|done|finished|pending)$',
      caseSensitive: false,
    ).firstMatch(clean);
    final completeCommandMatch = RegExp(
      r'^(?:complete|finish|done\s+with)\s+(?:task\s+)?(.+)$',
      caseSensitive: false,
    ).firstMatch(clean);

    if (updateMatch != null) {
      final target = updateMatch.group(1)!.trim();
      final statusWord = updateMatch.group(2)!.toLowerCase();
      final isDone = statusWord != 'pending';
      return ToolCallRequest(
        actionName: 'update_task',
        arguments: {'target': target, 'isCompleted': isDone},
      );
    } else if (completeCommandMatch != null && !_isRetrievalIntent(lower)) {
      final target = completeCommandMatch.group(1)!.trim();
      return ToolCallRequest(
        actionName: 'update_task',
        arguments: {'target': target, 'isCompleted': true},
      );
    }

    // 3. Check for Deletion Intent (e.g. "Delete task complete Java assignment", "Remove review DSA")
    if (lower.startsWith('delete') || lower.startsWith('remove') || lower.startsWith('cancel task')) {
      final target = clean
          .replaceFirst(RegExp(r'^(delete|remove|cancel)\s*(task)?\s*', caseSensitive: false), '')
          .trim();
      return ToolCallRequest(
        actionName: 'delete_task',
        arguments: {'target': target},
      );
    }

    // 3. Multi-task splitting check: e.g. "Buy groceries at 5 PM and call Mom at 7 PM"
    final taskClauses = _splitMultipleTaskClauses(clean);
    final List<Map<String, dynamic>> extractedTasks = [];

    for (final clause in taskClauses) {
      final taskData = _extractSingleTask(clause);
      if (taskData != null) {
        extractedTasks.add(taskData);
      }
    }

    if (extractedTasks.isNotEmpty) {
      // Check if any task requested a reminder but provided no time/date
      for (final t in extractedTasks) {
        final title = t['title'] as String;
        final hasReminder = t['hasReminder'] as bool? ?? false;
        final dueTime = t['dueTime'] as String?;
        final dueDate = t['dueDate'] as String?;

        if (hasReminder && dueTime == null && dueDate == null) {
          return ToolCallRequest(
            actionName: 'request_clarification',
            arguments: {
              'ambiguousField': 'time',
              'question': 'When should I remind you to "$title"? Please specify a day or time.',
            },
          );
        }
      }

      return ToolCallRequest(
        actionName: 'create_task',
        arguments: {'tasks': extractedTasks},
      );
    }

    // 4. Ambiguity / Clarification Fallback:
    return ToolCallRequest(
      actionName: 'request_clarification',
      arguments: {
        'ambiguousField': 'title',
        'question': 'I heard "$clean". Could you please clarify the task title and due time?',
      },
    );
  }

  static bool _isRetrievalIntent(String lower) {
    return lower.contains('what are') ||
        lower.contains('what is') ||
        lower.contains('what do i have') ||
        lower.contains('what did i') ||
        lower.contains('what did') ||
        lower.contains('what tasks') ||
        lower.contains('tasks completed') ||
        lower.contains('tasks done') ||
        lower.contains('tasks finished') ||
        lower.contains('tasks he completed') ||
        lower.contains('tasks i completed') ||
        lower.contains('tasks i did') ||
        lower.contains('which tasks') ||
        lower.contains('show me') ||
        lower.contains('show tasks') ||
        lower.contains('show my') ||
        lower.contains('list my') ||
        lower.contains('list tasks') ||
        lower.contains('list all') ||
        lower.contains('get tasks') ||
        lower.contains('view tasks') ||
        lower.contains('do i have') ||
        lower.contains('summarize') ||
        lower.contains('summary') ||
        lower.contains('how many tasks') ||
        lower.contains('check my tasks') ||
        lower.contains('check tasks') ||
        lower.startsWith('tasks') ||
        (lower.startsWith('tasks for') || lower.startsWith('my tasks'));
  }

  static int _parseNumberWord(String word) {
    final lower = word.toLowerCase().trim();
    switch (lower) {
      case 'one':
        return 1;
      case 'two':
        return 2;
      case 'three':
        return 3;
      case 'four':
        return 4;
      case 'five':
        return 5;
      case 'six':
        return 6;
      case 'seven':
        return 7;
      case 'eight':
        return 8;
      case 'nine':
        return 9;
      case 'ten':
        return 10;
      default:
        return int.tryParse(lower) ?? 3;
    }
  }

  static List<String> _splitMultipleTaskClauses(String input) {
    // Check if the command has compound statements like:
    // "Buy groceries at 5 PM and call mom at 7 PM"
    // "Finish report tomorrow morning, and also schedule meeting on Friday"
    final regex = RegExp(r'\b(?:and\s+also|and\s+then|and)\b', caseSensitive: false);
    
    // Only split if the word "and" is followed by a verb / new task indicator
    if (input.contains(regex)) {
      final parts = input.split(regex);
      if (parts.length > 1 && parts.every((p) => p.trim().split(' ').length >= 2)) {
        return parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      }
    }
    return [input];
  }

  static Map<String, dynamic>? _extractSingleTask(String input) {
    var text = input.trim();

    // Clean common leading prefixes:
    // "Remind me to finish my Java assignment tomorrow at 6 PM"
    // "Set an alarm for tomorrow 10:00 AM to go to Temple"
    // "Schedule a meeting with my project teammate on Friday"
    // "Create a task to complete my report by next Monday morning"
    // "Add a task to review DSA this weekend"
    text = text.replaceFirst(
      RegExp(
        r'^(remind me to|create a task to|add a task to|schedule a meeting with|schedule a meeting|schedule a task to|schedule a task|schedule|create|add|set an alarm for|set an alarm to|set an alarm|set alarm for|set alarm to|set alarm|set a reminder for|set a reminder to|set a reminder|set reminder for|set reminder to|set reminder|alarm for|wake me up at|wake me up for|wake me up|remind me)\s*',
        caseSensitive: false,
      ),
      '',
    );

    if (text.isEmpty) return null;

    final hasReminder = input.toLowerCase().contains('remind') ||
        input.toLowerCase().contains('reminder') ||
        input.toLowerCase().contains('alarm') ||
        input.toLowerCase().contains('wake');

    // Handle inverted syntax e.g. "tomorrow 10:00 AM to go to Temple" -> "go to Temple tomorrow 10:00 AM"
    final toMatch = RegExp(r'^(.+?)\s+to\s+(.+)$', caseSensitive: false).firstMatch(text);
    if (toMatch != null) {
      final potentialTimeOrDate = toMatch.group(1)!;
      final actionPart = toMatch.group(2)!;
      final hasTimeOrDate = AppDateUtils.parseTimeString(potentialTimeOrDate) != null ||
          AppDateUtils.parseRelativeDate(potentialTimeOrDate) != null;
      if (hasTimeOrDate) {
        final cleanAction = actionPart.replaceAll(RegExp(r'[.,;!]+$'), '').replaceAll(RegExp(r'^[.,;!]+'), '').trim();
        final cleanTime = potentialTimeOrDate.replaceAll(RegExp(r'[.,;!]+$'), '').replaceAll(RegExp(r'^[.,;!]+'), '').trim();
        text = '$cleanAction $cleanTime';
      }
    }

    // Extract time
    final parsedTime = AppDateUtils.parseTimeString(text);

    // Extract relative date
    String? datePhrase;
    final lower = text.toLowerCase();
    final relativeTokens = [
      'day after tomorrow',
      'in two days',
      'in 2 days',
      'tomorrow morning',
      'tomorrow evening',
      'tomorrow',
      'today',
      'tonight',
      'this weekend',
      'weekend',
      'next monday',
      'next tuesday',
      'next wednesday',
      'next thursday',
      'next friday',
      'next saturday',
      'next sunday',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];

    for (final token in relativeTokens) {
      if (lower.contains(token)) {
        datePhrase = token;
        break;
      }
    }

    // Clean date and time phrases from the title to keep title clean
    var cleanTitle = text;
    if (parsedTime != null) {
      // Remove digital time expressions: "at 6 PM", "at 6:00 PM", "by 7.00pm", "by 7", "6 PM", "7.00pm", "10:00 AM"
      cleanTitle = cleanTitle.replaceAll(
        RegExp(r'\b(?:at|by|before|for)\s*\d{1,2}(?:[:.]\d{2})?\s*(?:am|pm)?\b', caseSensitive: false),
        ' ',
      );
      cleanTitle = cleanTitle.replaceAll(
        RegExp(r'\b\d{1,2}(?:[:.]\d{2})?\s*(?:am|pm)\b', caseSensitive: false),
        ' ',
      );
      // Remove word-based time expressions: "ten a.m.", "ten a.m", "seven pm", "at ten", "ten thirty", "a.m.", "p.m."
      cleanTitle = cleanTitle.replaceAll(
        RegExp(r'\b(?:at|by|before|for)?\s*(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\s*(?:thirty|fifteen|forty[\s-]five|twenty)?\s*(?:am|pm|a\.m\.?|p\.m\.?)?(?![a-zA-Z0-9])', caseSensitive: false),
        ' ',
      );
      cleanTitle = cleanTitle.replaceAll(
        RegExp(r'\b(?:a\.m\.?|p\.m\.?|am|pm)(?![a-zA-Z0-9])', caseSensitive: false),
        ' ',
      );
      cleanTitle = cleanTitle.replaceAll(
        RegExp(r'\b(?:in the\s+)?(?:morning|afternoon|evening|night)\b', caseSensitive: false),
        ' ',
      );
    }

    if (datePhrase != null) {
      // Remove date expression like "on Friday", "by next Monday morning", "tomorrow", "tonight"
      cleanTitle = cleanTitle.replaceAll(
        RegExp('\\b(?:on|by|for)?\\s*${RegExp.escape(datePhrase)}\\b', caseSensitive: false),
        ' ',
      );
    }

    // Clean leftovers and trailing punctuation (e.g. "." from "Call mom by 7.")
    cleanTitle = cleanTitle
        .replaceAll(RegExp(r'\b(?:at|by|on|for|before)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'^[.,;!]+'), '')
        .replaceAll(RegExp(r'[.,;!]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Strip leading "to " if leftover from infinitive
    cleanTitle = cleanTitle.replaceFirst(RegExp(r'^to\s+', caseSensitive: false), '');

    // Capitalize first letter
    if (cleanTitle.isNotEmpty) {
      cleanTitle = cleanTitle[0].toUpperCase() + cleanTitle.substring(1);
    } else {
      if (input.toLowerCase().contains('alarm') || input.toLowerCase().contains('wake')) {
        cleanTitle = 'Alarm';
      } else if (input.toLowerCase().contains('remind')) {
        cleanTitle = 'Reminder';
      } else {
        cleanTitle = 'New Task';
      }
    }

    final hasAlarm = input.toLowerCase().contains('alarm') ||
        input.toLowerCase().contains('wake');

    return {
      'title': cleanTitle,
      'dueDate': datePhrase,
      'dueTime': parsedTime,
      'hasReminder': hasReminder || (parsedTime != null),
      'hasAlarm': hasAlarm,
      'description': null,
    };
  }
}
