import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/journal_entry.dart';
import '../services/auth_service.dart';
import '../services/habit_service.dart';
import '../services/journal_service.dart';
import '../services/widget_service.dart';
import '../services/notification_service.dart';

// ---------------- Services ----------------
final authServiceProvider = Provider((ref) => AuthService());
final habitServiceProvider = Provider((ref) => HabitService());
final journalServiceProvider = Provider((ref) => JournalService());
final widgetServiceProvider =
    Provider((ref) => WidgetService(ref.read(habitServiceProvider)));

// ---------------- Auth ----------------
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider).valueOrNull;
  return authState?.session?.user ?? Supabase.instance.client.auth.currentUser;
});

// ---------------- Habits ----------------
final habitsProvider = AsyncNotifierProvider<HabitsNotifier, List<Habit>>(HabitsNotifier.new);

class HabitsNotifier extends AsyncNotifier<List<Habit>> {
  @override
  Future<List<Habit>> build() async {
    return ref.read(habitServiceProvider).fetchHabits();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(habitServiceProvider).fetchHabits());
  }

  Future<void> addHabit(Habit habit) async {
    final created = await ref.read(habitServiceProvider).createHabit(habit);
    await NotificationService.instance.scheduleForHabit(created);
    await refresh();
    await ref.read(widgetServiceProvider).syncTodayToWidget();
  }

  Future<void> updateHabit(String id, Map<String, dynamic> changes) async {
    final updated = await ref.read(habitServiceProvider).updateHabit(id, changes);
    await NotificationService.instance.scheduleForHabit(updated);
    await refresh();
    await ref.read(widgetServiceProvider).syncTodayToWidget();
  }

  Future<void> archiveHabit(String id) async {
    await ref.read(habitServiceProvider).archiveHabit(id);
    await NotificationService.instance.cancelForHabit(id);
    await refresh();
    await ref.read(widgetServiceProvider).syncTodayToWidget();
  }

  Future<void> deleteHabit(String id) async {
    await ref.read(habitServiceProvider).deleteHabit(id);
    await NotificationService.instance.cancelForHabit(id);
    await refresh();
    await ref.read(widgetServiceProvider).syncTodayToWidget();
  }

  Future<void> tick(String habitId, {DateTime? date}) async {
    await ref.read(habitServiceProvider).tickHabit(habitId, date: date);
    await ref.read(widgetServiceProvider).syncTodayToWidget();
    ref.invalidate(habitLogsProvider(habitId));
    ref.invalidate(weekLogsProvider);
  }

  Future<void> untick(String habitId, {DateTime? date}) async {
    await ref.read(habitServiceProvider).untickHabit(habitId, date: date);
    await ref.read(widgetServiceProvider).syncTodayToWidget();
    ref.invalidate(habitLogsProvider(habitId));
    ref.invalidate(weekLogsProvider);
  }
}

// Logs for a single habit (used on the detail screen's heatmap/calendar).
final habitLogsProvider = FutureProvider.family<List<HabitLog>, String>((ref, habitId) {
  return ref.read(habitServiceProvider).fetchLogsForHabit(habitId);
});

// All logs for the current week (used to render the Streak home view grid).
final weekLogsProvider = FutureProvider<List<HabitLog>>((ref) {
  final today = DateTime.now();
  final start = today.subtract(Duration(days: today.weekday - 1));
  return ref.read(habitServiceProvider).fetchLogsInRange(start, today);
});

// ---------------- Journal ----------------
final journalEntriesProvider =
    AsyncNotifierProvider<JournalNotifier, List<JournalEntry>>(JournalNotifier.new);

class JournalNotifier extends AsyncNotifier<List<JournalEntry>> {
  @override
  Future<List<JournalEntry>> build() async {
    return ref.read(journalServiceProvider).fetchEntries();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => ref.read(journalServiceProvider).fetchEntries());
  }

  Future<void> addEntry(JournalEntry entry) async {
    await ref.read(journalServiceProvider).createEntry(entry);
    await refresh();
  }

  Future<void> deleteEntry(String id) async {
    await ref.read(journalServiceProvider).deleteEntry(id);
    await refresh();
  }
}

// ---------------- Home view preference (Streak vs List) ----------------
final homeViewProvider = StateProvider<HomeViewType>((ref) => HomeViewType.streak);

enum HomeViewType { streak, list }
