import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import 'habit_service.dart';

/// Bridges Flutter <-> the native Android AppWidgetProvider.
///
/// Flow:
/// 1. Whenever habits/logs change, [syncTodayToWidget] writes a small JSON
///    payload into the widget's shared storage via `home_widget`.
/// 2. `HomeWidget.updateWidget(...)` asks Android to redraw the widget,
///    which reads that JSON in `HabitWidgetProvider.kt`.
/// 3. Tapping a habit row in the widget fires a background broadcast that
///    the native side turns into a call back into Dart (see
///    `backgroundCallback` below), so ticking a habit works even if the
///    app isn't open.
class WidgetService {
  static const String _androidWidgetName = 'HabitWidgetProvider';
  static const String _dataKey = 'today_habits_json';

  final HabitService _habitService;
  WidgetService(this._habitService);

  Future<void> syncTodayToWidget() async {
    final habits = await _habitService.fetchHabits();
    final today = DateTime.now();
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final logs = await _habitService.fetchLogsInRange(startOfWeek, today);

    final logsByHabit = <String, List<HabitLog>>{};
    for (final log in logs) {
      logsByHabit.putIfAbsent(log.habitId, () => []).add(log);
    }

    final payload = habits.map((h) {
      final habitLogs = logsByHabit[h.id] ?? [];
      final doneToday = habitLogs.any((l) =>
          l.logDate.year == today.year && l.logDate.month == today.month && l.logDate.day == today.day);
      return {
        'id': h.id,
        'name': h.name,
        'color': '#${h.color.value.toRadixString(16).substring(2)}',
        'doneToday': doneToday,
        'streak': _habitService.computeCurrentStreak(habitLogs),
      };
    }).toList();

    await HomeWidget.saveWidgetData<String>(_dataKey, jsonEncode(payload));
    await HomeWidget.updateWidget(
      name: _androidWidgetName,
      androidName: _androidWidgetName,
    );
  }

  /// Registers the callback that runs in a background isolate when the
  /// widget itself sends an interaction (e.g. tapping a habit row's tick
  /// button) while the app is closed. Call once from `main()`.
  static Future<void> registerBackgroundCallback() async {
    await HomeWidget.registerInteractivityCallback(backgroundCallback);
  }
}

/// Runs in a **separate background isolate** spawned by the OS — it does
/// NOT share memory with the main app isolate, so Supabase (and anything
/// else set up in `main()`) does not exist here yet. It must be
/// re-initialized every time this callback runs. Must stay a top-level or
/// static function per `home_widget`'s requirements.
@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  if (uri == null) return;
  if (uri.host != 'tickhabit') return;

  final habitId = uri.queryParameters['habitId'];
  if (habitId == null) return;

  // Re-initialize Supabase in this isolate. `supabase_flutter` persists the
  // logged-in session to local storage, so this recovers the same signed-in
  // user the main app is using — it does not require signing in again.
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  } catch (_) {
    // Supabase.initialize throws if already initialized in this isolate
    // (e.g. if the OS reuses the isolate for a rapid second tap) — safe to
    // ignore and continue using the existing instance.
  }

  if (Supabase.instance.client.auth.currentUser == null) {
    // No persisted session yet (e.g. user never opened the app after
    // installing) — nothing we can attribute this tick to.
    return;
  }

  final habitService = HabitService();
  await habitService.tickHabit(habitId);
  await WidgetService(habitService).syncTodayToWidget();
}
