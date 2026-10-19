import 'package:intl/intl.dart';

class AppDateUtils {
  static final DateFormat fullDateFormat = DateFormat('EEE, d MMM yyyy');
  static final DateFormat shortDateFormat = DateFormat('d MMM');
  static final DateFormat monthYearFormat = DateFormat('MMMM yyyy');
  static final DateFormat timeFormat = DateFormat('h:mm a');
  static final DateFormat dbDateFormat = DateFormat('yyyy-MM-dd');

  /// Formats date for task card subtitle: e.g. "Today - 6:00 PM" or "Tomorrow - 10:00 AM" or "Fri, 16 Oct - 4:00 PM"
  static String formatTaskDateTime(DateTime? date, String? time) {
    if (date == null) {
      return time != null && time.isNotEmpty ? time : 'No due time';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    String dateStr;
    final diffDays = target.difference(today).inDays;

    if (diffDays == 0) {
      dateStr = 'Today';
    } else if (diffDays == 1) {
      dateStr = 'Tomorrow';
    } else if (diffDays == -1) {
      dateStr = 'Yesterday';
    } else {
      dateStr = DateFormat('EEE, d MMM').format(date);
    }

    if (time != null && time.isNotEmpty) {
      return '$dateStr - $time';
    } else {
      return dateStr;
    }
  }

  /// Checks if two dates are on the same calendar day
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Returns days of the month grid (including leading padding days from previous month)
  static List<DateTime> getDaysInMonthGrid(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    // 0 = Sunday, 1 = Monday, ... 6 = Saturday (matching UI: Sun, Mon, Tue...)
    // DateTime.weekday: Monday = 1, ... Sunday = 7
    final firstWeekday = firstDay.weekday % 7; // Sunday becomes 0

    final List<DateTime> days = [];

    // Previous month padding
    for (int i = firstWeekday - 1; i >= 0; i--) {
      days.add(firstDay.subtract(Duration(days: i + 1)));
    }

    // Current month days
    for (int i = 0; i < daysInMonth; i++) {
      days.add(DateTime(month.year, month.month, i + 1));
    }

    // Next month padding to fill a complete 35 or 42 grid
    final remaining = (7 - (days.length % 7)) % 7;
    for (int i = 1; i <= remaining; i++) {
      days.add(DateTime(month.year, month.month + 1, i));
    }

    return days;
  }

  /// Deterministically parses natural-language date phrases (e.g. "tomorrow", "next Monday", "in 2 days")
  static DateTime? parseRelativeDate(String phrase, {DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    final lower = phrase.toLowerCase().trim();

    if (lower.contains('today') || lower.contains('tonight')) {
      return DateTime(ref.year, ref.month, ref.day);
    }

    if (lower.contains('tomorrow')) {
      final d = ref.add(const Duration(days: 1));
      return DateTime(d.year, d.month, d.day);
    }

    if (lower.contains('day after tomorrow') || lower.contains('in two days') || lower.contains('in 2 days')) {
      final d = ref.add(const Duration(days: 2));
      return DateTime(d.year, d.month, d.day);
    }

    if (lower.contains('this weekend') || lower.contains('weekend')) {
      // Find upcoming Saturday
      int daysUntilSat = (DateTime.saturday - ref.weekday) % 7;
      if (daysUntilSat == 0) daysUntilSat = 7;
      final d = ref.add(Duration(days: daysUntilSat));
      return DateTime(d.year, d.month, d.day);
    }

    // Weekdays map (Monday: 1, Sunday: 7)
    final weekdays = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };

    for (final entry in weekdays.entries) {
      if (lower.contains(entry.key)) {
        int diff = entry.value - ref.weekday;
        if (lower.contains('next ${entry.key}')) {
          diff += 7;
        } else if (diff <= 0) {
          diff += 7; // Upcoming weekday
        }
        final d = ref.add(Duration(days: diff));
        return DateTime(d.year, d.month, d.day);
      }
    }

    return null;
  }

  /// Deterministically parses time expressions (e.g. "7.00pm", "7:00 PM", "ten a.m.", "10:00 AM", "6 PM", "18:00", "7 tonight", "morning", "evening")
  static String? parseTimeString(String phrase) {
    var lower = phrase.toLowerCase().trim();
    // Normalize trailing punctuation (e.g. "7.00pm." -> "7.00pm")
    lower = lower.replaceAll(RegExp(r'[.,;!]+$'), '');

    // Normalize dotted periods in am/pm
    lower = lower.replaceAll(RegExp(r'\ba\.m\.?\b'), 'am');
    lower = lower.replaceAll(RegExp(r'\bp\.m\.?\b'), 'pm');

    // Number words map
    const numberWords = {
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

    const minuteWords = {
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
    };

    // Fractions: half past <hour> -> <hour>:30
    lower = lower.replaceAllMapped(
      RegExp(r'\bhalf\s+past\s+(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|\d{1,2})\b'),
      (match) {
        final h = numberWords[match[1]!] ?? int.tryParse(match[1]!) ?? 12;
        return '$h:30';
      },
    );
    lower = lower.replaceAllMapped(
      RegExp(r'\bquarter\s+past\s+(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|\d{1,2})\b'),
      (match) {
        final h = numberWords[match[1]!] ?? int.tryParse(match[1]!) ?? 12;
        return '$h:15';
      },
    );
    lower = lower.replaceAllMapped(
      RegExp(r'\bquarter\s+to\s+(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|\d{1,2})\b'),
      (match) {
        final nextH = numberWords[match[1]!] ?? int.tryParse(match[1]!) ?? 1;
        final h = (nextH == 1) ? 12 : (nextH - 1);
        return '$h:45';
      },
    );

    // Word hour + minute word: e.g. "ten thirty" -> "10:30", "six fifteen" -> "6:15"
    final numPattern = numberWords.keys.join('|');
    final minPattern = minuteWords.keys.join('|');
    lower = lower.replaceAllMapped(
      RegExp('\\b($numPattern)\\s+($minPattern)(?:\\s*(am|pm))?\\b'),
      (match) {
        final h = numberWords[match[1]!]!;
        final m = minuteWords[match[2]!.replaceAll(RegExp(r'\s+'), ' ')] ?? '00';
        final ampm = match[3];
        return ampm != null ? '$h:$m $ampm' : '$h:$m';
      },
    );

    // Word hour + am/pm: e.g. "ten am" -> "10:00 am", "ten pm" -> "10:00 pm"
    lower = lower.replaceAllMapped(
      RegExp('\\b($numPattern)\\s*(am|pm)\\b'),
      (match) {
        final h = numberWords[match[1]!]!;
        return '$h:00 ${match[2]}';
      },
    );

    // Word hour + o'clock or context: e.g. "ten o'clock" -> "10:00"
    lower = lower.replaceAllMapped(
      RegExp('\\b($numPattern)\\s*o\\s*\'?\\s*clock\\b'),
      (match) => '${numberWords[match[1]!]}:00',
    );

    // Preposition with word hour: e.g. "at ten", "by seven"
    lower = lower.replaceAllMapped(
      RegExp('\\b(?:at|by|before|for)\\s+($numPattern)\\b'),
      (match) => 'at ${numberWords[match[1]!]}',
    );

    // 1. Time with AM/PM (e.g. "7:00 PM", "7.00pm", "7.00 pm", "7:30am", "7.30 pm", "7pm", "7 am")
    final regexAmPm = RegExp(
      r'(\b\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)\b',
      caseSensitive: false,
    );
    final matchAmPm = regexAmPm.firstMatch(lower);

    if (matchAmPm != null) {
      int hour = int.parse(matchAmPm.group(1)!);
      final minute = matchAmPm.group(2) ?? '00';
      final period = matchAmPm.group(3)!.toUpperCase();

      if (hour >= 1 && hour <= 12) {
        return '$hour:$minute $period';
      }
    }

    // 2. Time with context words (e.g. "7 tonight", "by 7 in the evening", "at 7 in the morning", "7:00 tonight", "7.00 tonight")
    final regexWithContext = RegExp(
      r'\b(?:at|by|for|before)?\s*(\d{1,2})(?:[:.](\d{2}))?\s*(?:in the\s+)?(morning|afternoon|evening|night|tonight)\b',
      caseSensitive: false,
    );
    final matchContext = regexWithContext.firstMatch(lower);
    if (matchContext != null) {
      int hour = int.parse(matchContext.group(1)!);
      final minute = matchContext.group(2) ?? '00';
      final contextWord = matchContext.group(3)!.toLowerCase();

      final period = contextWord == 'morning' ? 'AM' : 'PM';

      if (hour >= 1 && hour <= 12) {
        return '$hour:$minute $period';
      } else if (hour >= 13 && hour <= 23) {
        int hour12 = hour % 12;
        if (hour12 == 0) hour12 = 12;
        return '$hour12:$minute PM';
      }
    }

    // 3. 24-hour format like "18:00", "18.00", "09:30", "14:15", "19.00"
    final regex24 = RegExp(r'\b(\d{1,2})[:.](\d{2})\b');
    final match24 = regex24.firstMatch(lower);
    if (match24 != null) {
      int hour = int.parse(match24.group(1)!);
      int minute = int.parse(match24.group(2)!);
      if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
        if (hour >= 13) {
          final hour12 = hour - 12;
          final minuteStr = minute.toString().padLeft(2, '0');
          return '$hour12:$minuteStr PM';
        } else if (hour == 12) {
          final minuteStr = minute.toString().padLeft(2, '0');
          return '12:$minuteStr PM';
        } else if (hour == 0) {
          final minuteStr = minute.toString().padLeft(2, '0');
          return '12:$minuteStr AM';
        } else {
          final isPm = lower.contains('tonight') ||
              lower.contains('evening') ||
              lower.contains('night') ||
              lower.contains('afternoon') ||
              lower.contains('pm');
          final isAm = lower.contains('morning') || lower.contains('am');
          final period = isAm ? 'AM' : (isPm ? 'PM' : (hour >= 7 && hour <= 11 ? 'PM' : 'PM'));
          final minuteStr = minute.toString().padLeft(2, '0');
          return '$hour:$minuteStr $period';
        }
      }
    }

    // 4. Preposition with hour (e.g. "at 7", "by 7", "for 7", "before 7")
    final regexPrep = RegExp(r'\b(?:at|by|before|for)\s+(\d{1,2})\b', caseSensitive: false);
    final matchPrep = regexPrep.firstMatch(lower);
    if (matchPrep != null) {
      int hour = int.parse(matchPrep.group(1)!);
      if (hour >= 1 && hour <= 12) {
        final isPm = lower.contains('tonight') ||
            lower.contains('evening') ||
            lower.contains('night') ||
            lower.contains('afternoon') ||
            lower.contains('pm');
        final isAm = lower.contains('morning') || lower.contains('am');
        final period = isAm ? 'AM' : (isPm ? 'PM' : 'PM');
        return '$hour:00 $period';
      }
    }

    // 5. Day part heuristics ONLY when no number was found
    if (lower.contains('morning')) return '9:00 AM';
    if (lower.contains('noon') || lower.contains('lunch')) return '12:00 PM';
    if (lower.contains('afternoon')) return '2:00 PM';
    if (lower.contains('evening')) return '6:00 PM';
    if (RegExp(r'\btonight\b').hasMatch(lower)) return '8:00 PM';
    if (RegExp(r'(?<!to)\bnight\b').hasMatch(lower)) return '9:00 PM';

    return null;
  }
}
