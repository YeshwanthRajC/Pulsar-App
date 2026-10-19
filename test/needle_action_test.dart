import 'package:flutter_test/flutter_test.dart';
import 'package:pulsar/ai/needle_intent_parser.dart';
import 'package:pulsar/ai/action_router.dart';
import 'package:pulsar/data/repositories/task_repository.dart';
import 'package:pulsar/services/voice_enhancement_service.dart';
import 'package:pulsar/core/utils/date_utils.dart';

void main() {
  group('Needle Intent Parser Fallback Tests', () {
    test('Correctly extracts task with relative date and time', () {
      final request = NeedleIntentParser.parse(
        'Remind me to finish my Java assignment tomorrow at 6 PM',
      );

      expect(request.actionName, equals('create_task'));
      final tasks = request.arguments['tasks'] as List<dynamic>;
      expect(tasks.length, equals(1));

      final task = tasks.first as Map<String, dynamic>;
      expect(task['title'], contains('Java assignment'));
      expect(task['dueTime'], equals('6:00 PM'));
      expect(task['hasReminder'], isTrue);
    });

    test('Correctly extracts task with dot time notation (7.00pm)', () {
      final request = NeedleIntentParser.parse(
        'Call mom by 7.00pm',
      );

      expect(request.actionName, equals('create_task'));
      final tasks = request.arguments['tasks'] as List<dynamic>;
      expect(tasks.length, equals(1));

      final task = tasks.first as Map<String, dynamic>;
      expect(task['title'], equals('Call mom'));
      expect(task['dueTime'], equals('7:00 PM'));
      expect(task['hasReminder'], isTrue);
    });

    test('Correctly extracts task with space dot notation (7.00 pm)', () {
      final request = NeedleIntentParser.parse(
        'Call mom by 7.00 pm',
      );

      expect(request.actionName, equals('create_task'));
      final tasks = request.arguments['tasks'] as List<dynamic>;
      expect(tasks.length, equals(1));

      final task = tasks.first as Map<String, dynamic>;
      expect(task['title'], equals('Call mom'));
      expect(task['dueTime'], equals('7:00 PM'));
    });

    test('Correctly extracts task with trailing dot and hour (Call mom by 7.)', () {
      final request = NeedleIntentParser.parse(
        'Call mom by 7.',
      );

      expect(request.actionName, equals('create_task'));
      final tasks = request.arguments['tasks'] as List<dynamic>;
      expect(tasks.length, equals(1));

      final task = tasks.first as Map<String, dynamic>;
      expect(task['title'], equals('Call mom'));
      expect(task['dueTime'], equals('7:00 PM'));
    });

    test('Correctly extracts task with tonight context (Call mom by 7 tonight)', () {
      final request = NeedleIntentParser.parse(
        'Call mom by 7 tonight',
      );

      expect(request.actionName, equals('create_task'));
      final tasks = request.arguments['tasks'] as List<dynamic>;
      expect(tasks.length, equals(1));

      final task = tasks.first as Map<String, dynamic>;
      expect(task['title'], equals('Call mom'));
      expect(task['dueTime'], equals('7:00 PM'));
      expect(task['dueDate'], equals('tonight'));
    });

    test('Maps query question to retrieve_tasks Action Module', () {
      final request = NeedleIntentParser.parse(
        'What are all the tasks for today?',
      );

      expect(request.actionName, equals('retrieve_tasks'));
      expect(request.arguments['filter'], equals('today'));
    });

    test('Maps timeframe query for this week to retrieve_tasks', () {
      final request = NeedleIntentParser.parse(
        'What tasks do I have scheduled for this week?',
      );

      expect(request.actionName, equals('retrieve_tasks'));
      expect(request.arguments['filter'], equals('this_week'));
    });

    test('Maps query for completed tasks yesterday', () {
      final request = NeedleIntentParser.parse(
        'What did I complete yesterday?',
      );

      expect(request.actionName, equals('retrieve_tasks'));
      expect(request.arguments['filter'], equals('yesterday'));
      expect(request.arguments['status'], equals('completed'));
    });

    test('Maps query for overdue tasks', () {
      final request = NeedleIntentParser.parse(
        'Show me all overdue tasks',
      );

      expect(request.actionName, equals('retrieve_tasks'));
      expect(request.arguments['filter'], equals('overdue'));
    });

    test('Splits compound command into multiple tasks', () {
      final request = NeedleIntentParser.parse(
        'Buy groceries at 5 PM and call Mom at 7 PM',
      );

      expect(request.actionName, equals('create_task'));
      final tasks = request.arguments['tasks'] as List<dynamic>;
      expect(tasks.length, equals(2));

      expect(tasks[0]['title'], contains('Buy groceries'));
      expect(tasks[0]['dueTime'], equals('5:00 PM'));

      expect(tasks[1]['title'], contains('Call Mom'));
      expect(tasks[1]['dueTime'], equals('7:00 PM'));
    });

    test('Requests clarification when reminder has no date or time', () {
      final request = NeedleIntentParser.parse(
        'Remind me to call teammate',
      );

      // Never invent missing dates or times; ask user for clarification
      expect(request.actionName, equals('request_clarification'));
      expect(request.arguments['ambiguousField'], equals('time'));
    });

    test('Maps delete command to delete_task Action Module', () {
      final request = NeedleIntentParser.parse(
        'Delete task complete Java assignment',
      );

      expect(request.actionName, equals('delete_task'));
      expect(request.arguments['target'], contains('Java assignment'));
    });

    test('Maps "what are all the tasks he completed in the last 3 days" to retrieve_tasks tool call', () {
      final request = NeedleIntentParser.parse(
        'what are all the tasks he completed in the last 3 days',
      );

      expect(request.actionName, equals('retrieve_tasks'));
      expect(request.arguments['filter'], equals('last_3_days'));
      expect(request.arguments['status'], equals('completed'));
    });

    test('Maps "what tasks did I finish in the past 5 days" to retrieve_tasks tool call', () {
      final request = NeedleIntentParser.parse(
        'what tasks did I finish in the past 5 days',
      );

      expect(request.actionName, equals('retrieve_tasks'));
      expect(request.arguments['filter'], equals('last_5_days'));
      expect(request.arguments['status'], equals('completed'));
    });

    test('Maps "mark call Mom as completed" to update_task tool call', () {
      final request = NeedleIntentParser.parse(
        'mark call Mom as completed',
      );

      expect(request.actionName, equals('update_task'));
      expect(request.arguments['target'], equals('call Mom'));
      expect(request.arguments['isCompleted'], isTrue);
    });
  });

  group('ActionRouter requestFromNeedleCalls Tests', () {
    late ActionRouter router;

    setUp(() {
      router = ActionRouter(repository: TaskRepository());
    });

    test('Maps single create_task call', () {
      final calls = [
        {
          'name': 'create_task',
          'arguments': {
            'title': 'Call Mom',
            'dueDate': 'tomorrow',
            'dueTime': '6 PM',
            'hasReminder': true,
          },
        }
      ];

      final request = router.requestFromNeedleCalls(calls);
      expect(request, isNotNull);
      expect(request!.actionName, equals('create_task'));
      final tasks = request.arguments['tasks'] as List<dynamic>;
      expect(tasks.length, equals(1));
      expect(tasks[0]['title'], equals('Call Mom'));
      expect(tasks[0]['dueDate'], equals('tomorrow'));
      expect(tasks[0]['dueTime'], equals('6 PM'));
      expect(tasks[0]['hasReminder'], isTrue);
    });

    test('Merges multiple create_task calls into staged multi-task request', () {
      final calls = [
        {
          'name': 'create_task',
          'arguments': {
            'title': 'Buy groceries',
            'dueTime': '5 PM',
          },
        },
        {
          'name': 'create_task',
          'arguments': {
            'title': 'Call Mom',
            'dueTime': '7 PM',
          },
        },
      ];

      final request = router.requestFromNeedleCalls(calls);
      expect(request, isNotNull);
      expect(request!.actionName, equals('create_task'));
      final tasks = request.arguments['tasks'] as List<dynamic>;
      expect(tasks.length, equals(2));
      expect(tasks[0]['title'], equals('Buy groceries'));
      expect(tasks[0]['dueTime'], equals('5 PM'));
      expect(tasks[1]['title'], equals('Call Mom'));
      expect(tasks[1]['dueTime'], equals('7 PM'));
    });

    test('Maps retrieve_tasks call', () {
      final calls = [
        {
          'name': 'retrieve_tasks',
          'arguments': {'filter': 'today'},
        }
      ];

      final request = router.requestFromNeedleCalls(calls);
      expect(request, isNotNull);
      expect(request!.actionName, equals('retrieve_tasks'));
      expect(request.arguments['filter'], equals('today'));
    });

    test('Maps update_task call', () {
      final calls = [
        {
          'name': 'update_task',
          'arguments': {
            'target': 'finish Java assignment',
            'completed': true,
          },
        }
      ];

      final request = router.requestFromNeedleCalls(calls);
      expect(request, isNotNull);
      expect(request!.actionName, equals('update_task'));
      expect(request.arguments['target'], equals('finish Java assignment'));
      expect(request.arguments['completed'], isTrue);
    });

    test('Maps delete_task call', () {
      final calls = [
        {
          'name': 'delete_task',
          'arguments': {'target': 'old homework'},
        }
      ];

      final request = router.requestFromNeedleCalls(calls);
      expect(request, isNotNull);
      expect(request!.actionName, equals('delete_task'));
      expect(request.arguments['target'], equals('old homework'));
    });

    test('Returns null for empty calls', () {
      final request = router.requestFromNeedleCalls([]);
      expect(request, isNull);
    });

    test('Returns null for unregistered tool calls', () {
      final calls = [
        {
          'name': 'unregistered_tool',
          'arguments': {'foo': 'bar'},
        }
      ];

      final request = router.requestFromNeedleCalls(calls);
      expect(request, isNull);
    });

    test('Ignores malformed entries and processes valid ones', () {
      final calls = [
        'invalid entry',
        123,
        {
          'name': 'delete_task',
          'arguments': {'target': 'clean desk'},
        },
      ];

      final request = router.requestFromNeedleCalls(calls);
      expect(request, isNotNull);
      expect(request!.actionName, equals('delete_task'));
      expect(request.arguments['target'], equals('clean desk'));
    });
  });

  group('VoiceEnhancementService Whistle Refinement Tests', () {
    final service = VoiceEnhancementService.instance;

    test('Refines "Set an alarm for tomorrow ten a.m. to go to Temple."', () {
      final refined = service.postProcessTranscript(
        'Set an alarm for tomorrow ten a.m. to go to Temple.',
      );
      expect(refined, equals('Remind me to go to Temple tomorrow at 10:00 AM'));
    });

    test('Refines "Set an alarm for tomorrow 10 a.m. to go to Temple"', () {
      final refined = service.postProcessTranscript(
        'Set an alarm for tomorrow 10 a.m. to go to Temple',
      );
      expect(refined, equals('Remind me to go to Temple tomorrow at 10:00 AM'));
    });

    test('Refines "Wake me up tomorrow at 7 a.m. to study DSA"', () {
      final refined = service.postProcessTranscript(
        'Wake me up tomorrow at 7 a.m. to study DSA',
      );
      expect(refined, equals('Remind me to study DSA tomorrow at 7:00 AM'));
    });

    test('Refines word numbers and minutes (ten thirty a.m., six fifteen p.m.)', () {
      expect(
        service.postProcessTranscript('ten thirty a.m.'),
        equals('10:30 AM'),
      );
      expect(
        service.postProcessTranscript('six fifteen p.m.'),
        equals('6:15 PM'),
      );
      expect(
        service.postProcessTranscript('half past ten'),
        equals('10:30'),
      );
      expect(
        service.postProcessTranscript('quarter to eight'),
        equals('7:45'),
      );
      expect(
        service.postProcessTranscript('ten o\'clock'),
        equals('10:00'),
      );
    });

    test('Refines standalone alarm command (Set an alarm for 7:00 AM)', () {
      final refined = service.postProcessTranscript('Set an alarm for 7:00 AM');
      expect(refined, equals('Remind me to wake up at 7:00 AM'));
    });

    test('Keyword biasing includes task intents, times, destinations, and custom tasks', () {
      final keywords = service.buildKeywords();
      expect(keywords, contains('set an alarm'));
      expect(keywords, contains('go to Temple'));
      expect(keywords, contains('ten a.m.'));
      expect(keywords, contains('tomorrow'));
      expect(keywords, contains('DSA'));
    });
  });

  group('AppDateUtils Word and Dotted Time Parsing Tests', () {
    test('Parses word hours with dotted am/pm ("tomorrow ten a.m.")', () {
      expect(AppDateUtils.parseTimeString('tomorrow ten a.m.'), equals('10:00 AM'));
      expect(AppDateUtils.parseTimeString('ten a.m.'), equals('10:00 AM'));
      expect(AppDateUtils.parseTimeString('ten p.m.'), equals('10:00 PM'));
      expect(AppDateUtils.parseTimeString('seven a.m.'), equals('7:00 AM'));
    });

    test('Parses word minutes ("ten thirty am", "six fifteen pm")', () {
      expect(AppDateUtils.parseTimeString('ten thirty am'), equals('10:30 AM'));
      expect(AppDateUtils.parseTimeString('six fifteen pm'), equals('6:15 PM'));
    });

    test('Parses dotted digits ("10 a.m.", "10.00 a.m.", "7.00pm")', () {
      expect(AppDateUtils.parseTimeString('10 a.m.'), equals('10:00 AM'));
      expect(AppDateUtils.parseTimeString('10.00 a.m.'), equals('10:00 AM'));
      expect(AppDateUtils.parseTimeString('7.00pm'), equals('7:00 PM'));
    });
  });

  group('Whistle-to-Task Pipeline Parsing Tests', () {
    test('Parses spoken alarm command with word time and destination accurately', () {
      // 1. Raw Whistle transcript
      const rawWhistle = 'Set an alarm for tomorrow ten a.m. to go to Temple.';

      // 2. Enhanced by VoiceEnhancementService
      final enhanced = VoiceEnhancementService.instance.postProcessTranscript(rawWhistle);
      expect(enhanced, equals('Remind me to go to Temple tomorrow at 10:00 AM'));

      // 3. Parsed by Needle companion parser
      final request = NeedleIntentParser.parse(enhanced);
      expect(request.actionName, equals('create_task'));

      final tasks = request.arguments['tasks'] as List<dynamic>;
      expect(tasks.length, equals(1));

      final task = tasks.first as Map<String, dynamic>;
      expect(task['title'], equals('Go to Temple'));
      expect(task['dueDate'], equals('tomorrow'));
      expect(task['dueTime'], equals('10:00 AM'));
      expect(task['hasReminder'], isTrue);
    });

    test('Parses un-enhanced raw alarm command through NeedleIntentParser as well', () {
      // Even if raw transcript was passed without post-processing
      const rawWhistle = 'Set an alarm for tomorrow ten a.m. to go to Temple.';
      final request = NeedleIntentParser.parse(rawWhistle);

      expect(request.actionName, equals('create_task'));
      final tasks = request.arguments['tasks'] as List<dynamic>;
      expect(tasks.length, equals(1));

      final task = tasks.first as Map<String, dynamic>;
      expect(task['title'], equals('Go to Temple'));
      expect(task['dueDate'], equals('tomorrow'));
      expect(task['dueTime'], equals('10:00 AM'));
      expect(task['hasReminder'], isTrue);
    });
  });
}


