import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';

class HabitService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _uid => _client.auth.currentUser!.id;

  // ---------------- Habits ----------------

  Future<List<Habit>> fetchHabits({bool includeArchived = false}) async {
    var query = _client.from('habits').select().eq('user_id', _uid);
    if (!includeArchived) {
      query = query.eq('archived', false);
    }
    final rows = await query.order('sort_order', ascending: true);
    return (rows as List).map((r) => Habit.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<Habit> createHabit(Habit habit) async {
    final map = habit.toInsertMap()..['user_id'] = _uid;
    final row = await _client.from('habits').insert(map).select().single();
    return Habit.fromMap(row);
  }

  Future<Habit> updateHabit(String id, Map<String, dynamic> changes) async {
    final row = await _client.from('habits').update(changes).eq('id', id).select().single();
    return Habit.fromMap(row);
  }

  Future<void> archiveHabit(String id) => _client.from('habits').update({'archived': true}).eq('id', id);

  Future<void> deleteHabit(String id) => _client.from('habits').delete().eq('id', id);

  // ---------------- Logs (tick / un-tick / backdate) ----------------

  Future<List<HabitLog>> fetchLogsForHabit(String habitId) async {
    final rows = await _client.from('habit_logs').select().eq('habit_id', habitId).order('log_date');
    return (rows as List).map((r) => HabitLog.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// All logs for the user within [from, to] (inclusive) — handy for a
  /// month-view calendar or the weekly grid on the Streak home screen.
  Future<List<HabitLog>> fetchLogsInRange(DateTime from, DateTime to) async {
    final rows = await _client
        .from('habit_logs')
        .select()
        .eq('user_id', _uid)
        .gte('log_date', _dateOnly(from))
        .lte('log_date', _dateOnly(to));
    return (rows as List).map((r) => HabitLog.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Ticks a habit off for [date] (defaults to today). Supports backdating
  /// by passing any past date from the calendar picker.
  Future<void> tickHabit(String habitId, {DateTime? date, String? note}) async {
    final day = date ?? DateTime.now();
    await _client.from('habit_logs').upsert(
      {
        'habit_id': habitId,
        'user_id': _uid,
        'log_date': _dateOnly(day),
        'note': note,
      },
      onConflict: 'habit_id,log_date',
    );
  }

  /// Removes the tick for a given day (undo).
  Future<void> untickHabit(String habitId, {DateTime? date}) async {
    final day = date ?? DateTime.now();
    await _client
        .from('habit_logs')
        .delete()
        .eq('habit_id', habitId)
        .eq('log_date', _dateOnly(day));
  }

  /// Current streak (consecutive days up to and including today) for a habit,
  /// computed from the fetched logs. Kept client-side for flexibility with
  /// weekly/custom-frequency habits.
  int computeCurrentStreak(List<HabitLog> logs) {
    if (logs.isEmpty) return 0;
    final days = logs.map((l) => DateTime(l.logDate.year, l.logDate.month, l.logDate.day)).toSet();
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    int streak = 0;
    // If today isn't done yet, streak still counts back from yesterday.
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int computeBestStreak(List<HabitLog> logs) {
    if (logs.isEmpty) return 0;
    final sortedDays = logs.map((l) => DateTime(l.logDate.year, l.logDate.month, l.logDate.day)).toSet().toList()
      ..sort();
    int best = 1, current = 1;
    for (int i = 1; i < sortedDays.length; i++) {
      final diff = sortedDays[i].difference(sortedDays[i - 1]).inDays;
      if (diff == 1) {
        current++;
        best = current > best ? current : best;
      } else {
        current = 1;
      }
    }
    return best;
  }

  String _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day).toIso8601String().split('T').first;
}
