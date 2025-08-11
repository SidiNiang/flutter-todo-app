class Todo {
  final int? id;
  final int accountId;
  final DateTime date;
  final String todo;
  final bool done;
  final bool synced;

  Todo({
    this.id,
    required this.accountId,
    required this.date,
    required this.todo,
    this.done = false,
    this.synced = false,
  });

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['todo_id'] ?? json['id'],
      accountId: json['account_id'],
      date: DateTime.parse(json['date']),
      todo: json['todo'],
      done: json['done'] == 1 || json['done'] == true,
      synced: json['synced'] == 1 || json['synced'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'date': date.toIso8601String().split('T')[0],
      'todo': todo,
      'done': done,
      'synced': synced,
    };
  }

  Map<String, dynamic> toApiJson() {
    return {
      'id': accountId,
      'date': date.toIso8601String().split('T')[0],
      'todo': todo,
      'done': done,
    };
  }

  Todo copyWith({
    int? id,
    int? accountId,
    DateTime? date,
    String? todo,
    bool? done,
    bool? synced,
  }) {
    return Todo(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      date: date ?? this.date,
      todo: todo ?? this.todo,
      done: done ?? this.done,
      synced: synced ?? this.synced,
    );
  }
}
