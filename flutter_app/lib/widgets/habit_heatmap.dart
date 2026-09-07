import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';

/// A GitHub-contributions-style heatmap: one column per week, one square
/// per day (Sun at top .. Sat at bottom), filled in the habit's color when
/// that day was ticked off. Scrolls horizontally, most recent week on the
/// right.
class HabitHeatmap extends StatelessWidget {
  final Habit habit;
  final List<HabitLog> logs;
  final int weeksToShow;

  const HabitHeatmap({
    super.key,
    required this.habit,
    required this.logs,
    this.weeksToShow = 26, // ~6 months
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final doneDays = logs
        .map((l) => DateTime(l.logDate.year, l.logDate.month, l.logDate.day))
        .toSet();

    // Find the most recent Saturday (end of the current week's column) so
    // the grid always ends on a full week.
    final endOfThisWeek = todayNorm.add(Duration(days: DateTime.daysPerWeek - todayNorm.weekday));
    final startDay = endOfThisWeek.subtract(Duration(days: weeksToShow * 7 - 1));

    // Build weeksToShow columns of 7 days each (Sun..Sat).
    final weeks = <List<DateTime>>[];
    for (int w = 0; w < weeksToShow; w++) {
      final weekStart = startDay.add(Duration(days: w * 7));
      // Shift so Sunday is first in each column, matching GitHub's layout.
      final sunday = weekStart.subtract(Duration(days: weekStart.weekday % 7));
      weeks.add(List.generate(7, (d) => sunday.add(Duration(days: d))));
    }

    final monthLabels = _monthLabelsFor(weeks);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true, // start scrolled to "today" on the right
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(weeks.length, (i) {
                    return SizedBox(
                      width: 16,
                      child: Text(
                        monthLabels[i] ?? '',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 2),
                Row(
                  children: weeks.map((week) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: Column(
                        children: week.map((day) {
                          final normalized = DateTime(day.year, day.month, day.day);
                          final isFuture = normalized.isAfter(todayNorm);
                          final done = doneDays.contains(normalized);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Tooltip(
                              message: '${normalized.month}/${normalized.day}/${normalized.year}'
                                  '${done ? ' ✓' : ''}',
                              child: Container(
                                width: 13,
                                height: 13,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  color: isFuture
                                      ? Colors.transparent
                                      : done
                                          ? habit.color
                                          : habit.color.withOpacity(0.10),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Less', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            const SizedBox(width: 6),
            _legendSquare(habit.color.withOpacity(0.10)),
            const SizedBox(width: 3),
            _legendSquare(habit.color.withOpacity(0.4)),
            const SizedBox(width: 3),
            _legendSquare(habit.color),
            const SizedBox(width: 6),
            Text('More', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ],
    );
  }

  Widget _legendSquare(Color color) => Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: color),
      );

  /// Returns a short month label ("Jan") for the first column of each new
  /// month, so labels don't repeat every week.
  List<String?> _monthLabelsFor(List<List<DateTime>> weeks) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final labels = List<String?>.filled(weeks.length, null);
    int? lastMonth;
    for (int i = 0; i < weeks.length; i++) {
      final firstDayOfWeek = weeks[i].first;
      if (lastMonth != firstDayOfWeek.month) {
        labels[i] = months[firstDayOfWeek.month - 1];
        lastMonth = firstDayOfWeek.month;
      }
    }
    return labels;
  }
}
