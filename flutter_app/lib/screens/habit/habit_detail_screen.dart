import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/habit.dart';
import '../../providers/app_providers.dart';
import '../../widgets/habit_card.dart';
import '../../widgets/habit_heatmap.dart';
import 'add_edit_habit_screen.dart';

class HabitDetailScreen extends ConsumerStatefulWidget {
  final Habit habit;
  const HabitDetailScreen({super.key, required this.habit});

  @override
  ConsumerState<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends ConsumerState<HabitDetailScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(habitLogsProvider(widget.habit.id));
    final icon = habitIconMap[widget.habit.icon] ?? Icons.star_rounded;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.habit.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AddEditHabitScreen(existing: widget.habit)),
            ),
          ),
        ],
      ),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Something went wrong: $e')),
        data: (logs) {
          final doneDays = logs
              .map((l) => DateTime(l.logDate.year, l.logDate.month, l.logDate.day))
              .toSet();
          final currentStreak = ref.read(habitServiceProvider).computeCurrentStreak(logs);
          final bestStreak = ref.read(habitServiceProvider).computeBestStreak(logs);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 28, backgroundColor: widget.habit.color.withOpacity(0.15), child: Icon(icon, color: widget.habit.color, size: 28)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Row(
                      children: [
                        _StatChip(label: 'Current', value: '$currentStreak', color: widget.habit.color),
                        const SizedBox(width: 10),
                        _StatChip(label: 'Best', value: '$bestStreak', color: widget.habit.color),
                        const SizedBox(width: 10),
                        _StatChip(label: 'Total', value: '${logs.length}', color: widget.habit.color),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Streak heatmap', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      HabitHeatmap(habit: widget.habit, logs: logs),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TableCalendar(
                    firstDay: DateTime.now().subtract(const Duration(days: 365)),
                    lastDay: DateTime.now(),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
                    onDaySelected: (selected, focused) {
                      setState(() {
                        _selectedDay = selected;
                        _focusedDay = focused;
                      });
                      _showTickSheet(context, selected, doneDays.contains(DateTime(selected.year, selected.month, selected.day)));
                    },
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) => _dayCell(day, doneDays),
                      todayBuilder: (context, day, focusedDay) => _dayCell(day, doneDays, isToday: true),
                    ),
                    headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tap any past day to backdate a tick — great for catching up on days you forgot to log.',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dayCell(DateTime day, Set<DateTime> doneDays, {bool isToday = false}) {
    final normalized = DateTime(day.year, day.month, day.day);
    final done = doneDays.contains(normalized);
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? widget.habit.color : Colors.transparent,
        border: isToday && !done ? Border.all(color: widget.habit.color) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(color: done ? Colors.white : null, fontWeight: isToday ? FontWeight.bold : null),
      ),
    );
  }

  void _showTickSheet(BuildContext context, DateTime day, bool alreadyDone) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(alreadyDone ? Icons.close_rounded : Icons.check_rounded),
              title: Text(alreadyDone ? 'Remove tick for ${_fmt(day)}' : 'Mark ${_fmt(day)} as done'),
              onTap: () async {
                Navigator.pop(context);
                if (alreadyDone) {
                  await ref.read(habitsProvider.notifier).untick(widget.habit.id, date: day);
                } else {
                  await ref.read(habitsProvider.notifier).tick(widget.habit.id, date: day);
                }
                ref.invalidate(habitLogsProvider(widget.habit.id));
              },
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) => '${d.month}/${d.day}/${d.year}';
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
