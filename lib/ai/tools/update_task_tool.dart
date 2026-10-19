import 'base_tool.dart';
import '../../data/repositories/task_repository.dart';
import '../../core/utils/date_utils.dart';

class UpdateTaskTool extends BaseTool {
  @override
  String get name => 'update_task';

  @override
  String get description =>
      'Updates an existing task in the database: mark as completed/done, reschedule date/time, or change task title.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'target': {
            'type': 'string',
            'description': 'The title keywords or ID of the task to update.',
          },
          'newTitle': {
            'type': 'string',
            'description': 'New title ONLY if the user explicitly asked to rename the task.',
          },
          'newDate': {
            'type': 'string',
            'description': 'New due date phrase if rescheduling (e.g. tomorrow).',
          },
          'newTime': {
            'type': 'string',
            'description': 'New due time if changing time (e.g. 5 PM).',
          },
          'isCompleted': {
            'type': 'boolean',
            'description': 'Set true when marking a task as done, finished, or completed.',
          },
        },
        'required': ['target'],
      };

  @override
  Future<ActionResult> execute({
    required Map<String, dynamic> arguments,
    required TaskRepository repository,
  }) async {
    final target = (arguments['target'] as String? ?? '').toLowerCase().trim();
    if (target.isEmpty) {
      return ActionResult.clarificationNeeded(
        question: 'Which task would you like to update?',
        ambiguousField: 'target',
        toolName: name,
      );
    }

    final allTasks = await repository.getAllTasks();
    final matches = allTasks.where((t) {
      if (t.id.toString() == target) return true;
      return t.title.toLowerCase().contains(target);
    }).toList();

    if (matches.isEmpty) {
      return ActionResult.error(
        'Could not find any task matching "$target".',
        toolName: name,
      );
    }

    if (matches.length > 1) {
      return ActionResult.clarificationNeeded(
        question:
            'Multiple tasks match "$target": ${matches.map((m) => m.title).join(", ")}. Which one would you like to update?',
        ambiguousField: 'target',
        toolName: name,
      );
    }

    final task = matches.first;
    DateTime? newDate = task.dueDate;
    if (arguments['newDate'] != null) {
      newDate = AppDateUtils.parseRelativeDate(arguments['newDate'] as String);
    }

    String? newTime = task.dueTime;
    if (arguments['newTime'] != null) {
      newTime = AppDateUtils.parseTimeString(arguments['newTime'] as String);
    }

    final isCompletedArg = arguments['isCompleted'] as bool?;
    final newIsCompleted = isCompletedArg ?? task.isCompleted;
    final completedAt = newIsCompleted
        ? (task.completedAt ?? DateTime.now())
        : null;

    final updated = task.copyWith(
      title: arguments['newTitle'] as String? ?? task.title,
      dueDate: newDate,
      dueTime: newTime,
      isCompleted: newIsCompleted,
      completedAt: completedAt,
    );

    await repository.updateTask(updated);

    final statusChange = (isCompletedArg != null && isCompletedArg != task.isCompleted)
        ? (newIsCompleted ? ' marked as completed ✓' : ' marked as pending')
        : ' updated';

    return ActionResult.taskUpdated(
      'Task "${updated.title}"$statusChange.',
      updated,
      toolName: name,
    );
  }
}
