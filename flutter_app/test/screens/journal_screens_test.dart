import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tickoff_clone/models/journal_entry.dart';
import 'package:tickoff_clone/screens/journal/add_journal_entry_screen.dart';
import 'package:tickoff_clone/screens/journal/journal_detail_screen.dart';

void main() {
  final testEntry = JournalEntry(
    id: 'test-entry-1',
    userId: 'user-1',
    habitId: null,
    entryDate: DateTime(2026, 9, 9),
    title: 'Daily Reflection',
    body: 'Had a wonderful and productive day.',
    imagePaths: [],
    createdAt: DateTime(2026, 9, 9),
  );

  testWidgets('JournalDetailScreen renders title, body, and action buttons', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: JournalDetailScreen(entry: testEntry),
        ),
      ),
    );

    expect(find.text('Journal Entry'), findsOneWidget);
    expect(find.text('Daily Reflection'), findsOneWidget);
    expect(find.text('Had a wonderful and productive day.'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('AddEditJournalEntryScreen renders edit mode with pre-filled fields', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AddEditJournalEntryScreen(existing: testEntry),
        ),
      ),
    );

    expect(find.text('Edit journal entry'), findsOneWidget);
    expect(find.text('Daily Reflection'), findsOneWidget);
    expect(find.text('Had a wonderful and productive day.'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
  });

  testWidgets('AddEditJournalEntryScreen renders new entry mode', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AddEditJournalEntryScreen(),
        ),
      ),
    );

    expect(find.text('New journal entry'), findsOneWidget);
    expect(find.text('Save entry'), findsOneWidget);
  });
}
