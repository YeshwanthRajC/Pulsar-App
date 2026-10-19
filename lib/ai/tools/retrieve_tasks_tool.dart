import 'base_tool.dart';
import '../../data/repositories/task_repository.dart';
import '../../models/task_model.dart';

class RetrieveTasksTool extends BaseTool {
  @override
  String get name => 'retrieve_tasks';

  @override
  String get description =>
      'Queries tasks from the SQLite database based on timeframes (e.g. today, tomorrow, yesterday, this_week, last_week, last_3_days, last_N_days, this_month), status (completed, pending, overdue, all), or keyword search.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'filter': {
            'type': 'string',
            'description':
                'Timeframe or category: today, tomorrow, yesterday, this_week, next_week, last_week, this_month, last_3_days, last_N_days, past_3_days, weekend, upcoming, pending, completed, overdue, or all.',
          },
          'status': {
            'type': 'string',
            'enum': ['all', 'pending', 'completed', 'overdue'],
            'description': 'Optional status filter, e.g. completed, pending, overdue.',
          },
          'keyword': {
            'type': 'string',
            'description': 'Optional search keyword to match task title or description.',
          },
          'days': {
            'type': 'integer',
            'description': 'Optional number of days for relative range (e.g. 3 for last 3 days).',
          },
        },
        'required': ['filter'],
      };

  @override
  Future<ActionResult> execute({
    required Map<String, dynamic> arguments,
    required TaskRepository repository,
  }) async {
    var rawFilter = (arguments['filter'] as String? ?? 'today').trim();
    final status = arguments['status'] as String?;
    final keyword = arguments['keyword'] as String?;
    final days = arguments['days'] as int?;

    // If explicit day count was provided, ensure filter reflects it
    if (days != null && days > 0 && !rawFilter.contains('_days')) {
      rawFilter = 'last_${days}_days';
    }

    final List<Task> tasks = await repository.getTasksForPeriod(
      rawFilter,
      status: status,
      keyword: keyword,
    );

    final readableFilter = _formatReadablePeriod(rawFilter);
    final statusDescriptor = (status != null && status != 'all') ? '$status ' : '';

    if (tasks.isEmpty) {
      final extra = keyword != null ? ' matching "$keyword"' : '';
      return ActionResult.tasksRetrieved(
        'No ${statusDescriptor}tasks found for $readableFilter$extra.',
        tasks,
        toolName: name,
      );
    }

    final total = tasks.length;
    final completed = tasks.where((t) => t.isCompleted).length;
    final pending = total - completed;

    final summaryBuffer = StringBuffer();
    if (total == 1) {
      summaryBuffer.writeln('Found 1 ${statusDescriptor}task for $readableFilter:');
    } else {
      if (status == 'completed') {
        summaryBuffer.writeln('Found $total completed tasks for $readableFilter:');
      } else if (status == 'pending') {
        summaryBuffer.writeln('Found $total pending tasks for $readableFilter:');
      } else {
        summaryBuffer.writeln(
          'Found $total tasks for $readableFilter ($pending pending, $completed completed):',
        );
      }
    }

    for (int i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      final statusStr = t.isCompleted ? '✓' : '•';
      final timeStr = t.dueTime != null ? ' at ${t.dueTime}' : '';
      final dateStr = t.dueDate != null
          ? ' (${t.dueDate!.year}-${t.dueDate!.month.toString().padLeft(2, '0')}-${t.dueDate!.day.toString().padLeft(2, '0')})'
          : '';
      final reminderStr = t.hasReminder ? ' 🔔' : '';
      summaryBuffer.writeln('$statusStr ${t.title}$timeStr$dateStr$reminderStr');
    }

    return ActionResult.tasksRetrieved(
      summaryBuffer.toString().trim(),
      tasks,
      toolName: name,
    );
  }

  String _formatReadablePeriod(String period) {
    final norm = period.toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), '_');
    
    final daysMatch = RegExp(r'^(?:last|past)_(\d+)_days?$').firstMatch(norm);
    if (daysMatch != null) {
      return 'the last ${daysMatch.group(1)} days';
    }

    final nextDaysMatch = RegExp(r'^next_(\d+)_days?$').firstMatch(norm);
    if (nextDaysMatch != null) {
      return 'the next ${nextDaysMatch.group(1)} days';
    }

    switch (norm) {
      case 'this_week':
      case 'week':
        return 'this week';
      case 'next_week':
        return 'next week';
      case 'last_week':
        return 'last week';
      case 'this_month':
      case 'month':
        return 'this month';
      case 'next_month':
        return 'next month';
      case 'this_weekend':
      case 'weekend':
        return 'this weekend';
      case 'upcoming':
        return 'upcoming';
      case 'yesterday':
        return 'yesterday';
      case 'tomorrow':
        return 'tomorrow';
      case 'today':
        return 'today';
      case 'overdue':
        return 'overdue';
      case 'completed':
        return 'completed';
      case 'pending':
        return 'pending';
      default:
        return period.replaceAll('_', ' ');
    }
  }
}
