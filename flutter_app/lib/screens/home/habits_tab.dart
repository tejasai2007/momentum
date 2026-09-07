import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../habit/add_edit_habit_screen.dart';
import 'streak_view.dart';
import 'habit_list_view.dart';

class HabitsTab extends ConsumerWidget {
  const HabitsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(homeViewProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Habits'),
        actions: [
          IconButton(
            tooltip: view == HomeViewType.streak ? 'Switch to List View' : 'Switch to Streak View',
            icon: Icon(view == HomeViewType.streak ? Icons.view_list_rounded : Icons.grid_view_rounded),
            onPressed: () => ref.read(homeViewProvider.notifier).state =
                view == HomeViewType.streak ? HomeViewType.list : HomeViewType.streak,
          ),
        ],
      ),
      body: view == HomeViewType.streak ? const StreakView() : const HabitListView(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddEditHabitScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New habit'),
      ),
    );
  }
}
