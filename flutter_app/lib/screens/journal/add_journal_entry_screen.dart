import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/journal_entry.dart';
import '../../providers/app_providers.dart';

class AddEditJournalEntryScreen extends ConsumerStatefulWidget {
  final JournalEntry? existing;
  final String? habitId;

  const AddEditJournalEntryScreen({
    super.key,
    this.existing,
    this.habitId,
  });

  @override
  ConsumerState<AddEditJournalEntryScreen> createState() => _AddEditJournalEntryScreenState();
}

// Backwards compatibility alias
typedef AddJournalEntryScreen = AddEditJournalEntryScreen;

class _AddEditJournalEntryScreenState extends ConsumerState<AddEditJournalEntryScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  late DateTime _entryDate;
  late List<String> _existingImagePaths;
  final List<String> _removedImagePaths = [];
  final List<File> _newImages = [];
  String? _habitId;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleCtrl = TextEditingController(text: existing?.title ?? '');
    _bodyCtrl = TextEditingController(text: existing?.body ?? '');
    _entryDate = existing?.entryDate ?? DateTime.now();
    _habitId = existing?.habitId ?? widget.habitId;
    _existingImagePaths = List<String>.from(existing?.imagePaths ?? []);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _newImages.add(File(picked.path)));
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _entryDate) {
      setState(() => _entryDate = picked);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final journalService = ref.read(journalServiceProvider);
      final uploadedPaths = <String>[];
      for (final img in _newImages) {
        uploadedPaths.add(await journalService.uploadImage(img));
      }

      final allImagePaths = [..._existingImagePaths, ...uploadedPaths];
      final title = _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim();
      final body = _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim();

      if (_isEditing) {
        final changes = {
          'title': title,
          'body': body,
          'habit_id': _habitId,
          'entry_date': _entryDate.toIso8601String().split('T').first,
          'image_paths': allImagePaths,
        };

        await ref.read(journalEntriesProvider.notifier).updateEntry(
              widget.existing!.id,
              changes,
              imagesToDelete: _removedImagePaths,
            );
      } else {
        final entry = JournalEntry(
          id: '',
          userId: '',
          habitId: _habitId,
          entryDate: _entryDate,
          title: title,
          body: body,
          imagePaths: allImagePaths,
          createdAt: DateTime.now(),
        );
        await ref.read(journalEntriesProvider.notifier).addEntry(entry);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Journal entry updated' : 'Journal entry created'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsProvider).valueOrNull ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit journal entry' : 'New journal entry'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Date selector row
          InkWell(
            onTap: _selectDate,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1F) : Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Entry Date',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat.yMMMMd().format(_entryDate),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Title (optional)'),
          ),
          const SizedBox(height: 12),

          // Body
          TextField(
            controller: _bodyCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: "What's on your mind?",
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),

          // Habit association
          if (habits.isNotEmpty)
            DropdownButtonFormField<String?>(
              initialValue: _habitId,
              decoration: const InputDecoration(labelText: 'Link to a habit (optional)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('No habit')),
                ...habits.map((h) => DropdownMenuItem(value: h.id, child: Text(h.name))),
              ],
              onChanged: (v) => setState(() => _habitId = v),
            ),
          const SizedBox(height: 20),

          // Photos header
          Text(
            'Photos (${_existingImagePaths.length + _newImages.length})',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 10),

          // Photos wrap
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // Existing photos
              ..._existingImagePaths.map(
                (path) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 90,
                        height: 90,
                        child: FutureBuilder<String>(
                          future: ref.read(journalServiceProvider).signedUrlFor(path),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Container(
                                color: Colors.grey[300],
                                child: const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              );
                            }
                            return Image.network(snapshot.data!, fit: BoxFit.cover);
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _existingImagePaths.remove(path);
                            _removedImagePaths.add(path);
                          });
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(3),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Newly added local images
              ..._newImages.map(
                (img) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(img, width: 90, height: 90, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () => setState(() => _newImages.remove(img)),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(3),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Add photo button
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white24 : Colors.grey[400]!,
                      style: BorderStyle.solid,
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 26,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Save button
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(_isEditing ? 'Save changes' : 'Save entry'),
          ),
        ],
      ),
    );
  }
}
