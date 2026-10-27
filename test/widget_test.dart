import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsar/core/widgets/pulsar_logo.dart';
import 'package:pulsar/ui/add_task/widgets/staged_task_review_dialog.dart';
import 'package:pulsar/ui/alarm/widgets/dual_swipe_slider.dart';
import 'package:pulsar/ui/alarm/widgets/alarm_tutorial_dialog.dart';
import 'package:pulsar/ui/alarm/alarm_ring_screen.dart';
import 'package:alarm/alarm.dart';
import 'package:pulsar/models/task_model.dart';

void main() {
  testWidgets('Pulsar Logo renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: PulsarLogo(size: 64, isAnimated: false),
          ),
        ),
      ),
    );

    expect(find.byType(PulsarLogo), findsOneWidget);
  });

  testWidgets('StagedTaskReviewDialog renders without overflow on 360x800 mobile screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final testTask = Task(
      title: 'Submit assignment',
      dueDate: DateTime.now().add(const Duration(days: 1)),
      dueTime: '10:00 AM',
      hasReminder: true,
      hasAlarm: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              StagedTaskReviewDialog(
                tasks: [testTask],
                onConfirm: () {},
                onCancel: () {},
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Submit assignment'), findsOneWidget);
    expect(find.text('Reminder'), findsOneWidget);
    expect(find.text('Alarm'), findsOneWidget);
    expect(
      find.textContaining('Select either Reminder or Alarm.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('StagedTaskReviewDialog renders without overflow on very narrow 320x600 screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final testTask = Task(
      title: 'Submit assignment',
      dueDate: DateTime.now().add(const Duration(days: 1)),
      dueTime: '10:00 AM',
      hasReminder: true,
      hasAlarm: false,
    );

    Task? updatedResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              StagedTaskReviewDialog(
                tasks: [testTask],
                onTaskUpdated: (idx, updated) {
                  updatedResult = updated;
                },
                onConfirm: () {},
                onCancel: () {},
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // Tap Alarm -> should turn on alarm and turn off reminder
    await tester.tap(find.text('Alarm'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(updatedResult?.hasAlarm, isTrue);
    expect(updatedResult?.hasReminder, isFalse);

    // Tap Reminder -> should turn on reminder and turn off alarm
    await tester.tap(find.text('Reminder'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(updatedResult?.hasReminder, isTrue);
    expect(updatedResult?.hasAlarm, isFalse);
  });

  group('Task Model Reminder & Alarm Mutual Exclusion Tests', () {
    test('Task constructor enforces mutual exclusion when hasAlarm is true', () {
      final task = Task(
        title: 'Alarm Task',
        hasReminder: true,
        hasAlarm: true,
      );
      expect(task.hasAlarm, isTrue);
      expect(task.hasReminder, isFalse);
    });

    test('Task copyWith toggling alarm on turns off reminder', () {
      final task = Task(title: 'Task', hasReminder: true, hasAlarm: false);
      final updated = task.copyWith(hasAlarm: true);
      expect(updated.hasAlarm, isTrue);
      expect(updated.hasReminder, isFalse);
    });

    test('Task copyWith toggling reminder on turns off alarm', () {
      final task = Task(title: 'Task', hasReminder: false, hasAlarm: true);
      final updated = task.copyWith(hasReminder: true);
      expect(updated.hasReminder, isTrue);
      expect(updated.hasAlarm, isFalse);
    });

    test('Task copyWith allows turning both off', () {
      final task = Task(title: 'Task', hasReminder: true, hasAlarm: false);
      final updated = task.copyWith(hasReminder: false);
      expect(updated.hasReminder, isFalse);
      expect(updated.hasAlarm, isFalse);
    });

    test('Task.fromMap sanitizes historical records with both set to 1', () {
      final task = Task.fromMap({
        'title': 'Legacy Task',
        'has_reminder': 1,
        'has_alarm': 1,
        'is_completed': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      expect(task.hasAlarm, isTrue);
      expect(task.hasReminder, isFalse);
    });
  });

  group('Alarm Dual Swipe & Tutorial Widget Tests', () {
    testWidgets('DualSwipeSlider renders and responds to swipe right and left', (WidgetTester tester) async {
      bool rightSwiped = false;
      bool leftSwiped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 340,
                child: DualSwipeSlider(
                  snoozeMinutes: 10,
                  onSwipeRight: () => rightSwiped = true,
                  onSwipeLeft: () => leftSwiped = true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Snooze 10m'), findsOneWidget);
      expect(find.text('Swipe left to snooze'), findsOneWidget);
      expect(find.text('Swipe right to complete'), findsOneWidget);

      // Drag right to trigger complete
      await tester.drag(find.byType(DualSwipeSlider), const Offset(150, 0));
      await tester.pumpAndSettle();
      expect(rightSwiped, isTrue);

      // Reset state for swipe left test
      rightSwiped = false;
      leftSwiped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 340,
                child: DualSwipeSlider(
                  key: const ValueKey('second_slider'),
                  snoozeMinutes: 10,
                  onSwipeRight: () => rightSwiped = true,
                  onSwipeLeft: () => leftSwiped = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Drag left to trigger snooze
      await tester.drag(find.byType(DualSwipeSlider), const Offset(-150, 0));
      await tester.pumpAndSettle();
      expect(leftSwiped, isTrue);
    });

    testWidgets('AlarmTutorialDialog renders instructions and tips correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AlarmTutorialDialog(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Alarm Controls'), findsOneWidget);
      expect(find.text('Swipe Right 👉 Dismiss & Done'), findsOneWidget);
      expect(find.text('Swipe Left 👈 Snooze'), findsOneWidget);
      expect(find.text('Got It'), findsOneWidget);

      // Tap Got It
      await tester.tap(find.text('Got It'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('AlarmRingScreen renders Dismiss without completing button with high visibility', (WidgetTester tester) async {
      final settings = AlarmSettings(
        id: 999,
        dateTime: DateTime.now().add(const Duration(minutes: 5)),
        assetAudioPath: 'assets/audio/alarm.wav',
        notificationSettings: const NotificationSettings(
          title: '⏰ Alarm: Test Task',
          body: 'Click the notification for other options',
          stopButton: 'Dismiss',
        ),
        volumeSettings: const VolumeSettings.fixed(volume: 0.8),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AlarmRingScreen(
            alarmSettings: settings,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Test Task'), findsOneWidget);
      expect(find.text('Dismiss without completing'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });
  });
}
