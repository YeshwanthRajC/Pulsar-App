import '../../data/repositories/task_repository.dart';

enum ActionResultType {
  tasksRetrieved,
  tasksStagedForConfirmation,
  taskUpdated,
  taskDeleted,
  clarificationNeeded,
  error,
}

class ActionResult {
  final ActionResultType type;
  final bool success;
  final String message;
  final dynamic data;
  final String? toolName;

  ActionResult({
    required this.type,
    required this.success,
    required this.message,
    this.data,
    this.toolName,
  });

  factory ActionResult.tasksRetrieved(
    String summary,
    dynamic tasks, {
    String toolName = 'retrieve_tasks',
  }) {
    return ActionResult(
      type: ActionResultType.tasksRetrieved,
      success: true,
      message: summary,
      data: tasks,
      toolName: toolName,
    );
  }

  factory ActionResult.stagedForReview({
    required String message,
    required List<dynamic> stagedTasks,
    String toolName = 'create_task',
  }) {
    return ActionResult(
      type: ActionResultType.tasksStagedForConfirmation,
      success: true,
      message: message,
      data: stagedTasks,
      toolName: toolName,
    );
  }

  factory ActionResult.clarificationNeeded({
    required String question,
    required String ambiguousField,
    String? pendingTitle,
    String toolName = 'request_clarification',
  }) {
    return ActionResult(
      type: ActionResultType.clarificationNeeded,
      success: false,
      message: question,
      data: {
        'field': ambiguousField,
        'question': question,
        'title': pendingTitle,
      },
      toolName: toolName,
    );
  }

  factory ActionResult.taskUpdated(
    String message,
    dynamic task, {
    String toolName = 'update_task',
  }) {
    return ActionResult(
      type: ActionResultType.taskUpdated,
      success: true,
      message: message,
      data: task,
      toolName: toolName,
    );
  }

  factory ActionResult.taskDeleted(
    String message,
    dynamic task, {
    String toolName = 'delete_task',
  }) {
    return ActionResult(
      type: ActionResultType.taskDeleted,
      success: true,
      message: message,
      data: task,
      toolName: toolName,
    );
  }

  factory ActionResult.error(String error, {String? toolName}) {
    return ActionResult(
      type: ActionResultType.error,
      success: false,
      message: error,
      toolName: toolName,
    );
  }
}

/// Abstract base class for all Needle Tools.
/// Needle operates as a structured tool calling & data extraction engine.
/// It selects and validates discrete tool calls rather than freeform text chatting.
abstract class BaseTool {
  String get name;
  String get description;
  Map<String, dynamic> get parametersSchema;

  Future<ActionResult> execute({
    required Map<String, dynamic> arguments,
    required TaskRepository repository,
  });
}

/// Alias for backwards compatibility with legacy action terminology
typedef BaseAction = BaseTool;
