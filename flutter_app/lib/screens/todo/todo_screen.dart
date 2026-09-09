import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/todo_list.dart';
import '../../providers/app_providers.dart';
import 'todo_list_detail_screen.dart';

class TodoScreen extends ConsumerWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(todoListsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Todos')),
      body: listsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Something went wrong: $e')),
        data: (lists) {
          if (lists.isEmpty) {
            return Center(
              child: Text(
                'No lists yet.\nCreate a list to start organizing your tasks.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500]),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(todoListsProvider.notifier).refresh(),
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.15,
              ),
              itemCount: lists.length,
              itemBuilder: (context, i) => _ListCard(list: lists[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditListSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New list'),
      ),
    );
  }

  Future<void> _showEditListSheet(BuildContext context, WidgetRef ref,
      {TodoList? existing}) async {
    final result = await showModalBottomSheet<_ListDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => _EditListSheet(existing: existing),
    );
    if (result == null) return;

    final notifier = ref.read(todoListsProvider.notifier);
    try {
      if (existing == null) {
        final list = TodoList(
          id: '',
          userId: '',
          name: result.name,
          color: result.color,
          icon: result.icon,
          sortOrder: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          createdAt: DateTime.now(),
        );
        await notifier.addList(list);
      } else {
        await notifier.updateList(existing.id, {
          'name': result.name,
          'color': '#${result.color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
          'icon': result.icon,
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving list: $e')),
        );
      }
    }
  }
}

class _ListCard extends ConsumerWidget {
  final TodoList list;
  const _ListCard({required this.list});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = list.color;
    final items = ref.watch(todoItemsProvider(list.id)).valueOrNull ?? [];
    final done = items.where((i) => i.isCompleted).length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TodoListDetailScreen(list: list)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(todoListIconMap[list.icon] ?? Icons.list_rounded,
                    color: color, size: 22),
              ),
              const Spacer(),
              Text(
                list.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(
                '$done/${items.length} done',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListDraft {
  final String name;
  final Color color;
  final String icon;
  _ListDraft(this.name, this.color, this.icon);
}

class _EditListSheet extends StatefulWidget {
  final TodoList? existing;
  const _EditListSheet({this.existing});

  @override
  State<_EditListSheet> createState() => _EditListSheetState();
}

class _EditListSheetState extends State<_EditListSheet> {
  late final TextEditingController _nameCtrl;
  late Color _color;
  late String _icon;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _color = widget.existing?.color ?? const Color(0xFF6C5CE7);
    _icon = widget.existing?.icon ?? 'list';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existing == null ? 'New list' : 'Edit list',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'List name'),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          Text('Icon', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: GridView.count(
              crossAxisCount: 6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: todoListIconMap.entries.map((e) {
                final selected = e.key == _icon;
                return InkWell(
                  onTap: () => setState(() => _icon = e.key),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected
                          ? _color.withValues(alpha: 0.15)
                          : Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: selected ? Border.all(color: _color, width: 2) : null,
                    ),
                    child: Icon(e.value, color: selected ? _color : Colors.grey),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Text('Color', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: habitColorPalette.map((c) {
              final selected = c.toARGB32() == _color.toARGB32();
              return GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: Text(widget.existing == null ? 'Create list' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(_ListDraft(name, _color, _icon));
  }
}
