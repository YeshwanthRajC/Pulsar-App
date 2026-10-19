import '../models/task_model.dart';

/// Provides domain-specific keyword biasing and acoustic post-processing
/// to maximize Whistle speech-to-text accuracy.
class VoiceEnhancementService {
  VoiceEnhancementService._();
  static final VoiceEnhancementService instance = VoiceEnhancementService._();

  /// Core task management, calendar, time, actions, and common terms for Aho-Corasick automaton biasing.
  static const List<String> _baseKeywords = [
    // Action verbs & intents
    'set an alarm',
    'set alarm',
    'alarm',
    'wake me up',
    'wake me up at',
    'wake up',
    'remind me to',
    'remind me',
    'reminder',
    'create task',
    'add task',
    'new task',
    'schedule',
    'schedule task',
    'schedule a meeting',
    'delete task',
    'remove task',
    'cancel task',
    'update task',
    'reschedule',
    'complete',
    'completed',
    'mark as done',
    'mark done',
    'finish',
    'review',
    'todo',
    'urgent',
    'priority',

    // Temporal phrases & periods
    'today',
    'tomorrow',
    'day after tomorrow',
    'yesterday',
    'this week',
    'next week',
    'last week',
    'this month',
    'next month',
    'this weekend',
    'weekend',
    'upcoming',
    'overdue',
    'pending',

    // Days of the week
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',

    // Time indicators & spoken words
    'morning',
    'afternoon',
    'evening',
    'tonight',
    'night',
    'noon',
    'midnight',
    'AM',
    'PM',
    'a.m.',
    'p.m.',
    "o'clock",
    'half past',
    'quarter past',
    'quarter to',

    // Common spoken time words for Whistle recognition
    'ten a.m.',
    'ten p.m.',
    'seven a.m.',
    'seven p.m.',
    'six a.m.',
    'six p.m.',
    'eight a.m.',
    'eight p.m.',
    'nine a.m.',
    'nine p.m.',
    'one',
    'two',
    'three',
    'four',
    'five',
    'six',
    'seven',
    'eight',
    'nine',
    'ten',
    'eleven',
    'twelve',
    'fifteen',
    'twenty',
    'thirty',
    'forty-five',
    'forty five',

    // Common activity, destinations & academic nouns
    'go to Temple',
    'go to temple',
    'temple',
    'church',
    'mosque',
    'gym',
    'market',
    'grocery',
    'supermarket',
    'office',
    'hospital',
    'doctor',
    'clinic',
    'dentist',
    'bank',
    'pharmacy',
    'library',
    'college',
    'school',
    'class',
    'lecture',
    'lab',
    'airport',
    'station',
    'DSA',
    'Data Structures',
    'Algorithms',
    'assignment',
    'presentation',
    'groceries',
    'homework',
    'exam',
    'test',
    'quiz',
    'workout',
    'meeting',
    'standup',
    'teammate',
    'project',
    'call Mom',
    'call Dad',
    'call teammate',
    'buy groceries',
    'buy milk',
    'pay bills',
    'submit assignment',
  ];

  static const Map<String, int> _numberWords = {
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
  };

  static const Map<String, String> _minuteWords = {
    'fifteen': '15',
    'twenty': '20',
    'twenty-five': '25',
    'twenty five': '25',
    'thirty': '30',
    'thirty-five': '35',
    'thirty five': '35',
    'forty': '40',
    'forty-five': '45',
    'forty five': '45',
    'fifty': '50',
    'fifty-five': '55',
    'fifty five': '55',
  };

  /// Builds a newline-separated keyword biasing string for Whistle ASR.
  /// Dynamically extracts task titles and keywords from existing database tasks.
  String buildKeywords({List<Task>? tasks}) {
    final Set<String> keywordSet = Set<String>.from(_baseKeywords);

    if (tasks != null) {
      for (final task in tasks) {
        final title = task.title.trim();
        if (title.isNotEmpty) {
          keywordSet.add(title);
          // Also add distinctive words > 3 characters
          for (final word in title.split(RegExp(r'\s+'))) {
            final cleanWord = word.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
            if (cleanWord.length > 3) {
              keywordSet.add(cleanWord);
            }
          }
        }
      }
    }

    return keywordSet.join('\n');
  }

  /// Corrects common acoustic misrecognitions, normalizes times/numbers,
  /// and canonicalizes spoken alarm/reminder syntax so Needle understands the task context.
  String postProcessTranscript(String text) {
    var cleaned = text.trim();
    if (cleaned.isEmpty) return cleaned;

    // 1. Fix DSA acronym mishearings (e.g. "dsa", "d s a", "the essay" in tech/task context)
    cleaned = cleaned.replaceAll(
      RegExp(r'\b(?:d\s*s\s*a|the\s+essay)\b', caseSensitive: false),
      'DSA',
    );

    // 2. Fix acoustic misrecognitions like "remind me two" -> "remind me to"
    cleaned = cleaned.replaceAll(
      RegExp(r'\bremind\s+me\s+two\b', caseSensitive: false),
      'remind me to',
    );

    // 3. Fix "to do" / "to - do" -> "todo"
    cleaned = cleaned.replaceAll(
      RegExp(r'\bto\s*-\s*do\b', caseSensitive: false),
      'todo',
    );

    // 4. Convert spoken word fractions (half past ten -> 10:30, quarter past seven -> 7:15)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\bhalf\s+past\s+(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|\d{1,2})\b', caseSensitive: false),
      (match) {
        final hour = _numberWords[match[1]!.toLowerCase()] ?? int.tryParse(match[1]!) ?? 12;
        return '$hour:30';
      },
    );

    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\bquarter\s+past\s+(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|\d{1,2})\b', caseSensitive: false),
      (match) {
        final hour = _numberWords[match[1]!.toLowerCase()] ?? int.tryParse(match[1]!) ?? 12;
        return '$hour:15';
      },
    );

    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\bquarter\s+to\s+(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|\d{1,2})\b', caseSensitive: false),
      (match) {
        final nextHour = _numberWords[match[1]!.toLowerCase()] ?? int.tryParse(match[1]!) ?? 1;
        final hour = (nextHour == 1) ? 12 : (nextHour - 1);
        return '$hour:45';
      },
    );

    // 5. Convert word hours + minutes (e.g. "ten thirty a.m." -> "10:30 AM", "six fifteen p.m." -> "6:15 PM")
    final numWordsPattern = _numberWords.keys.join('|');
    final minWordsPattern = _minuteWords.keys.join('|');
    cleaned = cleaned.replaceAllMapped(
      RegExp('\\b($numWordsPattern)\\s+($minWordsPattern)(?:\\s*(a\\.?m\\.?|p\\.?m\\.?|am|pm))?(?![a-zA-Z0-9])', caseSensitive: false),
      (match) {
        final hour = _numberWords[match[1]!.toLowerCase()]!;
        final minute = _minuteWords[match[2]!.toLowerCase().replaceAll(RegExp(r'\s+'), ' ')] ?? '00';
        final ampm = match[3];
        if (ampm != null) {
          final period = ampm.toUpperCase().replaceAll('.', '');
          return '$hour:$minute $period';
        }
        return '$hour:$minute';
      },
    );

    // 6. Convert word hours + AM/PM: e.g. "ten a.m." -> "10:00 AM", "seven p.m." -> "7:00 PM"
    cleaned = cleaned.replaceAllMapped(
      RegExp('\\b($numWordsPattern)\\s*(a\\.?m\\.?|p\\.?m\\.?|am|pm)(?![a-zA-Z0-9])', caseSensitive: false),
      (match) {
        final hour = _numberWords[match[1]!.toLowerCase()]!;
        final period = match[2]!.toUpperCase().replaceAll('.', '');
        return '$hour:00 $period';
      },
    );

    // 7. Convert word hours + o'clock: e.g. "ten o'clock" -> "10:00"
    cleaned = cleaned.replaceAllMapped(
      RegExp('\\b($numWordsPattern)\\s*o\\s*\'?\\s*clock\\b', caseSensitive: false),
      (match) {
        final hour = _numberWords[match[1]!.toLowerCase()]!;
        return '$hour:00';
      },
    );

    // 8. Normalize standalone dotted periods: "a.m." -> "AM", "p.m." -> "PM"
    cleaned = cleaned.replaceAll(RegExp(r'\ba\.m\.?(?![a-zA-Z0-9])', caseSensitive: false), 'AM');
    cleaned = cleaned.replaceAll(RegExp(r'\bp\.m\.?(?![a-zA-Z0-9])', caseSensitive: false), 'PM');

    // 9. Normalize digital time expressions with minutes: e.g. "6:00pm" -> "6:00 PM", "7.00 AM" -> "7:00 AM"
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\b(\d{1,2})[:.](\d{2})\s*(am|pm)\b', caseSensitive: false),
      (match) => '${match[1]}:${match[2]} ${match[3]!.toUpperCase()}',
    );

    // 10. Normalize hour-only time expressions: e.g. "7 am" -> "7:00 AM", "10 AM" -> "10:00 AM"
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(?<!:)\b(\d{1,2})\s*(am|pm)\b', caseSensitive: false),
      (match) => '${match[1]}:00 ${match[2]!.toUpperCase()}',
    );

    // 11. Normalize "o clock" -> ":00"
    cleaned = cleaned.replaceAll(
      RegExp(r"\b(\d{1,2})\s*o\s*'?\s*clock\b", caseSensitive: false),
      r"$1:00",
    );

    // 12. Canonicalize inverted alarm/reminder phrasing:
    // e.g. "Set an alarm for tomorrow 10:00 AM to go to Temple." -> "Remind me to go to Temple tomorrow at 10:00 AM"
    // e.g. "Set a reminder for tomorrow 10:00 AM to go to Temple" -> "Remind me to go to Temple tomorrow at 10:00 AM"
    // e.g. "Alarm for tomorrow 10:00 AM to go to Temple" -> "Remind me to go to Temple tomorrow at 10:00 AM"
    // e.g. "Wake me up tomorrow at 7:00 AM to study" -> "Remind me to study tomorrow at 7:00 AM"
    cleaned = _canonicalizeAlarmPhrasing(cleaned);

    // 13. Clean trailing periods on AM/PM (e.g. "10:30 AM." -> "10:30 AM")
    cleaned = cleaned.replaceAll(RegExp(r'(?<=(?:AM|PM))[.]+$'), '');

    // 14. Ensure clean spacing
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleaned;
  }

  /// Restructures spoken alarm and reminder phrases into canonical task format
  /// that Needle tool calling reliably parses.
  static String _canonicalizeAlarmPhrasing(String input) {
    var text = input.trim();

    // Pattern A: "Set an alarm for [when] to [action]" or "Alarm for [when] to [action]"
    final alarmForToRegex = RegExp(
      r'^(?:set\s+an?\s+alarm|set\s+alarm|alarm|set\s+a\s+reminder|set\s+reminder)\s+for\s+(.+?)\s+to\s+(.+)$',
      caseSensitive: false,
    );
    final matchA = alarmForToRegex.firstMatch(text);
    if (matchA != null) {
      final whenPart = _cleanWhenPart(matchA.group(1)!);
      final actionPart = _cleanActionPart(matchA.group(2)!);
      return 'Remind me to $actionPart $whenPart';
    }

    // Pattern B: "Wake me up (at) [when] to [action]"
    final wakeMeToRegex = RegExp(
      r'^wake\s+me\s+up\s+(?:at\s+)?(.+?)\s+to\s+(.+)$',
      caseSensitive: false,
    );
    final matchB = wakeMeToRegex.firstMatch(text);
    if (matchB != null) {
      final whenPart = _cleanWhenPart(matchB.group(1)!);
      final actionPart = _cleanActionPart(matchB.group(2)!);
      return 'Remind me to $actionPart $whenPart';
    }

    // Pattern C: "Remind me [when] to [action]" (when [when] contains time or date)
    final remindWhenToRegex = RegExp(
      r'^remind\s+me\s+(.+?)\s+to\s+(.+)$',
      caseSensitive: false,
    );
    final matchC = remindWhenToRegex.firstMatch(text);
    if (matchC != null) {
      final middle = matchC.group(1)!.trim().toLowerCase();
      final hasTemporal = middle.contains('today') ||
          middle.contains('tomorrow') ||
          middle.contains('am') ||
          middle.contains('pm') ||
          middle.contains('morning') ||
          middle.contains('evening') ||
          middle.contains('night') ||
          RegExp(r'\d{1,2}(?::\d{2})?').hasMatch(middle);
      if (hasTemporal) {
        final whenPart = _cleanWhenPart(matchC.group(1)!);
        final actionPart = _cleanActionPart(matchC.group(2)!);
        return 'Remind me to $actionPart $whenPart';
      }
    }

    // Pattern D: "Set an alarm to [action] (at/for/on [when])"
    final alarmToRegex = RegExp(
      r'^(?:set\s+an?\s+alarm|set\s+alarm)\s+to\s+(.+)$',
      caseSensitive: false,
    );
    final matchD = alarmToRegex.firstMatch(text);
    if (matchD != null) {
      final actionAndWhen = _cleanActionPart(matchD.group(1)!);
      return 'Remind me to $actionAndWhen';
    }

    // Pattern E: "Set an alarm for [when]" or "Wake me up at [when]" (without "to [action]")
    final alarmOnlyRegex = RegExp(
      r'^(?:set\s+an?\s+alarm|set\s+alarm|wake\s+me\s+up)\s+(?:for|at)\s+(.+)$',
      caseSensitive: false,
    );
    final matchE = alarmOnlyRegex.firstMatch(text);
    if (matchE != null) {
      final whenPart = _cleanWhenPart(matchE.group(1)!);
      return 'Remind me to wake up $whenPart';
    }

    return text;
  }

  static String _cleanActionPart(String raw) {
    return raw
        .replaceAll(RegExp(r'[.,;!]+$'), '')
        .replaceAll(RegExp(r'^[.,;!]+'), '')
        .trim();
  }

  static String _cleanWhenPart(String raw) {
    var cleaned = raw
        .replaceAll(RegExp(r'[.,;!]+$'), '')
        .replaceAll(RegExp(r'^[.,;!]+'), '')
        .trim();

    // If time is present without 'at' before it, insert 'at' for smooth parsing
    // e.g. "tomorrow 10:00 AM" -> "tomorrow at 10:00 AM"
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(?<!at\s)\b(\d{1,2}:\d{2}\s+(?:AM|PM))\b'),
      (m) => 'at ${m[1]}',
    );

    return cleaned;
  }
}
