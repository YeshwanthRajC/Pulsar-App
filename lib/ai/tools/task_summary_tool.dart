import 'base_tool.dart';
import '../../data/repositories/task_repository.dart';

class TaskSummaryTool extends BaseTool {
  @override
  String get name => 'task_summary';

  @override
  String get description =>
      'Generates a statistical summary and completion rate of tasks over a timeframe (e.g. today, this_week, last_3_days, this_month).';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'period': {
            'type': 'string',
            'description':
                'Timeframe for the summary: today, this_week, last_week, last_3_days, this_month, all.',
          },
        },
        'required': ['period'],
      };

  @override
  Future<ActionResult> execute({
    required Map<String, dynamic> arguments,
    required TaskRepository repository,
  }) async {
    final period = arguments['period'] as String? ?? 'today';
    final stats = await repository.getTaskStatsOverPeriod(period);
    final tasks = await repository.getTasksForPeriod(period);

    final total = stats['total'] as int? ?? 0;
    final completed = stats['completed'] as int? ?? 0;
    final pending = stats['pending'] as int? ?? 0;
    final overdue = stats['overdue'] as int? ?? 0;
    final rate = stats['completionRate'] as int? ?? 0;

    final periodLabel = period.replaceAll('_', ' ');

    final summary = StringBuffer();
    summary.writeln('📊 Summary for $periodLabel:');
    summary.writeln('• Total: $total | Completed: $completed ($rate%)');
    summary.writeln('• Pending: $pending | Overdue: $overdue');

    return ActionResult.tasksRetrieved(
      summary.toString().trim(),
      tasks,
      toolName: name,
    );
  }
}
