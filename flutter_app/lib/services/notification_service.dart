import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../models/habit.dart';

/// Schedules one repeating daily local notification per habit, at that
/// habit's `reminderTime`. Each habit gets a stable notification id derived
/// from its UUID so it can be individually rescheduled or cancelled when the
/// habit is edited, archived, or deleted.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const MethodChannel _timezoneChannel =
      MethodChannel('tickoffclone/timezone');

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _canScheduleExact = false;

  Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    await _resolveLocalTimezone();

    const androidInit = AndroidInitializationSettings('ic_stat_check');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(initSettings);

    // Reads whether exact-alarm scheduling is currently allowed. We do NOT
    // request any permission here — several of these must be triggered from
    // the activity after the UI is up (see [requestAllPermissions]), so
    // asking during startup (before the widget tree exists) is silently
    // ignored on many Android 14+/OEM devices.
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      _canScheduleExact = await androidImpl?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      _canScheduleExact = false;
    }

    _initialized = true;
  }

  /// Non-prompting snapshot of the current state of every reminder permission,
  /// so callers can decide whether an auto-request is actually warranted.
  Future<Map<AlarmPermission, bool>> checkPermissions() async {
    if (!_initialized) await init();

    final results = {
      AlarmPermission.notifications: false,
      AlarmPermission.exactAlarms: false,
      AlarmPermission.fullScreenNotifications: false,
      AlarmPermission.ignoreBatteryOptimizations: false,
    };

    try {
      results[AlarmPermission.notifications] =
          await Permission.notification.status.isGranted;
    } catch (_) {}
    try {
      results[AlarmPermission.exactAlarms] =
          await Permission.scheduleExactAlarm.status.isGranted;
    } catch (_) {}
    try {
      results[AlarmPermission.ignoreBatteryOptimizations] =
          await Permission.ignoreBatteryOptimizations.status.isGranted;
    } catch (_) {}
    try {
      // There's no non-prompting status getter for full-screen intents; it
      // only matters on Android 14+ where it can be toggled per-app. Report
      // it conservatively as unmet so the auto-request flow includes it.
      results[AlarmPermission.fullScreenNotifications] = false;
    } catch (_) {}

    return results;
  }

  /// Asks the OS for every permission needed for alarm-style reminders:
  /// notifications (Android 13+), full-screen intents (Android 14+), exact
  /// alarms (Android 12+), and — critically on OEM devices (Xiaomi/Vivo/
  /// Oppo, etc.) — an exemption from battery optimization, without which the
  /// OS silently suppresses background alarms. Must be called from an active
  /// screen.
  ///
  /// Returns a map describing what ended up granted, so the UI can guide the
  /// user when something still needs to be enabled in system Settings.
  Future<Map<AlarmPermission, bool>> requestAllPermissions() async {
    if (!_initialized) await init();

    final results = {
      AlarmPermission.notifications: false,
      AlarmPermission.exactAlarms: false,
      AlarmPermission.fullScreenNotifications: false,
      AlarmPermission.ignoreBatteryOptimizations: false,
    };

    // POST_NOTIFICATIONS — Android 13+. Uses permission_handler for reliable
    // status tracking (granted / denied / permanently denied).
    try {
      final status = await Permission.notification.request();
      results[AlarmPermission.notifications] = status.isGranted;
    } catch (_) {
      // Some OEMs throw; treat as not granted.
    }

    // SCHEDULE_EXACT_ALARM — Android 12+. Depending on Android version this
    // opens the system's "Alarms & reminders" special-access screen.
    try {
      final status = await Permission.scheduleExactAlarm.request();
      results[AlarmPermission.exactAlarms] = status.isGranted;
      _canScheduleExact = status.isGranted;
    } catch (_) {
      // Fall back to the flutter_local_notifications API which also opens
      // the exact-alarm screen on Android 12+.
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      try {
        final granted = await androidImpl?.requestExactAlarmsPermission() ?? false;
        results[AlarmPermission.exactAlarms] = granted;
        _canScheduleExact = granted;
      } catch (_) {
        results[AlarmPermission.exactAlarms] = false;
        _canScheduleExact = false;
      }
    }

    // USE_FULL_SCREEN_INTENT — Android 14+ has a dedicated permission screen.
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidImpl?.requestFullScreenIntentPermission() ?? false;
      results[AlarmPermission.fullScreenNotifications] = granted;
    } catch (_) {
      results[AlarmPermission.fullScreenNotifications] = false;
    }

    // REQUEST_IGNORE_BATTERY_OPTIMIZATIONS — without this, OEMs defer or kill
    // the scheduled alarm while the app is backgrounded, so reminders never
    // appear on time.
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      results[AlarmPermission.ignoreBatteryOptimizations] = status.isGranted;
    } catch (_) {
      results[AlarmPermission.ignoreBatteryOptimizations] = false;
    }

    return results;
  }

  /// Fires the permission-request flow only for permissions that are still
  /// missing, skipping ones the user already granted. Use this from the
  /// habit-reminder save path so the first time a reminder is set the OS
  /// prompts appear automatically without nagging on every save.
  Future<Map<AlarmPermission, bool>> ensureReminderPermissions() async {
    final current = await checkPermissions();
    if (!current.values.any((g) => g == false)) return current;
    // prune the granted ones and only ask for what's still outstanding
    final outstanding = <AlarmPermission>[];
    for (final entry in current.entries) {
      if (!entry.value) outstanding.add(entry.key);
    }
    return _requestPermissions(outstanding);
  }

  Future<Map<AlarmPermission, bool>> _requestPermissions(
      List<AlarmPermission> which) async {
    if (which.isEmpty) return {};
    if (!_initialized) await init();
    final results = <AlarmPermission, bool>{};

    if (which.contains(AlarmPermission.notifications)) {
      try {
        results[AlarmPermission.notifications] =
            (await Permission.notification.request()).isGranted;
      } catch (_) {}
    } else {
      try {
        results[AlarmPermission.notifications] =
            await Permission.notification.status.isGranted;
      } catch (_) {}
    }

    if (which.contains(AlarmPermission.exactAlarms)) {
      try {
        results[AlarmPermission.exactAlarms] =
            (await Permission.scheduleExactAlarm.request()).isGranted;
        _canScheduleExact = results[AlarmPermission.exactAlarms]!;
      } catch (_) {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        try {
          results[AlarmPermission.exactAlarms] =
              await androidImpl?.requestExactAlarmsPermission() ?? false;
          _canScheduleExact = results[AlarmPermission.exactAlarms]!;
        } catch (_) {
          results[AlarmPermission.exactAlarms] = false;
          _canScheduleExact = false;
        }
      }
    } else {
      results[AlarmPermission.exactAlarms] = _canScheduleExact;
    }

    if (which.contains(AlarmPermission.fullScreenNotifications)) {
      try {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        results[AlarmPermission.fullScreenNotifications] =
            await androidImpl?.requestFullScreenIntentPermission() ?? false;
      } catch (_) {
        results[AlarmPermission.fullScreenNotifications] = false;
      }
    } else {
      // No status getter for full-screen intents; report as unmet.
      results[AlarmPermission.fullScreenNotifications] = false;
    }

    if (which.contains(AlarmPermission.ignoreBatteryOptimizations)) {
      try {
        results[AlarmPermission.ignoreBatteryOptimizations] =
            (await Permission.ignoreBatteryOptimizations.request()).isGranted;
      } catch (_) {
        results[AlarmPermission.ignoreBatteryOptimizations] = false;
      }
    } else {
      try {
        results[AlarmPermission.ignoreBatteryOptimizations] =
            await Permission.ignoreBatteryOptimizations.status.isGranted;
      } catch (_) {
        results[AlarmPermission.ignoreBatteryOptimizations] = false;
      }
    }

    return results;
  }

  /// Resolves `tz.local` to the device's real IANA zone so "daily at HH:MM"
  /// fires at the correct wall-clock time. If the ID the OS reports isn't in
  /// the tz database (some OEMs return short/offset IDs), falls back to any
  /// database location whose *current* UTC offset matches the device, which
  /// keeps the scheduled wall-clock time correct.
  Future<void> _resolveLocalTimezone() async {
    String? deviceId;
    try {
      deviceId = await _timezoneChannel.invokeMethod<String>('getLocalTimezone');
    } catch (_) {
      return;
    }
    if (deviceId == null || deviceId.isEmpty) return;

    try {
      tz.setLocalLocation(tz.getLocation(deviceId));
      return;
    } on tz.LocationNotFoundException {
      // fall through to offset-based lookup below
    }

    final targetOffset = DateTime.now().timeZoneOffset;
    for (final name in tz.timeZoneDatabase.locations.keys) {
      final loc = tz.getLocation(name);
      if (tz.TZDateTime.now(loc).timeZoneOffset == targetOffset) {
        tz.setLocalLocation(loc);
        return;
      }
    }
  }

  /// Schedules (or reschedules) a daily reminder for [habit]. Does nothing
  /// if the habit has no `reminderTime` set.
  Future<void> scheduleForHabit(Habit habit) async {
    try {
      await cancelForHabit(habit.id);
      final time = habit.reminderTime;
      if (time == null) return;

      if (!_initialized) await init();

      final id = _notificationIdFor(habit.id);
      final scheduledDate = _nextInstanceOfTime(time);

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'habit_reminders',
          'Habit Reminders',
          channelDescription: 'Daily reminders to complete your habits',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          // Alarm-style: take over the screen (opens the app) so reminder
          // gets noticed even when the phone is locked or in do-not-disturb.
          fullScreenIntent: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.public,
          colorized: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBanner: true,
          sound: 'default',
        ),
      );

      try {
        await _plugin.zonedSchedule(
          id,
          habit.name,
          "Time to tick off \"${habit.name}\" 💪",
          scheduledDate,
          details,
          androidScheduleMode: _canScheduleExact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          // repeats daily
          matchDateTimeComponents: DateTimeComponents.time,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {
        // Exact-alarm permission may still be missing on this OEM even after
        // the permission dialog — retry once with inexact scheduling so the
        // reminder still (approximately) fires.
        try {
          await _plugin.zonedSchedule(
            id,
            habit.name,
            "Time to tick off \"${habit.name}\" 💪",
            scheduledDate,
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.time,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (_) {
          // Never let a scheduling failure break habit create/edit/delete.
        }
      }
    } catch (_) {
      // Swallow scheduling errors — the habit itself is already saved.
    }
  }

  Future<void> cancelForHabit(String habitId) async {
    await _plugin.cancel(_notificationIdFor(habitId));
  }

  /// Re-syncs every habit's reminder — call this once after fetching habits
  /// (e.g. on app start / login) so reminders survive app reinstalls or a
  /// fresh device, since Android does NOT persist notifications across a
  /// reboot on its own beyond what the plugin re-registers at app launch.
  Future<void> resyncAll(List<Habit> habits) async {
    for (final h in habits) {
      if (h.archived) {
        await cancelForHabit(h.id);
      } else {
        await scheduleForHabit(h);
      }
    }
  }

  int _notificationIdFor(String habitId) => habitId.hashCode & 0x7fffffff;

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

/// The Android permissions required for alarm-style reminder delivery.
enum AlarmPermission {
  notifications,
  exactAlarms,
  fullScreenNotifications,
  ignoreBatteryOptimizations,
}
