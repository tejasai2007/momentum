import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/journal_entry.dart';
import '../../providers/app_providers.dart';

class AddJournalEntryScreen extends ConsumerStatefulWidget {
  final String? habitId;
  const AddJournalEntryScreen({super.key, this.habitId});

  @override
  ConsumerState<AddJournalEntryScreen> createState() => _AddJournalEntryScreenState();
}

class _AddJournalEntryScreenState extends ConsumerState<AddJournalEntryScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final List<File> _images = [];
  String? _habitId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _habitId = widget.habitId;
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _images.add(File(picked.path)));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final journalService = ref.read(journalServiceProvider);
      final paths = <String>[];
      for (final img in _images) {
        paths.add(await journalService.uploadImage(img));
      }
      final entry = JournalEntry(
        id: '',
        userId: '',
        habitId: _habitId,
        entryDate: DateTime.now(),
        title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
        imagePaths: paths,
        createdAt: DateTime.now(),
      );
      await ref.read(journalEntriesProvider.notifier).addEntry(entry);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('New journal entry')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Title (optional)')),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyCtrl,
            maxLines: 5,
            decoration: const InputDecoration(labelText: "What's on your mind?", alignLabelWithHint: true),
          ),
          const SizedBox(height: 16),
          if (habits.isNotEmpty)
            DropdownButtonFormField<String?>(
              value: _habitId,
              decoration: const InputDecoration(labelText: 'Link to a habit (optional)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('No habit')),
                ...habits.map((h) => DropdownMenuItem(value: h.id, child: Text(h.name))),
              ],
              onChanged: (v) => setState(() => _habitId = v),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ..._images.map((img) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(img, width: 90, height: 90, fit: BoxFit.cover),
                  )),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_a_photo_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save entry'),
          ),
        ],
      ),
    );
  }
}
