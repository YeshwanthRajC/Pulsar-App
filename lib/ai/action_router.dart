import 'dart:convert';
import 'needle_intent_parser.dart';
import '../data/repositories/task_repository.dart';
import 'tools/base_tool.dart';
import 'tools/retrieve_tasks_tool.dart';
import 'tools/create_task_tool.dart';
import 'tools/update_task_tool.dart';
import 'tools/delete_task_tool.dart';
import 'tools/request_clarification_tool.dart';
import 'tools/task_summary_tool.dart';

/// The Action Router provides strict boundary control over what the AI can do.
/// Instead of giving the Cactus Needle model free rein over device state or SQLite,
/// the model must produce a structured Tool Call which is validated and executed here.
class ActionRouter {
  final TaskRepository repository;
  final Map<String, BaseTool> _actionRegistry = {};

  ActionRouter({required this.repository}) {
    _register(RetrieveTasksTool());
    _register(CreateTaskTool());
    _register(UpdateTaskTool());
    _register(DeleteTaskTool());
    _register(RequestClarificationTool());
    _register(TaskSummaryTool());
  }

  void _register(BaseAction action) {
    _actionRegistry[action.name] = action;
  }

  /// Tool schemas handed to Needle as JSON. Needle works best with flat,
  /// small schemas (<= 5 tools): one tool per action, one call per task.
  /// Execution never happens inside the model; the calls it returns are
  /// validated and run by the Action Modules below.
  String buildNeedleToolsJson() {
    final tools = <Map<String, dynamic>>[
      {
        'name': 'create_task',
        'description':
            'Create ONE task or reminder. Call it once per task when the user asks for several.',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {
              'type': 'string',
              'description': 'Short task title, without the date or time words.',
            },
            'dueDate': {
              'type': 'string',
              'description':
                  'Date phrase exactly as said, e.g. tomorrow, friday, next monday. Omit if not said.',
            },
            'dueTime': {
              'type': 'string',
              'description': 'Time as said, e.g. 6 PM or 10:30 AM. Omit if not said.',
            },
            'hasReminder': {
              'type': 'boolean',
              'description': 'True if the user asked to be reminded.',
            },
          },
          'required': ['title'],
        },
      },
      _toolFor('retrieve_tasks'),
      _toolFor('update_task'),
      _toolFor('delete_task'),
    ];
    return jsonEncode(tools);
  }

  Map<String, dynamic> _toolFor(String name) {
    final a = _actionRegistry[name]!;
    return {
      'name': a.name,
      'description': a.description,
      'parameters': a.parametersSchema,
    };
  }

  /// Maps Needle's `function_calls` into a single dispatchable request.
  /// Several create_task calls are merged into one staged multi-task review.
  ToolCallRequest? requestFromNeedleCalls(List<dynamic> calls) {
    final parsed = <Map<String, dynamic>>[];
    for (final c in calls) {
      if (c is! Map) continue;
      final name = c['name'];
      final args = c['arguments'];
      if (name is! String || !_actionRegistry.containsKey(name)) continue;
      parsed.add({
        'name': name,
        'arguments': args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{},
      });
    }
    if (parsed.isEmpty) return null;

    final creates = parsed.where((c) => c['name'] == 'create_task').toList();
    if (creates.isNotEmpty && creates.length == parsed.length) {
      return ToolCallRequest(
        actionName: 'create_task',
        arguments: {
          'tasks': creates.map((c) => c['arguments']).toList(),
        },
      );
    }
    final first = parsed.first;
    return ToolCallRequest(
      actionName: first['name'] as String,
      arguments: first['arguments'] as Map<String, dynamic>,
    );
  }

  /// Direct execution of a tool call
  Future<ActionResult> executeAction({
    required String actionName,
    required Map<String, dynamic> arguments,
  }) async {
    final action = _actionRegistry[actionName];
    if (action == null) {
      return ActionResult.error('Action module "$actionName" is not recognized.');
    }

    try {
      return await action.execute(
        arguments: arguments,
        repository: repository,
      );
    } catch (e) {
      return ActionResult.error('Failed executing action $actionName: $e');
    }
  }

  List<BaseAction> get registeredActions => _actionRegistry.values.toList();
}
