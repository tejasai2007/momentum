import 'package:flutter/material.dart';

enum HabitFrequency { daily, weekly, custom }

HabitFrequency frequencyFromString(String s) {
  switch (s) {
    case 'weekly':
      return HabitFrequency.weekly;
    case 'custom':
      return HabitFrequency.custom;
    default:
      return HabitFrequency.daily;
  }
}

String frequencyToString(HabitFrequency f) => f.name;

class Habit {
  final String id;
  final String userId;
  final String name;
  final String icon;
  final Color color;
  final HabitFrequency frequency;
  final List<int>? customDays; // 1=Mon .. 7=Sun
  final int targetPerPeriod;
  final TimeOfDay? reminderTime;
  final bool archived;
  final int sortOrder;
  final DateTime createdAt;

  Habit({
    required this.id,
    required this.userId,
    required this.name,
    required this.icon,
    required this.color,
    required this.frequency,
    this.customDays,
    required this.targetPerPeriod,
    this.reminderTime,
    required this.archived,
    required this.sortOrder,
    required this.createdAt,
  });

  factory Habit.fromMap(Map<String, dynamic> map) {
    TimeOfDay? reminder;
    if (map['reminder_time'] != null) {
      final parts = (map['reminder_time'] as String).split(':');
      reminder = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    return Habit(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String? ?? 'star',
      color: _colorFromHex(map['color'] as String? ?? '#6C5CE7'),
      frequency: frequencyFromString(map['frequency'] as String? ?? 'daily'),
      customDays: (map['custom_days'] as List?)?.map((e) => e as int).toList(),
      targetPerPeriod: map['target_per_period'] as int? ?? 1,
      reminderTime: reminder,
      archived: map['archived'] as bool? ?? false,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'name': name,
        'icon': icon,
        'color': _hexFromColor(color),
        'frequency': frequencyToString(frequency),
        'custom_days': customDays,
        'target_per_period': targetPerPeriod,
        'reminder_time': reminderTime == null
            ? null
            : '${reminderTime!.hour.toString().padLeft(2, '0')}:${reminderTime!.minute.toString().padLeft(2, '0')}:00',
        'archived': archived,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
      };

  Habit copyWith({
    String? id,
    String? userId,
    String? name,
    String? icon,
    Color? color,
    HabitFrequency? frequency,
    List<int>? customDays,
    int? targetPerPeriod,
    TimeOfDay? reminderTime,
    bool? archived,
    int? sortOrder,
    DateTime? createdAt,
  }) =>
      Habit(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        frequency: frequency ?? this.frequency,
        customDays: customDays ?? this.customDays,
        targetPerPeriod: targetPerPeriod ?? this.targetPerPeriod,
        reminderTime: reminderTime ?? this.reminderTime,
        archived: archived ?? this.archived,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
      );

  static Color _colorFromHex(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }

  static String _hexFromColor(Color c) =>
      '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
}
