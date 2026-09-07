import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/config.dart';
import '../models/journal_entry.dart';

class JournalService {
  final SupabaseClient _client = Supabase.instance.client;
  final _uuid = const Uuid();

  String get _uid => _client.auth.currentUser!.id;

  Future<List<JournalEntry>> fetchEntries({String? habitId}) async {
    var query = _client.from('journal_entries').select().eq('user_id', _uid);
    if (habitId != null) {
      query = query.eq('habit_id', habitId);
    }
    final rows = await query.order('entry_date', ascending: false);
    return (rows as List).map((r) => JournalEntry.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Uploads a local image file to the private `journal-media` bucket under
  /// the user's own folder (required by the storage RLS policies) and
  /// returns the storage path to save on the entry.
  Future<String> uploadImage(File file) async {
    final ext = file.path.split('.').last;
    final path = '$_uid/${_uuid.v4()}.$ext';
    await _client.storage.from(AppConstants.journalBucket).upload(path, file);
    return path;
  }

  /// Journal photos live in a private bucket, so screens should render them
  /// via a short-lived signed URL rather than a public URL.
  Future<String> signedUrlFor(String path, {int expiresInSeconds = 3600}) {
    return _client.storage.from(AppConstants.journalBucket).createSignedUrl(path, expiresInSeconds);
  }

  Future<JournalEntry> createEntry(JournalEntry entry) async {
    final map = entry.toInsertMap()..['user_id'] = _uid;
    final row = await _client.from('journal_entries').insert(map).select().single();
    return JournalEntry.fromMap(row);
  }

  Future<JournalEntry> updateEntry(String id, Map<String, dynamic> changes) async {
    final row = await _client.from('journal_entries').update(changes).eq('id', id).select().single();
    return JournalEntry.fromMap(row);
  }

  Future<void> deleteEntry(String id) => _client.from('journal_entries').delete().eq('id', id);
}
