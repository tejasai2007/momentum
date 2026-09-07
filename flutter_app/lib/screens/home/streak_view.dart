import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../widgets/habit_card.dart';
import '../../widgets/streak_week_row.dart';
import '../habit/habit_detail_screen.dart';

class StreakView extends ConsumerWidget {
  const StreakView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsProvider);
    final weekLogsAsync = ref.watch(weekLogsProvider);

    return habitsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Something went wrong: $e')),
      data: (habits) {
        if (habits.isEmpty) return const _EmptyState();

        return weekLogsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Something went wrong: $e')),
          data: (weekLogs) => RefreshIndicator(
            onRefresh: () async {
              await ref.read(habitsProvider.notifier).refresh();
              ref.invalidate(weekLogsProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: habits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
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

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HabitCard(
                      habit: habit,
                      doneToday: doneToday,
                      streak: streak,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => HabitDetailScreen(habit: habit)),
                      ),
                      onToggle: () => doneToday
                          ? ref.read(habitsProvider.notifier).untick(habit.id)
                          : ref.read(habitsProvider.notifier).tick(habit.id),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                      child: StreakWeekRow(habit: habit, weekLogs: weekLogs),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.self_improvement_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('No habits yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Tap "New habit" to start building your streak.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}
