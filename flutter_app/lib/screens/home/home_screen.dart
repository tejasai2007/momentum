import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../providers/app_providers.dart';
import 'habits_tab.dart';
import '../journal/journal_screen.dart';
import '../settings/settings_screen.dart';
import '../todo/todo_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  int _index = 0;
  static const MethodChannel _widgetSyncChannel = MethodChannel('tickoffclone/widget_sync');

  final _pages = const [
    HabitsTab(),
    TodoScreen(),
    JournalScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _widgetSyncChannel.setMethodCallHandler(_handleWidgetSync);
  }

  Future<void> _handleWidgetSync(MethodCall call) async {
    if (call.method == 'onHabitToggled') {
      ref.invalidate(habitsProvider);
      ref.invalidate(weekLogsProvider);
    }
  }

  @override
  void dispose() {
    _widgetSyncChannel.setMethodCallHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The Android widget can tick a habit while this app is backgrounded or
    // fully closed. Refresh on every resume so the in-app UI always reflects
    // the latest Supabase state instead of a stale cached one.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(habitsProvider);
      ref.invalidate(weekLogsProvider);
      ref.invalidate(journalEntriesProvider);
      ref.invalidate(todoListsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.check_circle_outline_rounded), selectedIcon: Icon(Icons.check_circle_rounded), label: 'Habits'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist_rounded), label: 'Todos'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: 'Journal'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}
