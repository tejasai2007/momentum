import 'package:flutter/material.dart';

class TodoList {
  final String id;
  final String userId;
  final String name;
  final Color color;
  final String icon;
  final int sortOrder;
  final DateTime createdAt;

  const TodoList({
    required this.id,
    required this.userId,
    required this.name,
    required this.color,
    required this.icon,
    required this.sortOrder,
    required this.createdAt,
  });

  factory TodoList.fromMap(Map<String, dynamic> map) {
    return TodoList(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      color: _colorFromHex(map['color'] as String? ?? '#6C5CE7'),
      icon: map['icon'] as String? ?? 'list',
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'name': name,
        'color': _hexFromColor(color),
        'icon': icon,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
      };

  TodoList copyWith({
    String? id,
    String? userId,
    String? name,
    Color? color,
    String? icon,
    int? sortOrder,
    DateTime? createdAt,
  }) =>
      TodoList(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        color: color ?? this.color,
        icon: icon ?? this.icon,
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

const Map<String, IconData> todoListIconMap = {
  'list': Icons.format_list_bulleted_rounded,
  'work': Icons.work_outline_rounded,
  'home': Icons.home_outlined,
  'cart': Icons.shopping_cart_outlined,
  'study': Icons.school_outlined,
  'fitness': Icons.fitness_center_rounded,
  'money': Icons.attach_money_rounded,
  'favorite': Icons.favorite_outline_rounded,
  'plane': Icons.flight_outlined,
  'flag': Icons.flag_outlined,
  'star': Icons.star_rounded,
  'code': Icons.code_rounded,
};
