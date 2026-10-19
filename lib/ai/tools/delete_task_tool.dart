import 'base_tool.dart';
import '../../data/repositories/task_repository.dart';

class DeleteTaskTool extends BaseTool {
  @override
  String get name => 'delete_task';

  @override
  String get description =>
      'Deletes a task by matching title keywords or ID from the SQLite database.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'target': {
            'type': 'string',
            'description': 'The title keywords or ID of the task to delete.',
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
        question: 'Which task would you like to delete?',
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
        'Could not find any task matching "$target" to delete.',
        toolName: name,
      );
    }

    if (matches.length > 1) {
      return ActionResult.clarificationNeeded(
        question:
            'Multiple tasks match "$target": ${matches.map((m) => m.title).join(", ")}. Which one do you want to delete?',
        ambiguousField: 'target',
        toolName: name,
      );
    }

    final task = matches.first;
    await repository.deleteTask(task.id!);

    return ActionResult.taskDeleted(
      'Deleted task "${task.title}".',
      task,
      toolName: name,
    );
  }
}
