import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/habit.dart';
import '../../providers/app_providers.dart';
import '../../services/notification_service.dart';
import '../../widgets/habit_card.dart';

class AddEditHabitScreen extends ConsumerStatefulWidget {
  final Habit? existing;
  const AddEditHabitScreen({super.key, this.existing});

  @override
  ConsumerState<AddEditHabitScreen> createState() => _AddEditHabitScreenState();
}

class _AddEditHabitScreenState extends ConsumerState<AddEditHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late String _icon;
  late Color _color;
  late HabitFrequency _frequency;
  late int _target;
  TimeOfDay? _reminder;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final h = widget.existing;
    _nameCtrl = TextEditingController(text: h?.name ?? '');
    _icon = h?.icon ?? 'star';
    _color = h?.color ?? habitColorPalette.first;
    _frequency = h?.frequency ?? HabitFrequency.daily;
    _target = h?.targetPerPeriod ?? 1;
    _reminder = h?.reminderTime;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final habit = Habit(
        id: widget.existing?.id ?? '',
        userId: '',
        name: _nameCtrl.text.trim(),
        icon: _icon,
        color: _color,
        frequency: _frequency,
        targetPerPeriod: _target,
        reminderTime: _reminder,
        archived: false,
        sortOrder: widget.existing?.sortOrder ?? 0,
        createdAt: DateTime.now(),
      );

      if (_reminder != null) {
        await NotificationService.instance.ensureReminderPermissions();
      }

      if (widget.existing == null) {
        await ref.read(habitsProvider.notifier).addHabit(habit);
      } else {
        await ref.read(habitsProvider.notifier).updateHabit(widget.existing!.id, habit.toInsertMap());
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'New habit' : 'Edit habit')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Habit name', hintText: 'e.g. Drink water'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Give it a name' : null,
            ),
            const SizedBox(height: 24),
            const Text('Icon', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: habitIconMap.entries.map((e) {
                final selected = _icon == e.key;
                return GestureDetector(
                  onTap: () => setState(() => _icon = e.key),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: selected ? _color : _color.withOpacity(0.12),
                    child: Icon(e.value, color: selected ? Colors.white : _color),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text('Color', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: habitColorPalette.map((c) {
                final selected = _color.toARGB32() == c.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: selected ? Border.all(width: 3, color: Colors.black26) : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text('Frequency', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            SegmentedButton<HabitFrequency>(
              segments: const [
                ButtonSegment(value: HabitFrequency.daily, label: Text('Daily')),
                ButtonSegment(value: HabitFrequency.weekly, label: Text('Weekly')),
              ],
              selected: {_frequency},
              onSelectionChanged: (s) => setState(() => _frequency = s.first),
            ),
            if (_frequency == HabitFrequency.weekly) ...[
              const SizedBox(height: 16),
              Text('Times per week: $_target'),
              Slider(
                value: _target.toDouble(),
                min: 1,
                max: 7,
                divisions: 6,
                label: '$_target',
                onChanged: (v) => setState(() => _target = v.round()),
              ),
            ],
            const SizedBox(height: 24),
            const Text('Reminder', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.alarm_rounded),
              title: Text(_reminder == null ? 'No reminder set' : _reminder!.format(context)),
              trailing: _reminder != null
                  ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _reminder = null))
                  : null,
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: _reminder ?? TimeOfDay.now());
                if (t != null) setState(() => _reminder = t);
              },
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(widget.existing == null ? 'Create habit' : 'Save changes'),
            ),
            if (widget.existing != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () async {
                  await ref.read(habitsProvider.notifier).archiveHabit(widget.existing!.id);
                  if (mounted) Navigator.of(context).pop();
                },
                child: const Text('Archive habit'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
