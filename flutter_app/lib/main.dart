import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config.dart';
import 'core/theme.dart';
import 'providers/app_providers.dart';
import 'services/notification_service.dart';
import 'services/habit_service.dart';
import 'services/widget_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // NOTE: The Android widget tick is handled natively (HabitTickReceiver.kt)
  // because the `home_widget` background isolate does not register Flutter
  // plugins, so supabase_flutter cannot restore the session there.
  await NotificationService.instance.init();
  // Re-arm every habit's daily reminder on launch, in case the OS cleared
  // scheduled alarms (e.g. after a reboot or app update).
  _resyncRemindersForCurrentUser(supabase: Supabase.instance.client);

  runApp(const ProviderScope(child: TickOffCloneApp()));
}

/// (Re)schedules every active habit's reminder AND pushes the current habit
/// snapshot to the Android widget. Called on app start with an existing
/// session and again whenever the user signs in, so reminders survive app
/// restarts, logins, and OS-cleared alarms — and the widget always has data
/// (plus the Supabase config/access token it needs for native taps).
void _resyncRemindersForCurrentUser({required SupabaseClient supabase}) {
  if (supabase.auth.currentUser == null) return;

  unawaited(() async {
    try {
      final habits = await HabitService().fetchHabits();
      await NotificationService.instance.resyncAll(habits);
      await WidgetService(HabitService()).syncTodayToWidget();
    } catch (_) {
      // Non-fatal — will be re-attempted on the next habit change.
    }
  }());

  supabase.auth.onAuthStateChange.listen((data) {
    if (data.session != null) {
      unawaited(() async {
        try {
          final habits = await HabitService().fetchHabits();
          await NotificationService.instance.resyncAll(habits);
          await WidgetService(HabitService()).syncTodayToWidget();
        } catch (_) {
          // Non-fatal.
        }
      }());
    } else {
      unawaited(WidgetService(HabitService()).clearWidget());
    }
  });
}

class TickOffCloneApp extends ConsumerWidget {
  const TickOffCloneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return MaterialApp(
      title: 'Momentum',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: user == null ? const LoginScreen() : const HomeScreen(),
    );
  }
}
