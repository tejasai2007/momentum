import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config.dart';
import '../models/habit_log.dart';
import 'habit_service.dart';

/// Bridges Flutter <-> the native Android AppWidgetProvider.
///
/// Flow:
/// 1. Whenever habits/logs change, [syncTodayToWidget] writes a small JSON
///    payload into the widget's shared storage via `home_widget`.
/// 2. `HomeWidget.updateWidget(...)` asks Android to redraw the widget,
///    which reads that JSON in `HabitWidgetProvider.kt`.
/// 3. Tapping a habit row in the widget fires a broadcast handled natively
///    (see `HabitTickReceiver.kt`), which ticks the habit via the Supabase
///    REST API and refreshes the widget — so ticking works even if the app
///    isn't open.
class WidgetService {
  static const String _androidWidgetName = 'HabitWidgetProvider';
  static const String _dataKey = 'today_habits_json';

  // Supabase credentials/session are written into the widget's shared storage
  // so the native widget can tick a habit directly (see HabitTickReceiver.kt)
  // without relying on a Dart background isolate.
  static const String _urlKey = 'supabase_url';
  static const String _anonKey = 'supabase_anon_key';
  static const String _tokenKey = 'supabase_access_token';
  static const String _refreshTokenKey = 'supabase_refresh_token';
  static const String _userIdKey = 'user_id';

  final HabitService _habitService;
  WidgetService(this._habitService);

  Future<void> syncTodayToWidget() async {
    try {
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
        final hexColor = (h.color.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0');
        return {
          'id': h.id,
          'name': h.name,
          'color': '#$hexColor',
          'doneToday': doneToday,
          'streak': _habitService.computeCurrentStreak(habitLogs),
        };
      }).toList();

      await _saveNativeConfig();

      await HomeWidget.saveWidgetData<String>(_dataKey, jsonEncode(payload));
      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        androidName: _androidWidgetName,
      );
    } catch (_) {
      // Non-fatal: widget sync will be re-attempted on next habit change or app resume
    }
  }

  /// Stores Supabase configuration, user ID, and tokens in shared storage
  /// so HabitTickReceiver can authenticate natively even when the app is closed.
  Future<void> _saveNativeConfig() async {
    await HomeWidget.saveWidgetData<String>(_urlKey, SupabaseConfig.url);
    await HomeWidget.saveWidgetData<String>(_anonKey, SupabaseConfig.anonKey);

    final session = Supabase.instance.client.auth.currentSession;
    final user = Supabase.instance.client.auth.currentUser;

    if (session != null) {
      await HomeWidget.saveWidgetData<String>(_tokenKey, session.accessToken);
      if (session.refreshToken != null) {
        await HomeWidget.saveWidgetData<String>(_refreshTokenKey, session.refreshToken);
      }
    }
    if (user != null) {
      await HomeWidget.saveWidgetData<String>(_userIdKey, user.id);
    }
  }

  /// Clears stored habits and credentials from the widget (e.g. on logout).
  Future<void> clearWidget() async {
    await HomeWidget.saveWidgetData<String>(_dataKey, '[]');
    await HomeWidget.saveWidgetData<String>(_tokenKey, null);
    await HomeWidget.saveWidgetData<String>(_refreshTokenKey, null);
    await HomeWidget.saveWidgetData<String>(_userIdKey, null);
    await HomeWidget.updateWidget(
      name: _androidWidgetName,
      androidName: _androidWidgetName,
    );
  }
}
