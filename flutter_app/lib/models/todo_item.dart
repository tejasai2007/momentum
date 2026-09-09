class TodoItem {
  final String id;
  final String listId;
  final String userId;
  final String title;
  final String? notes;
  final bool isCompleted;
  final DateTime? dueDate;
  final int priority; // 0=none, 1=low, 2=medium, 3=high
  final DateTime? completedAt;
  final int sortOrder;
  final DateTime createdAt;

  const TodoItem({
    required this.id,
    required this.listId,
    required this.userId,
    required this.title,
    this.notes,
    required this.isCompleted,
    this.dueDate,
    required this.priority,
    this.completedAt,
    required this.sortOrder,
    required this.createdAt,
  });

  factory TodoItem.fromMap(Map<String, dynamic> map) {
    return TodoItem(
      id: map['id'] as String,
      listId: map['list_id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      notes: map['notes'] as String?,
      isCompleted: map['is_completed'] as bool? ?? false,
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date'] as String) : null,
      priority: map['priority'] as int? ?? 0,
      completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at'] as String) : null,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'list_id': listId,
        'title': title,
        'notes': notes,
        'is_completed': isCompleted,
        'due_date': dueDate?.toIso8601String().split('T').first,
        'priority': priority,
        'completed_at': completedAt?.toIso8601String(),
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
      };

  TodoItem copyWith({
    String? id,
    String? listId,
    String? userId,
    String? title,
    String? notes,
    bool? isCompleted,
    DateTime? dueDate,
    int? priority,
    DateTime? completedAt,
    int? sortOrder,
    DateTime? createdAt,
  }) =>
      TodoItem(
        id: id ?? this.id,
        listId: listId ?? this.listId,
        userId: userId ?? this.userId,
        title: title ?? this.title,
        notes: notes ?? this.notes,
        isCompleted: isCompleted ?? this.isCompleted,
        dueDate: dueDate ?? this.dueDate,
        priority: priority ?? this.priority,
        completedAt: completedAt ?? this.completedAt,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
      );
}
