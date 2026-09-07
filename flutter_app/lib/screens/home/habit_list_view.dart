import 'package:flutter/material.dart' hide ListView;
import 'package:flutter/material.dart' as flutter show ListView;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../widgets/habit_card.dart';
import '../habit/habit_detail_screen.dart';

/// TickOff's "List View" — a streamlined checklist, no weekly grid, for
/// people who just want to see today's to-dos.
class HabitListView extends ConsumerWidget {
  const HabitListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsProvider);
    final weekLogsAsync = ref.watch(weekLogsProvider);

    return habitsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Something went wrong: $e')),
      data: (habits) {
        if (habits.isEmpty) {
          return Center(
            child: Text('No habits yet — tap "New habit" to add one.',
                style: TextStyle(color: Colors.grey[500])),
          );
        }
        return weekLogsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Something went wrong: $e')),
          data: (weekLogs) => RefreshIndicator(
            onRefresh: () async {
              await ref.read(habitsProvider.notifier).refresh();
              ref.invalidate(weekLogsProvider);
            },
            child: flutter.ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: habits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final habit = habits[i];
                final today = DateTime.now();
                final doneToday = weekLogs.any((l) =>
                    l.habitId == habit.id &&
                    l.logDate.year == today.year &&
                    l.logDate.month == today.month &&
                    l.logDate.day == today.day);
                final habitWeekLogs = weekLogs.where((l) => l.habitId == habit.id).toList();
                final streak = ref.read(habitServiceProvider).computeCurrentStreak(habitWeekLogs);

                return HabitCard(
                  habit: habit,
                  doneToday: doneToday,
                  streak: streak,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => HabitDetailScreen(habit: habit)),
                  ),
                  onToggle: () => doneToday
                      ? ref.read(habitsProvider.notifier).untick(habit.id)
                      : ref.read(habitsProvider.notifier).tick(habit.id),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
