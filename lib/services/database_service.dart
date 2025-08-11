import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/todo.dart';
import '../models/user.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('todo_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        email TEXT NOT NULL,
        profile_image_path TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE todos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        todo TEXT NOT NULL,
        done INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0,
        server_id INTEGER
      )
    ''');
  }

  // User operations
  Future<void> saveUser(User user) async {
    final db = await instance.database;
    await db.insert(
      'users',
      user.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<User?> getUser() async {
    final db = await instance.database;
    final maps = await db.query('users', limit: 1);
    
    if (maps.isNotEmpty) {
      return User.fromJson(maps.first);
    }
    return null;
  }

  Future<void> deleteUser() async {
    final db = await instance.database;
    await db.delete('users');
  }

  // Todo operations
  Future<int> insertTodo(Todo todo) async {
    final db = await instance.database;
    return await db.insert('todos', {
      'account_id': todo.accountId,
      'date': todo.date.toIso8601String().split('T')[0],
      'todo': todo.todo,
      'done': todo.done ? 1 : 0,
      'synced': todo.synced ? 1 : 0,
      'server_id': todo.id,
    });
  }

  Future<List<Todo>> getTodos(int accountId) async {
    final db = await instance.database;
    final maps = await db.query(
      'todos',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'date DESC',
    );

    return List.generate(maps.length, (i) {
      return Todo(
        id: maps[i]['server_id'] as int? ?? maps[i]['id'] as int,
        accountId: maps[i]['account_id'] as int,
        date: DateTime.parse(maps[i]['date'] as String),
        todo: maps[i]['todo'] as String,
        done: maps[i]['done'] == 1,
        synced: maps[i]['synced'] == 1,
      );
    });
  }

  Future<void> updateTodo(Todo todo) async {
    final db = await instance.database;
    await db.update(
      'todos',
      {
        'todo': todo.todo,
        'done': todo.done ? 1 : 0,
        'synced': todo.synced ? 1 : 0,
      },
      where: 'id = ? OR server_id = ?',
      whereArgs: [todo.id, todo.id],
    );
  }

  Future<void> deleteTodo(int todoId) async {
    final db = await instance.database;
    await db.delete(
      'todos',
      where: 'id = ? OR server_id = ?',
      whereArgs: [todoId, todoId],
    );
  }

  Future<List<Todo>> getUnsyncedTodos(int accountId) async {
    final db = await instance.database;
    final maps = await db.query(
      'todos',
      where: 'account_id = ? AND synced = 0',
      whereArgs: [accountId],
    );

    return List.generate(maps.length, (i) {
      return Todo(
        id: maps[i]['id'] as int,
        accountId: maps[i]['account_id'] as int,
        date: DateTime.parse(maps[i]['date'] as String),
        todo: maps[i]['todo'] as String,
        done: maps[i]['done'] == 1,
        synced: false,
      );
    });
  }

  Future<void> markTodoAsSynced(int localId, int serverId) async {
    final db = await instance.database;
    await db.update(
      'todos',
      {
        'synced': 1,
        'server_id': serverId,
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> clearTodos() async {
    final db = await instance.database;
    await db.delete('todos');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
