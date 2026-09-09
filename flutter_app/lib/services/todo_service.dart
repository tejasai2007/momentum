import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/todo_item.dart';
import '../models/todo_list.dart';

class TodoService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _uid => _client.auth.currentUser!.id;

  // ---------------- Lists ----------------

  Future<List<TodoList>> fetchLists() async {
    final rows = await _client
        .from('todo_lists')
        .select()
        .eq('user_id', _uid)
        .order('sort_order', ascending: true);
    return (rows as List).map((r) => TodoList.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<TodoList> createList(TodoList list) async {
    final map = list.toInsertMap()..['user_id'] = _uid;
    final row = await _client.from('todo_lists').insert(map).select().single();
    return TodoList.fromMap(row);
  }

  Future<TodoList> updateList(String id, Map<String, dynamic> changes) async {
    final row = await _client.from('todo_lists').update(changes).eq('id', id).select().single();
    return TodoList.fromMap(row);
  }

  Future<void> deleteList(String id) async {
    // Deleting a list removes all of its todos too.
    await _client.from('todo_items').delete().eq('list_id', id);
    await _client.from('todo_lists').delete().eq('id', id);
  }

  // ---------------- Items ----------------

  Future<List<TodoItem>> fetchItems(String listId) async {
    final rows = await _client
        .from('todo_items')
        .select()
        .eq('list_id', listId)
        .order('is_completed', ascending: true)
        .order('sort_order', ascending: true);
    return (rows as List).map((r) => TodoItem.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<TodoItem> createItem(TodoItem item) async {
    final map = item.toInsertMap()..['user_id'] = _uid;
    final row = await _client.from('todo_items').insert(map).select().single();
    return TodoItem.fromMap(row);
  }

  Future<TodoItem> updateItem(String id, Map<String, dynamic> changes) async {
    final row = await _client.from('todo_items').update(changes).eq('id', id).select().single();
    return TodoItem.fromMap(row);
  }

  Future<void> deleteItem(String id) => _client.from('todo_items').delete().eq('id', id);
}
