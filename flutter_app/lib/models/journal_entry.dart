class JournalEntry {
  final String id;
  final String userId;
  final String? habitId;
  final DateTime entryDate;
  final String? title;
  final String? body;
  final List<String> imagePaths; // storage object paths
  final DateTime createdAt;

  JournalEntry({
    required this.id,
    required this.userId,
    this.habitId,
    required this.entryDate,
    this.title,
    this.body,
    required this.imagePaths,
    required this.createdAt,
  });

  factory JournalEntry.fromMap(Map<String, dynamic> map) => JournalEntry(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        habitId: map['habit_id'] as String?,
        entryDate: DateTime.parse(map['entry_date'] as String),
        title: map['title'] as String?,
        body: map['body'] as String?,
        imagePaths: (map['image_paths'] as List?)?.map((e) => e as String).toList() ?? [],
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'habit_id': habitId,
        'entry_date': entryDate.toIso8601String().split('T').first,
        'title': title,
        'body': body,
        'image_paths': imagePaths,
      };

  JournalEntry copyWith({
    String? id,
    String? userId,
    String? habitId,
    DateTime? entryDate,
    String? title,
    String? body,
    List<String>? imagePaths,
    DateTime? createdAt,
  }) =>
      JournalEntry(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        habitId: habitId ?? this.habitId,
        entryDate: entryDate ?? this.entryDate,
        title: title ?? this.title,
        body: body ?? this.body,
        imagePaths: imagePaths ?? this.imagePaths,
        createdAt: createdAt ?? this.createdAt,
      );
}

