import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/journal_entry.dart';
import '../../providers/app_providers.dart';
import '../../widgets/full_screen_image_viewer.dart';
import '../../widgets/habit_card.dart';
import '../habit/habit_detail_screen.dart';
import 'add_journal_entry_screen.dart';

class JournalDetailScreen extends ConsumerWidget {
  final JournalEntry entry;

  const JournalDetailScreen({
    super.key,
    required this.entry,
  });

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, JournalEntry currentEntry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete journal entry?'),
        content: const Text(
          'This will permanently delete this journal entry and its attached photos. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(journalEntriesProvider.notifier).deleteEntry(
            currentEntry.id,
            imagePaths: currentEntry.imagePaths,
          );
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Journal entry deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch journal entries to reactively reflect edits in real-time.
    final entriesAsync = ref.watch(journalEntriesProvider);
    final currentEntry = entriesAsync.valueOrNull?.firstWhere(
          (e) => e.id == entry.id,
          orElse: () => entry,
        ) ??
        entry;

    // Watch habits to display linked habit metadata
    final habits = ref.watch(habitsProvider).valueOrNull ?? [];
    final linkedHabit = currentEntry.habitId != null
        ? habits.where((h) => h.id == currentEntry.habitId).firstOrNull
        : null;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal Entry'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit entry',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AddEditJournalEntryScreen(existing: currentEntry),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete entry',
            onPressed: () => _confirmDelete(context, ref, currentEntry),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Date header
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                DateFormat.yMMMMEEEEd().format(currentEntry.entryDate),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Linked habit chip
          if (linkedHabit != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: Icon(
                  habitIconMap[linkedHabit.icon] ?? Icons.star_rounded,
                  size: 18,
                  color: linkedHabit.color,
                ),
                label: Text(
                  linkedHabit.name,
                  style: TextStyle(
                    color: linkedHabit.color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                backgroundColor: linkedHabit.color.withValues(alpha: 0.12),
                side: BorderSide(color: linkedHabit.color.withValues(alpha: 0.25)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => HabitDetailScreen(habit: linkedHabit)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Title
          if (currentEntry.title != null && currentEntry.title!.isNotEmpty) ...[
            Text(
              currentEntry.title!,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 14),
          ],

          // Body
          if (currentEntry.body != null && currentEntry.body!.isNotEmpty) ...[
            SelectableText(
              currentEntry.body!,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Photos
          if (currentEntry.imagePaths.isNotEmpty) ...[
            Text(
              'Photos (${currentEntry.imagePaths.length})',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: currentEntry.imagePaths.length == 1 ? 1 : 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: currentEntry.imagePaths.length == 1 ? 1.4 : 1.0,
              ),
              itemCount: currentEntry.imagePaths.length,
              itemBuilder: (context, i) {
                final path = currentEntry.imagePaths[i];
                return GestureDetector(
                  onTap: () => FullScreenImageViewer.show(
                    context,
                    imagePaths: currentEntry.imagePaths,
                    initialIndex: i,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        FutureBuilder<String>(
                          future: ref.read(journalServiceProvider).signedUrlFor(path),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Container(
                                color: isDark ? const Color(0xFF1E1E22) : Colors.grey[200],
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              );
                            }
                            return Image.network(
                              snapshot.data!,
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.fullscreen,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }
}
