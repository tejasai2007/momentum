import 'package:flutter_test/flutter_test.dart';
import 'package:tickoff_clone/models/todo_item.dart';

void main() {
  group('TodoItem', () {
    final createdAt = DateTime(2026, 9, 9, 10, 0, 0);

    test('fromMap parses all fields', () {
      final map = {
        'id': 'item-1',
        'list_id': 'list-1',
        'user_id': 'user-1',
        'title': 'Buy groceries',
        'notes': 'Milk and eggs',
        'is_completed': true,
        'due_date': '2026-09-10',
        'priority': 2,
        'completed_at': '2026-09-09T11:00:00.000Z',
        'sort_order': 0,
        'created_at': '2026-09-09T10:00:00.000Z',
      };

      final item = TodoItem.fromMap(map);
      expect(item.id, 'item-1');
      expect(item.listId, 'list-1');
      expect(item.userId, 'user-1');
      expect(item.title, 'Buy groceries');
      expect(item.notes, 'Milk and eggs');
      expect(item.isCompleted, isTrue);
      expect(item.dueDate, DateTime.parse('2026-09-10'));
      expect(item.priority, 2);
      expect(item.completedAt, DateTime.parse('2026-09-09T11:00:00.000Z'));
      expect(item.sortOrder, 0);
      expect(item.createdAt, DateTime.parse('2026-09-09T10:00:00.000Z'));
    });

    test('fromMap applies defaults for missing optional fields', () {
      final item = TodoItem.fromMap({
        'id': 'item-2',
        'list_id': 'list-1',
        'user_id': 'user-1',
        'title': 'Simple task',
        'created_at': '2026-09-09T10:00:00.000Z',
      });
      expect(item.notes, isNull);
      expect(item.isCompleted, isFalse);
      expect(item.dueDate, isNull);
      expect(item.priority, 0);
    });

    test('toInsertMap serializes fields and excludes user_id', () {
      final item = TodoItem(
        id: 'item-1',
        listId: 'list-1',
        userId: 'user-1',
        title: 'Read a book',
        notes: 'Chapter 3',
        isCompleted: false,
        dueDate: DateTime(2026, 9, 12),
        priority: 1,
        completedAt: null,
        sortOrder: 5,
        createdAt: createdAt,
      );

      final map = item.toInsertMap();
      expect(map['list_id'], 'list-1');
      expect(map['title'], 'Read a book');
      expect(map['notes'], 'Chapter 3');
      expect(map['is_completed'], isFalse);
      expect(map['due_date'], '2026-09-12');
      expect(map['priority'], 1);
      expect(map['sort_order'], 5);
      expect(map.containsKey('user_id'), isFalse);
    });

    test('copyWith produces modified copy without mutating original', () {
      final original = TodoItem(
        id: 'item-1',
        listId: 'list-1',
        userId: 'user-1',
        title: 'Original',
        notes: null,
        isCompleted: false,
        dueDate: null,
        priority: 0,
        completedAt: null,
        sortOrder: 0,
        createdAt: createdAt,
      );

      final completed = original.copyWith(
        isCompleted: true,
        completedAt: DateTime(2026, 9, 9, 12, 0, 0),
      );

      expect(completed.isCompleted, isTrue);
      expect(completed.completedAt, DateTime(2026, 9, 9, 12, 0, 0));
      expect(completed.title, 'Original');
      expect(original.isCompleted, isFalse);
      expect(original.completedAt, isNull);
    });
  });
}
