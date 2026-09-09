import 'package:flutter_test/flutter_test.dart';
import 'package:tickoff_clone/models/journal_entry.dart';

void main() {
  group('JournalEntry', () {
    final testDate = DateTime(2026, 9, 9, 12, 0, 0);
    final testCreated = DateTime(2026, 9, 9, 12, 5, 0);

    test('creates and serializes correctly to map', () {
      final entry = JournalEntry(
        id: 'entry-123',
        userId: 'user-abc',
        habitId: 'habit-456',
        entryDate: testDate,
        title: 'Great Workout',
        body: 'Ran 5k and felt energized.',
        imagePaths: ['user-abc/img1.jpg', 'user-abc/img2.jpg'],
        createdAt: testCreated,
      );

      final insertMap = entry.toInsertMap();
      expect(insertMap['habit_id'], 'habit-456');
      expect(insertMap['entry_date'], '2026-09-09');
      expect(insertMap['title'], 'Great Workout');
      expect(insertMap['body'], 'Ran 5k and felt energized.');
      expect(insertMap['image_paths'], ['user-abc/img1.jpg', 'user-abc/img2.jpg']);
    });

    test('deserializes from map correctly', () {
      final map = {
        'id': 'entry-999',
        'user_id': 'user-xyz',
        'habit_id': 'habit-789',
        'entry_date': '2026-09-09',
        'title': 'Morning Reflections',
        'body': 'Clear skies today.',
        'image_paths': ['photo1.png'],
        'created_at': '2026-09-09T10:00:00.000Z',
      };

      final entry = JournalEntry.fromMap(map);
      expect(entry.id, 'entry-999');
      expect(entry.userId, 'user-xyz');
      expect(entry.habitId, 'habit-789');
      expect(entry.entryDate, DateTime.parse('2026-09-09'));
      expect(entry.title, 'Morning Reflections');
      expect(entry.body, 'Clear skies today.');
      expect(entry.imagePaths, ['photo1.png']);
      expect(entry.createdAt, DateTime.parse('2026-09-09T10:00:00.000Z'));
    });

    test('copyWith produces modified copy without mutating original', () {
      final original = JournalEntry(
        id: '1',
        userId: 'u1',
        habitId: 'h1',
        entryDate: testDate,
        title: 'Original Title',
        body: 'Original Body',
        imagePaths: ['img1.jpg'],
        createdAt: testCreated,
      );

      final updated = original.copyWith(
        title: 'Updated Title',
        imagePaths: ['img1.jpg', 'img2.jpg'],
      );

      expect(updated.id, original.id);
      expect(updated.title, 'Updated Title');
      expect(updated.body, 'Original Body');
      expect(updated.imagePaths.length, 2);
      expect(original.title, 'Original Title');
      expect(original.imagePaths.length, 1);
    });
  });
}
