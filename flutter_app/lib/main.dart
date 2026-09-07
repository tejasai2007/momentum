import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config.dart';
import 'core/theme.dart';
import 'providers/app_providers.dart';
import 'services/widget_service.dart';
import 'services/notification_service.dart';
import 'services/habit_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Lets the Android widget tick a habit and call back into Dart even
  // when the app isn't running (see services/widget_service.dart).
  await WidgetService.registerBackgroundCallback();

  await NotificationService.instance.init();
  // Re-arm every habit's daily reminder on launch, in case the OS cleared
  // scheduled alarms (e.g. after a reboot or app update).
  _resyncRemindersForCurrentUser(supabase: Supabase.instance.client);

  runApp(const ProviderScope(child: TickOffCloneApp()));
}

/// (Re)schedules every active habit's reminder. Called on app start with an
/// existing session and again whenever the user signs in, so reminders survive
/// app restarts, logins, and OS-cleared alarms.
void _resyncRemindersForCurrentUser({required SupabaseClient supabase}) {
  if (supabase.auth.currentUser == null) return;

  unawaited(() async {
    try {
      final habits = await HabitService().fetchHabits();
      await NotificationService.instance.resyncAll(habits);
    } catch (_) {
      // Non-fatal — reminders will still get (re)scheduled the next time
      // habits are created/edited.
    }
  }());

  supabase.auth.onAuthStateChange.listen((data) {
    if (data.session != null) {
      unawaited(() async {
        try {
          final habits = await HabitService().fetchHabits();
          await NotificationService.instance.resyncAll(habits);
        } catch (_) {
          // Non-fatal.
        }
      }());
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
