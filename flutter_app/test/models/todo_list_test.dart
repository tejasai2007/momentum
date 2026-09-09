import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tickoff_clone/models/todo_list.dart';

void main() {
  group('TodoList', () {
    final created = DateTime(2026, 9, 9, 10, 0, 0);

    test('fromMap parses fields and hex color', () {
      final map = {
        'id': 'list-1',
        'user_id': 'user-1',
        'name': 'Work',
        'color': '#0984E3',
        'icon': 'work',
        'sort_order': 1,
        'created_at': '2026-09-09T10:00:00.000Z',
      };

      final list = TodoList.fromMap(map);
      expect(list.id, 'list-1');
      expect(list.userId, 'user-1');
      expect(list.name, 'Work');
      expect(list.color, const Color(0xFF0984E3));
      expect(list.icon, 'work');
      expect(list.sortOrder, 1);
      expect(list.createdAt, DateTime.parse('2026-09-09T10:00:00.000Z'));
    });

    test('fromMap applies defaults when fields missing', () {
      final list = TodoList.fromMap({
        'id': 'list-2',
        'user_id': 'user-1',
        'name': 'Personal',
        'created_at': '2026-09-09T10:00:00.000Z',
      });
      expect(list.color, const Color(0xFF6C5CE7));
      expect(list.icon, 'list');
      expect(list.sortOrder, 0);
    });

    test('toInsertMap serializes color hex and excludes user_id', () {
      final list = TodoList(
        id: 'list-1',
        userId: 'user-1',
        name: 'Homework',
        color: const Color(0xFFE17055),
        icon: 'study',
        sortOrder: 2,
        createdAt: created,
      );

      final map = list.toInsertMap();
      expect(map['name'], 'Homework');
      expect(map['color'], '#E17055');
      expect(map['icon'], 'study');
      expect(map['sort_order'], 2);
      expect(map.containsKey('user_id'), isFalse);
      expect(map['created_at'], created.toIso8601String());
    });

    test('copyWith produces modified copy without mutating original', () {
      final original = TodoList(
        id: 'list-1',
        userId: 'user-1',
        name: 'Original',
        color: const Color(0xFF6C5CE7),
        icon: 'list',
        sortOrder: 0,
        createdAt: created,
      );

      final updated = original.copyWith(name: 'Renamed', color: const Color(0xFF00B894));

      expect(updated.name, 'Renamed');
      expect(updated.color, const Color(0xFF00B894));
      expect(updated.icon, 'list');
      expect(original.name, 'Original');
      expect(original.color, const Color(0xFF6C5CE7));
    });
  });
}
