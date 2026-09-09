import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tickoff_clone/models/habit.dart';

void main() {
  group('Habit Model', () {
    final creationDate = DateTime(2026, 8, 15, 9, 30, 0);

    test('includes created_at in toInsertMap()', () {
      final habit = Habit(
        id: 'habit-1',
        userId: 'user-1',
        name: 'Meditation',
        icon: 'meditate',
        color: const Color(0xFF6C5CE7),
        frequency: HabitFrequency.daily,
        targetPerPeriod: 1,
        reminderTime: const TimeOfDay(hour: 8, minute: 0),
        archived: false,
        sortOrder: 0,
        createdAt: creationDate,
      );

      final map = habit.toInsertMap();
      expect(map['created_at'], creationDate.toIso8601String());
      expect(map['name'], 'Meditation');
      expect(map['icon'], 'meditate');
      expect(map['reminder_time'], '08:00:00');
    });

    test('copyWith updates creation date and fields properly', () {
      final original = Habit(
        id: 'habit-1',
        userId: 'user-1',
        name: 'Meditation',
        icon: 'meditate',
        color: const Color(0xFF6C5CE7),
        frequency: HabitFrequency.daily,
        targetPerPeriod: 1,
        archived: false,
        sortOrder: 0,
        createdAt: creationDate,
      );

      final updatedDate = DateTime(2026, 9, 1);
      final updated = original.copyWith(
        name: 'Mindful Meditation',
        createdAt: updatedDate,
      );

      expect(updated.name, 'Mindful Meditation');
      expect(updated.createdAt, updatedDate);
      expect(original.name, 'Meditation');
      expect(original.createdAt, creationDate);
    });
  });
}
