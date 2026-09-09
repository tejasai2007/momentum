import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';

/// A GitHub-contributions-style heatmap: one column per week, one square
/// per day (Sun at top .. Sat at bottom), filled in the habit's color when
/// that day was ticked off. The grid starts from the habit's creation date
/// (or earlier if backdated logs exist) and extends to the current week.
class HabitHeatmap extends StatefulWidget {
  final Habit habit;
  final List<HabitLog> logs;

  const HabitHeatmap({
    super.key,
    required this.habit,
    required this.logs,
  });

  @override
  State<HabitHeatmap> createState() => _HabitHeatmapState();
}

class _HabitHeatmapState extends State<HabitHeatmap> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void didUpdateWidget(covariant HabitHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    final logs = widget.logs;

    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final createdNorm = DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day);

    final doneDays = logs
        .map((l) => DateTime(l.logDate.year, l.logDate.month, l.logDate.day))
        .toSet();

    // The grid starts from the date of creation. If any backdated logs exist
    // before creation, expand start to include them.
    DateTime effectiveStart = createdNorm;
    for (final done in doneDays) {
      if (done.isBefore(effectiveStart)) {
        effectiveStart = done;
      }
    }

    // Grid starts on the Sunday of the week the habit was created (or earliest log).
    final startSunday = effectiveStart.subtract(Duration(days: effectiveStart.weekday % 7));

    // Grid ends on the Saturday of the current week (or creation week if in future).
    final endDay = todayNorm.isAfter(effectiveStart) ? todayNorm : effectiveStart;
    final endSunday = endDay.subtract(Duration(days: endDay.weekday % 7));

    final totalWeeks = (endSunday.difference(startSunday).inDays ~/ 7) + 1;

    // Build columns of 7 days each (Sun..Sat).
    final weeks = <List<DateTime>>[];
    for (int w = 0; w < totalWeeks; w++) {
      final weekStart = startSunday.add(Duration(days: w * 7));
      weeks.add(List.generate(7, (d) => weekStart.add(Duration(days: d))));
    }

    final monthLabels = _monthLabelsFor(weeks);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
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
                        softWrap: false,
                        overflow: TextOverflow.visible,
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
                          final isBeforeCreation = normalized.isBefore(effectiveStart);
                          final isFuture = normalized.isAfter(todayNorm);
                          final done = doneDays.contains(normalized);
                          final isToday = normalized.isAtSameMomentAs(todayNorm);

                          if (isBeforeCreation && !done) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 3),
                              child: SizedBox(width: 13, height: 13),
                            );
                          }

                          if (isFuture) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 3),
                              child: SizedBox(width: 13, height: 13),
                            );
                          }

                          final squareColor = done
                              ? habit.color
                              : habit.color.withValues(alpha: 0.10);

                          final border = isToday && !done
                              ? Border.all(color: habit.color.withValues(alpha: 0.45), width: 1.2)
                              : null;

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
                                  color: squareColor,
                                  border: border,
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
            _legendSquare(habit.color.withValues(alpha: 0.10)),
            const SizedBox(width: 3),
            _legendSquare(habit.color.withValues(alpha: 0.40)),
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
