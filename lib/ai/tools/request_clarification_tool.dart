import 'base_tool.dart';
import '../../data/repositories/task_repository.dart';

class RequestClarificationTool extends BaseTool {
  @override
  String get name => 'request_clarification';

  @override
  String get description =>
      'Invoked when a user command has ambiguous or missing details (e.g. no due time for a reminder, ambiguous target).';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'question': {
            'type': 'string',
            'description': 'The targeted question to ask the user.',
          },
          'ambiguousField': {
            'type': 'string',
            'enum': ['title', 'date', 'time', 'reminder', 'target'],
            'description': 'The specific parameter that requires clarification.',
          },
          'pendingTitle': {
            'type': 'string',
            'description': 'The title of the pending task, if known.',
          },
        },
        'required': ['question', 'ambiguousField'],
      };

  @override
  Future<ActionResult> execute({
    required Map<String, dynamic> arguments,
    required TaskRepository repository,
  }) async {
    final question = arguments['question'] as String? ??
        'Could you clarify the details for this task?';
    final ambiguousField =
        arguments['ambiguousField'] as String? ?? 'general';
    final pendingTitle = arguments['pendingTitle'] as String? ??
        arguments['title'] as String?;

    return ActionResult.clarificationNeeded(
      question: question,
      ambiguousField: ambiguousField,
      pendingTitle: pendingTitle,
      toolName: name,
    );
  }
}
