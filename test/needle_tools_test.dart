import 'package:flutter_test/flutter_test.dart';
import 'package:pulsar/ai/tools/retrieve_tasks_tool.dart';
import 'package:pulsar/ai/tools/update_task_tool.dart';
import 'package:pulsar/ai/tools/delete_task_tool.dart';
import 'package:pulsar/ai/tools/create_task_tool.dart';
import 'package:pulsar/ai/needle_intent_parser.dart';
import 'package:pulsar/models/task_model.dart';
import 'package:pulsar/data/repositories/task_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Needle Tool Calling & Relative Days Tests', () {
    late TaskRepository repository;
    late RetrieveTasksTool retrieveTool;

    setUp(() async {
      repository = TaskRepository();
      retrieveTool = RetrieveTasksTool();
      await repository.clearAll();
    });

    tearDown(() async {
      await repository.clearAll();
    });

    test('Correctly retrieves tasks completed in the last 3 days', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final twoDaysAgo = today.subtract(const Duration(days: 2));
      final tenDaysAgo = today.subtract(const Duration(days: 10));

      // 1. Task completed 2 days ago (within last 3 days)
      final task1Created = await repository.createTask(
        Task(
          title: 'Finish lab report',
          dueDate: twoDaysAgo,
          isCompleted: false,
        ),
      );
      await repository.updateTask(
        task1Created.copyWith(
          isCompleted: true,
          completedAt: twoDaysAgo,
        ),
      );

      // 2. Task completed 10 days ago (outside last 3 days)
      final task2Created = await repository.createTask(
        Task(
          title: 'Old midterm study',
          dueDate: tenDaysAgo,
          isCompleted: false,
        ),
      );
      await repository.updateTask(
        task2Created.copyWith(
          isCompleted: true,
          completedAt: tenDaysAgo,
        ),
      );

      // 3. Task pending today (within last 3 days but pending)
      await repository.createTask(
        Task(
          title: 'Buy groceries',
          dueDate: today,
          isCompleted: false,
        ),
      );

      // Test parsing of natural query
      final parsed = NeedleIntentParser.parse(
        'what are all the tasks he completed in the last 3 days',
      );
      expect(parsed.actionName, equals('retrieve_tasks'));
      expect(parsed.arguments['filter'], equals('last_3_days'));
      expect(parsed.arguments['status'], equals('completed'));

      // Execute tool
      final result = await retrieveTool.execute(
        arguments: parsed.arguments,
        repository: repository,
      );

      expect(result.success, isTrue);
      expect(result.data, isA<List>());
      final retrievedTasks = result.data as List;
      expect(retrievedTasks.length, equals(1));
      expect(retrievedTasks.first.title, equals('Finish lab report'));
      expect(result.message, contains('Found 1 completed task for the last 3 days:'));
      expect(result.message, contains('✓ Finish lab report'));
    });

    test('RetrieveTasksTool handles empty results cleanly', () async {
      final result = await retrieveTool.execute(
        arguments: {'filter': 'last_3_days', 'status': 'completed'},
        repository: repository,
      );

      expect(result.success, isTrue);
      expect(result.message, contains('No completed tasks found for the last 3 days.'));
      expect((result.data as List).isEmpty, isTrue);
    });

    test('UpdateTaskTool marks task as completed', () async {
      final task = await repository.createTask(
        Task(title: 'Call Mom', isCompleted: false),
      );

      final updateTool = UpdateTaskTool();
      final result = await updateTool.execute(
        arguments: {'target': 'Call Mom', 'isCompleted': true},
        repository: repository,
      );

      expect(result.success, isTrue);
      expect(result.message, contains('marked as completed'));
      final updated = await repository.getTaskById(task.id!);
      expect(updated!.isCompleted, isTrue);
    });

    test('DeleteTaskTool removes task from database', () async {
      final task = await repository.createTask(
        Task(title: 'Trash task', isCompleted: false),
      );

      final deleteTool = DeleteTaskTool();
      final result = await deleteTool.execute(
        arguments: {'target': 'Trash task'},
        repository: repository,
      );

      expect(result.success, isTrue);
      expect(result.message, contains('Deleted task "Trash task"'));
      final found = await repository.getTaskById(task.id!);
      expect(found, isNull);
    });

    test('CreateTaskTool stages task cleanly', () async {
      final createTool = CreateTaskTool();
      final result = await createTool.execute(
        arguments: {
          'tasks': [
            {
              'title': 'Read chapter 4',
              'dueDate': 'tomorrow',
              'dueTime': '6:00 PM',
              'hasReminder': true,
            }
          ]
        },
        repository: repository,
      );

      expect(result.success, isTrue);
      expect(result.message, contains('Staged 1 task'));
      final staged = result.data as List<Task>;
      expect(staged.first.title, equals('Read chapter 4'));
      expect(staged.first.hasReminder, isTrue);
    });
  });
}
