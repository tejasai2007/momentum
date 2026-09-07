import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/app_providers.dart';
import 'add_journal_entry_screen.dart';

class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(journalEntriesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Journal')),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Something went wrong: $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Text('Your journey timeline is empty.\nAdd a note or photo to get started.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500])),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(journalEntriesProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final e = entries[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat.yMMMd().format(e.entryDate),
                            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        const SizedBox(height: 4),
                        if (e.title != null && e.title!.isNotEmpty)
                          Text(e.title!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        if (e.body != null && e.body!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(e.body!),
                        ],
                        if (e.imagePaths.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 90,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: e.imagePaths.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, j) => _JournalThumb(path: e.imagePaths[j]),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddJournalEntryScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New entry'),
      ),
    );
  }
}

class _JournalThumb extends ConsumerWidget {
  final String path;
  const _JournalThumb({required this.path});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String>(
      future: ref.read(journalServiceProvider).signedUrlFor(path),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12)),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(snapshot.data!, width: 90, height: 90, fit: BoxFit.cover),
        );
      },
    );
  }
}
