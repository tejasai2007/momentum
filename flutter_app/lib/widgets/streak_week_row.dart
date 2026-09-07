import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';

/// Shows Mon..Sun dots for the current week, filled in the habit's color
/// on days it was completed — this is the "interactive streak" visual
/// TickOff's Streak View is built around.
class StreakWeekRow extends StatelessWidget {
  final Habit habit;
  final List<HabitLog> weekLogs;

  const StreakWeekRow({super.key, required this.habit, required this.weekLogs});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final doneDays = weekLogs
        .where((l) => l.habitId == habit.id)
        .map((l) => DateTime(l.logDate.year, l.logDate.month, l.logDate.day))
        .toSet();
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + i);
        final isDone = doneDays.contains(day);
        final isFuture = day.isAfter(DateTime(today.year, today.month, today.day));
        return Column(
          children: [
            Text(labels[i], style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            const SizedBox(height: 4),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? habit.color : habit.color.withOpacity(isFuture ? 0.05 : 0.12),
              ),
              child: isDone ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
          ],
        );
      }),
    );
  }
}
