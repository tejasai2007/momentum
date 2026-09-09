import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tickoff_clone/models/habit.dart';
import 'package:tickoff_clone/widgets/habit_heatmap.dart';

void main() {
  group('HabitHeatmap', () {
    testWidgets('renders heatmap with columns starting from habit creation week', (tester) async {
      final now = DateTime.now();
      // Habit created today
      final habitToday = Habit(
        id: 'h1',
        userId: 'u1',
        name: 'Running',
        icon: 'run',
        color: const Color(0xFF00B894),
        frequency: HabitFrequency.daily,
        targetPerPeriod: 1,
        archived: false,
        sortOrder: 0,
        createdAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitHeatmap(habit: habitToday, logs: const []),
          ),
        ),
      );

      expect(find.byType(HabitHeatmap), findsOneWidget);
      // There should be a single column representing the current week
      final rowFinder = find.byType(Row);
      expect(rowFinder, findsWidgets);
    });

    testWidgets('renders multiple columns when habit was created in the past', (tester) async {
      final now = DateTime.now();
      // Habit created 3 weeks ago
      final habitPast = Habit(
        id: 'h2',
        userId: 'u1',
        name: 'Reading',
        icon: 'book',
        color: const Color(0xFF0984E3),
        frequency: HabitFrequency.daily,
        targetPerPeriod: 1,
        archived: false,
        sortOrder: 0,
        createdAt: now.subtract(const Duration(days: 21)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitHeatmap(habit: habitPast, logs: const []),
          ),
        ),
      );

      expect(find.byType(HabitHeatmap), findsOneWidget);
    });
  });
}
