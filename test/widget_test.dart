import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsar/core/widgets/pulsar_logo.dart';
import 'package:pulsar/ui/add_task/widgets/staged_task_review_dialog.dart';
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
      hasAlarm: true,
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

    expect(tester.takeException(), isNull);

    // Tap reminder to toggle
    await tester.tap(find.text('Reminder'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Tap alarm to toggle
    await tester.tap(find.text('Alarm'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
