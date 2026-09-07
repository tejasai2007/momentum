import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/app_providers.dart';
import '../../services/notification_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _requestReminderPermissions(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final results = await NotificationService.instance.requestAllPermissions();

    final granted = <String>[];
    final pending = <String>[];
    if (results[AlarmPermission.notifications] == true) {
      granted.add('Notifications');
    } else {
      pending.add('Notifications');
    }
    if (results[AlarmPermission.exactAlarms] == true) {
      granted.add('Exact alarms');
    } else {
      pending.add('Exact alarms');
    }
    if (results[AlarmPermission.fullScreenNotifications] == true) {
      granted.add('Full-screen alerts');
    } else {
      pending.add('Full-screen alerts');
    }
    if (results[AlarmPermission.ignoreBatteryOptimizations] == true) {
      granted.add('Battery optimization');
    } else {
      pending.add('Battery (background alarms)');
    }

    final parts = <String>[];
    if (pending.isEmpty) {
      parts.add('All reminder permissions are enabled.');
    } else {
      parts.add(
          'Allow in your phone\u2019s Settings: ${pending.join(', ')}.');
      if (granted.isNotEmpty) parts.add('Granted: ${granted.join(', ')}.');
    }
    messenger.showSnackBar(SnackBar(
      content: Text(parts.join('\n')),
      duration: const Duration(seconds: 6),
      action: pending.isEmpty
          ? null
          : SnackBarAction(
              label: 'OPEN SETTINGS',
              onPressed: openAppSettings,
            ),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final homeView = ref.watch(homeViewProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(user?.email ?? 'Signed in'),
              subtitle: const Text('Your account'),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Default home screen', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<HomeViewType>(
            segments: const [
              ButtonSegment(value: HomeViewType.streak, label: Text('Streak View')),
              ButtonSegment(value: HomeViewType.list, label: Text('List View')),
            ],
            selected: {homeView},
            onSelectionChanged: (s) => ref.read(homeViewProvider.notifier).state = s.first,
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.alarm_rounded),
              title: const Text('Reminder permissions'),
              subtitle: const Text('Allow notifications, exact alarms, and full-screen alerts so reminders fire on time.'),
              trailing: FilledButton.tonal(
                onPressed: () => _requestReminderPermissions(context),
                child: const Text('Request'),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.widgets_outlined),
              title: const Text('Home screen widget'),
              subtitle: const Text('Long-press your Android home screen → Widgets → Momentum to add it.'),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: () => ref.read(authServiceProvider).signOut(),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
