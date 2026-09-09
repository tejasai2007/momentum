import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/todo_item.dart';
import '../../models/todo_list.dart';
import '../../providers/app_providers.dart';

class TodoListDetailScreen extends ConsumerStatefulWidget {
  final TodoList list;
  const TodoListDetailScreen({super.key, required this.list});

  @override
  ConsumerState<TodoListDetailScreen> createState() => _TodoListDetailScreenState();
}

class _TodoListDetailScreenState extends ConsumerState<TodoListDetailScreen> {
  final TextEditingController _quickAddCtrl = TextEditingController();

  @override
  void dispose() {
    _quickAddCtrl.dispose();
    super.dispose();
  }

  Future<void> _quickAdd() async {
    final title = _quickAddCtrl.text.trim();
    if (title.isEmpty) return;
    _quickAddCtrl.clear();
    try {
      final item = TodoItem(
        id: '',
        listId: widget.list.id,
        userId: '',
        title: title,
        isCompleted: false,
        priority: 0,
        sortOrder: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        createdAt: DateTime.now(),
      );
      await ref.read(todoItemsProvider(widget.list.id).notifier).addItem(item);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding task: $e')),
        );
      }
    }
  }

  Future<void> _toggle(TodoItem item) async {
    try {
      await ref.read(todoItemsProvider(widget.list.id).notifier).updateItem(item.id, {
        'is_completed': !item.isCompleted,
        'completed_at': item.isCompleted ? null : DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating task: $e')),
        );
      }
    }
  }

  void _edit(TodoItem item) {
    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ItemEditDialog(existing: item),
    ).then((result) async {
      if (result == null) return;
      try {
        await ref.read(todoItemsProvider(widget.list.id).notifier).updateItem(item.id, result);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating task: $e')),
          );
        }
      }
    });
  }

  void _addNew() {
    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _ItemEditDialog(),
    ).then((result) async {
      if (result == null) return;
      try {
        final item = TodoItem(
          id: '',
          listId: widget.list.id,
          userId: '',
          title: result['title'] as String,
          notes: result['notes'] as String?,
          isCompleted: false,
          dueDate: result['due_date'] as DateTime?,
          priority: result['priority'] as int,
          sortOrder: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          createdAt: DateTime.now(),
        );
        await ref.read(todoItemsProvider(widget.list.id).notifier).addItem(item);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding task: $e')),
          );
        }
      }
    });
  }

  Future<void> _delete(TodoItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('"${item.title}" will be removed permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(todoItemsProvider(widget.list.id).notifier).deleteItem(item.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting task: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(todoItemsProvider(widget.list.id));
    final color = widget.list.color;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(todoListIconMap[widget.list.icon] ?? Icons.list_rounded, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.list.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showListMenu(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick add
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quickAddCtrl,
                    decoration: InputDecoration(
                      hintText: 'Quick add a task…',
                      prefixIcon: Icon(Icons.add, color: color),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _quickAdd(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addNew,
                  icon: const Icon(Icons.tune),
                  tooltip: 'Add with details',
                ),
              ],
            ),
          ),
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Something went wrong: $e')),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'Nothing here yet.\nAdd your first task above.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(todoItemsProvider(widget.list.id).notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: items.length,
                    itemBuilder: (context, i) => _buildItemCard(items[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showListMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit list'),
              onTap: () {
                Navigator.pop(sheetContext);
                _editList();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Delete list', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(sheetContext);
                _deleteList();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editList() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ListEditDialog(existing: widget.list),
    );
    if (result == null) return;
    try {
      await ref.read(todoListsProvider.notifier).updateList(widget.list.id, result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating list: $e')),
        );
      }
    }
  }

  Future<void> _deleteList() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete list?'),
        content: Text('"${widget.list.name}" and its tasks will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(todoListsProvider.notifier).deleteList(widget.list.id);
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting list: $e')),
          );
        }
      }
    }
  }

  Widget _buildItemCard(TodoItem item) {
    final color = widget.list.color;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _edit(item),
        onLongPress: () => _delete(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              InkWell(
                onTap: () => _toggle(item),
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    item.isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: item.isCompleted ? color : Colors.grey[400],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        decoration: item.isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: item.isCompleted ? Colors.grey : null,
                      ),
                    ),
                    if (item.notes != null && item.notes!.isNotEmpty)
                      Text(
                        item.notes!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    if (item.dueDate != null)
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat.yMMMd().format(item.dueDate!),
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (item.priority > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _priorityColor(item.priority).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _priorityLabel(item.priority),
                    style: TextStyle(fontSize: 11, color: _priorityColor(item.priority)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _priorityColor(int p) {
    switch (p) {
      case 1:
        return const Color(0xFF0984E3);
      case 2:
        return const Color(0xFFE17055);
      case 3:
        return const Color(0xFFD63031);
      default:
        return Colors.grey;
    }
  }

  String _priorityLabel(int p) {
    switch (p) {
      case 1:
        return 'Low';
      case 2:
        return 'Med';
      case 3:
        return 'High';
      default:
        return '';
    }
  }
}

class _ItemEditDialog extends StatefulWidget {
  final TodoItem? existing;
  const _ItemEditDialog({this.existing});

  @override
  State<_ItemEditDialog> createState() => _ItemEditDialogState();
}

class _ItemEditDialogState extends State<_ItemEditDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;
  DateTime? _dueDate;
  int _priority = 0;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _notesCtrl = TextEditingController(text: widget.existing?.notes ?? '');
    _dueDate = widget.existing?.dueDate;
    _priority = widget.existing?.priority ?? 0;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop({
      'title': title,
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      'due_date': _dueDate,
      'priority': _priority,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New task' : 'Edit task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _dueDate == null ? 'No due date' : DateFormat.yMMMd().format(_dueDate!),
                    ),
                    const Spacer(),
                    if (_dueDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _dueDate = null),
                        child: const Icon(Icons.close, size: 16),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Priority'),
                const Spacer(),
                for (final (prio, label) in const [(0, 'None'), (1, 'Low'), (2, 'Med'), (3, 'High')])
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _priority == prio,
                      onSelected: (_) => setState(() => _priority = prio),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _ListEditDialog extends StatefulWidget {
  final TodoList existing;
  const _ListEditDialog({required this.existing});

  @override
  State<_ListEditDialog> createState() => _ListEditDialogState();
}

class _ListEditDialogState extends State<_ListEditDialog> {
  late final TextEditingController _nameCtrl;
  late Color _color;
  late String _icon;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing.name);
    _color = widget.existing.color;
    _icon = widget.existing.icon;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop({
      'name': name,
      'color': '#${_color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
      'icon': _icon,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit list'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'List name'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: todoListIconMap.entries.map((e) {
                final selected = e.key == _icon;
                return InkWell(
                  onTap: () => setState(() => _icon = e.key),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected ? _color.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(7),
                    child: Icon(e.value, color: selected ? _color : Colors.grey, size: 20),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: habitColorPalette.map((c) {
                final selected = c.toARGB32() == _color.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: selected ? Border.all(color: Colors.white, width: 2) : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
