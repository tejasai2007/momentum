class HabitLog {
  final String id;
  final String habitId;
  final DateTime logDate; // date-only
  final String? note;

  HabitLog({
    required this.id,
    required this.habitId,
    required this.logDate,
    this.note,
  });

  factory HabitLog.fromMap(Map<String, dynamic> map) => HabitLog(
        id: map['id'] as String,
        habitId: map['habit_id'] as String,
        logDate: DateTime.parse(map['log_date'] as String),
        note: map['note'] as String?,
      );
}
