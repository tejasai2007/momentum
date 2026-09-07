import 'package:flutter/material.dart';
import '../models/habit.dart';

/// Maps the habit's stored icon key to a Material icon. Extend this map as
/// you add more options to the icon picker in AddEditHabitScreen.
const Map<String, IconData> habitIconMap = {
  'star': Icons.star_rounded,
  'water': Icons.water_drop_rounded,
  'run': Icons.directions_run_rounded,
  'book': Icons.menu_book_rounded,
  'meditate': Icons.self_improvement_rounded,
  'sleep': Icons.bedtime_rounded,
  'food': Icons.restaurant_rounded,
  'gym': Icons.fitness_center_rounded,
  'code': Icons.code_rounded,
  'music': Icons.music_note_rounded,
};

class HabitCard extends StatelessWidget {
  final Habit habit;
  final bool doneToday;
  final int streak;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const HabitCard({
    super.key,
    required this.habit,
    required this.doneToday,
    required this.streak,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = habitIconMap[habit.icon] ?? Icons.star_rounded;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: habit.color.withOpacity(0.15),
                child: Icon(icon, color: habit.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(habit.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded, size: 15, color: Colors.orange),
                        const SizedBox(width: 2),
                        Text('$streak day streak', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: doneToday ? habit.color : Colors.transparent,
                    border: Border.all(color: habit.color, width: 2),
                  ),
                  child: doneToday ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
