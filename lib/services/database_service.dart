import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
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
      version: 6,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    print('Creating database tables...');
    
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        email TEXT NOT NULL UNIQUE,
        profile_image_path TEXT,
        password_hash TEXT,
        password_plain TEXT,
        is_synced INTEGER DEFAULT 1,
        created_at TEXT DEFAULT (datetime('now'))
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
        server_id INTEGER,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    // Create unique index to prevent duplicates
    await db.execute('''
      CREATE UNIQUE INDEX idx_todos_server_account 
      ON todos(server_id, account_id) 
      WHERE server_id IS NOT NULL
    ''');
    
    print('Database tables created successfully');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    print('Upgrading database from version $oldVersion to $newVersion');
    
    if (oldVersion < 6) {
      await _recreateAllTables(db);
    }
  }

  Future<void> _recreateAllTables(Database db) async {
    try {
      print('Recreating all tables...');
      
      // Sauvegarder les données existantes
      List<Map<String, dynamic>> existingUsers = [];
      List<Map<String, dynamic>> existingTodos = [];
      
      try {
        existingUsers = await db.query('users');
        print('Backed up ${existingUsers.length} users');
      } catch (e) {
        print('No existing users to backup: $e');
      }
      
      try {
        existingTodos = await db.query('todos');
        print('Backed up ${existingTodos.length} todos');
      } catch (e) {
        print('No existing todos to backup: $e');
      }
      
      // Supprimer les anciennes tables
      await db.execute('DROP TABLE IF EXISTS users');
      await db.execute('DROP TABLE IF EXISTS todos');
      await db.execute('DROP INDEX IF EXISTS idx_todos_server_account');
      
      // Recréer les tables
      await _createDB(db, 6);
      
      // Restaurer les données users
      for (final user in existingUsers) {
        try {
          await db.insert('users', {
            'id': user['id'],
            'email': user['email'],
            'profile_image_path': user['profile_image_path'],
            'password_hash': user['password_hash'],
            'password_plain': user['password_plain'],
            'is_synced': user['is_synced'] ?? 1,
            'created_at': user['created_at'] ?? DateTime.now().toIso8601String(),
          });
        } catch (e) {
          print('Error restoring user ${user['email']}: $e');
        }
      }
      
      // Restaurer les données todos
      for (final todo in existingTodos) {
        try {
          await db.insert('todos', {
            'id': todo['id'],
            'account_id': todo['account_id'],
            'date': todo['date'],
            'todo': todo['todo'],
            'done': todo['done'],
            'synced': todo['synced'],
            'server_id': todo['server_id'],
            'created_at': todo['created_at'] ?? DateTime.now().toIso8601String(),
          });
        } catch (e) {
          print('Error restoring todo: $e');
        }
      }
      
      print('All tables recreated successfully');
      print('Restored ${existingUsers.length} users and ${existingTodos.length} todos');
      
    } catch (e) {
      print('Error recreating tables: $e');
    }
  }

  Future<void> saveUserWithPassword(User user, String password) async {
    final db = await instance.database;
    final passwordHash = _hashPassword(password);
    
    print('Saving user with password:');
    print('  - Email: ${user.email}');
    print('  - ID: ${user.id}');
    print('  - Password: $password');
    print('  - Password Hash: $passwordHash');
    
    await db.insert(
      'users',
      {
        'id': user.id,
        'email': user.email,
        'profile_image_path': user.profileImagePath,
        'password_hash': passwordHash,
        'password_plain': password,
        'is_synced': user.id > 0 ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    print('User saved successfully');
    await debugDatabase();
  }

  Future<void> saveUser(User user, {String? password}) async {
    final db = await instance.database;
    
    String? passwordHash;
    String? passwordPlain;
    
    if (password != null) {
      passwordHash = _hashPassword(password);
      passwordPlain = password;
      print('Saving user with new password: ${user.email}');
    } else {
      final existingUser = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: [user.email],
        limit: 1,
      );
      
      if (existingUser.isNotEmpty) {
        passwordHash = existingUser.first['password_hash'] as String?;
        passwordPlain = existingUser.first['password_plain'] as String?;
        print('Preserving existing password for user: ${user.email}');
      } else {
        print('No existing password found for user: ${user.email}');
      }
    }
    
    await db.insert(
      'users',
      {
        'id': user.id,
        'email': user.email,
        'profile_image_path': user.profileImagePath,
        'password_hash': passwordHash,
        'password_plain': passwordPlain,
        'is_synced': 1,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    print('User saved: ${user.email} (ID: ${user.id})');
  }

  // ANCIEN : Méthode dépréciée - ne plus utiliser
  Future<User?> getUser() async {
    try {
      final db = await instance.database;
      print('WARNING: getUser() is deprecated, use getUserById() instead');
      
      final maps = await db.query('users', limit: 1);
      print('Found ${maps.length} users in database');
      
      if (maps.isNotEmpty) {
        final userData = maps.first;
        print('User data: ID=${userData['id']}, Email=${userData['email']}');
        
        final user = User.fromJson(userData);
        print('User object created successfully');
        return user;
      } else {
        print('No users found in database');
        return null;
      }
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  // NOUVEAU : Récupérer un utilisateur par son ID
  Future<User?> getUserById(int userId) async {
    try {
      final db = await instance.database;
      print('Looking for user with ID: $userId');
      
      final maps = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      
      if (maps.isNotEmpty) {
        final userData = maps.first;
        print('User found: ID=${userData['id']}, Email=${userData['email']}');
        return User.fromJson(userData);
      } else {
        print('User with ID $userId not found');
        return null;
      }
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await instance.database;
    final maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    
    if (maps.isNotEmpty) {
      return User.fromJson(maps.first);
    }
    return null;
  }

  Future<bool> verifyUserCredentials(String email, String password) async {
    final db = await instance.database;
    
    print('Verifying credentials:');
    print('  - Email: $email');
    print('  - Password: $password');
    
    final allUsers = await db.query('users');
    print('All users in database (${allUsers.length}):');
    for (final user in allUsers) {
      print('  - ID: ${user['id']}, Email: ${user['email']}, Hash: ${user['password_hash']}, Plain: ${user['password_plain']}');
    }
    
    final userMaps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    
    if (userMaps.isEmpty) {
      print('User not found in database');
      return false;
    }
    
    final userData = userMaps.first;
    print('User found:');
    print('  - ID: ${userData['id']}');
    print('  - Email: ${userData['email']}');
    print('  - Stored password hash: ${userData['password_hash']}');
    print('  - Stored password plain: ${userData['password_plain']}');
    
    final passwordHash = _hashPassword(password);
    print('Generated hash for input: $passwordHash');
    
    final hashMatch = userData['password_hash'] == passwordHash;
    print('Hash match: $hashMatch');
    
    final plainMatch = userData['password_plain'] == password;
    print('Plain match: $plainMatch');
    
    return hashMatch || plainMatch;
  }

  Future<List<User>> getAllUsers() async {
    final db = await instance.database;
    final maps = await db.query('users');
    
    print('All users in database:');
    for (final map in maps) {
      print('  - ID: ${map['id']}, Email: ${map['email']}, Synced: ${map['is_synced']}');
    }
    
    return List.generate(maps.length, (i) {
      return User.fromJson(maps[i]);
    });
  }

  Future<List<User>> getOfflineUsers() async {
    final db = await instance.database;
    final maps = await db.query(
      'users',
      where: 'is_synced = 0',
    );
    
    return List.generate(maps.length, (i) {
      return User.fromJson(maps[i]);
    });
  }

  Future<String?> getUserPassword(String email) async {
    final db = await instance.database;
    final maps = await db.query(
      'users',
      columns: ['password_plain'],
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    
    if (maps.isNotEmpty) {
      return maps.first['password_plain'] as String?;
    }
    return null;
  }

  // CORRIGÉ : Mettre à jour un utilisateur après synchronisation ET ses tâches
  Future<void> updateUserAfterSync(int oldId, User newUser) async {
    final db = await instance.database;
    
    print('Updating user after sync:');
    print('  - Old ID: $oldId');
    print('  - New ID: ${newUser.id}');
    print('  - Email: ${newUser.email}');
    
    // Récupérer le mot de passe ET le profile_image_path de l'ancien utilisateur
    final oldUserData = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [oldId],
      limit: 1,
    );
    
    String? passwordHash;
    String? passwordPlain;
    String? profileImagePath;
    
    if (oldUserData.isNotEmpty) {
      passwordHash = oldUserData.first['password_hash'] as String?;
      passwordPlain = oldUserData.first['password_plain'] as String?;
      profileImagePath = oldUserData.first['profile_image_path'] as String?;
      print('Preserving password and profile image from old user');
      if (profileImagePath != null) {
        print('Profile image path to preserve: $profileImagePath');
      }
    }
    
    // IMPORTANT : Mettre à jour TOUTES les tâches de l'ancien utilisateur AVANT de le supprimer
    print('Updating todos account_id from $oldId to ${newUser.id}');
    final todosUpdated = await db.update(
      'todos',
      {'account_id': newUser.id},
      where: 'account_id = ?',
      whereArgs: [oldId],
    );
    print('Updated $todosUpdated todos with new account_id');
    
    // Supprimer l'ancien utilisateur
    await db.delete('users', where: 'id = ?', whereArgs: [oldId]);
    
    // Insérer le nouvel utilisateur avec le mot de passe ET profile_image_path préservés
    await db.insert('users', {
      'id': newUser.id,
      'email': newUser.email,
      'profile_image_path': profileImagePath ?? newUser.profileImagePath, // CORRIGÉ : Préserver l'ancienne photo
      'password_hash': passwordHash,
      'password_plain': passwordPlain,
      'is_synced': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
    
    print('User updated after sync with preserved password, profile image, and updated todos');
    await debugDatabase();
  }

  Future<void> deleteUser() async {
    final db = await instance.database;
    print('Clearing user session (keeping user data and todos)');
    // Ne rien supprimer - juste nettoyer la session
  }

  Future<void> deleteAllUsers() async {
    final db = await instance.database;
    await db.delete('users');
    print('All users deleted');
  }

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> debugDatabase() async {
    final db = await instance.database;
    
    print('=== DATABASE DEBUG ===');
    
    final usersTableInfo = await db.rawQuery('PRAGMA table_info(users)');
    print('Users table structure:');
    for (final column in usersTableInfo) {
      print('  - ${column['name']}: ${column['type']}');
    }
    
    final todosTableInfo = await db.rawQuery('PRAGMA table_info(todos)');
    print('Todos table structure:');
    for (final column in todosTableInfo) {
      print('  - ${column['name']}: ${column['type']}');
    }
    
    final users = await db.query('users');
    print('Users in database (${users.length}):');
    for (final user in users) {
      print('  - ID: ${user['id']}, Email: ${user['email']}, Hash: ${user['password_hash']}, Plain: ${user['password_plain']}');
    }
    
    final todos = await db.query('todos');
    print('Todos in database (${todos.length}):');
    for (final todo in todos) {
      print('  - ID: ${todo['id']}, Account: ${todo['account_id']}, Todo: ${todo['todo']}, Synced: ${todo['synced']}');
    }
    
    print('=== END DEBUG ===');
  }

  // Todo operations
  Future<int> insertTodo(Todo todo) async {
    final db = await instance.database;
    
    try {
      if (todo.id != null && todo.id! > 0) {
        // Tâche avec ID serveur - utiliser INSERT OR REPLACE avec server_id
        print('Inserting/updating server todo: ${todo.todo} (ID: ${todo.id})');
        
        await db.execute('''
          INSERT OR REPLACE INTO todos 
          (server_id, account_id, date, todo, done, synced, created_at) 
          VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', [
          todo.id,
          todo.accountId,
          todo.date.toIso8601String().split('T')[0],
          todo.todo,
          todo.done ? 1 : 0,
          todo.synced ? 1 : 0,
          DateTime.now().toIso8601String(),
        ]);
        return todo.id!;
      } else {
        // Tâche locale - insérer normalement
        print('Inserting local todo: ${todo.todo}');
        final maps = await db.query(
          'todos',
          where: 'account_id = ? AND date = ? AND todo = ?',
          whereArgs: [todo.accountId, todo.date.toIso8601String().split('T')[0], todo.todo],
        );
        
        if (maps.isNotEmpty) {
          print('Duplicate todo found, skipping insertion');
          return maps.first['id'] as int;
        }
        
        return await db.insert('todos', {
          'account_id': todo.accountId,
          'date': todo.date.toIso8601String().split('T')[0],
          'todo': todo.todo,
          'done': todo.done ? 1 : 0,
          'synced': todo.synced ? 1 : 0,
          'server_id': null,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('Error inserting todo: $e');
      return -1;
    }
  }

  Future<List<Todo>> getTodos(int accountId) async {
    final db = await instance.database;
    
    try {
      final maps = await db.query(
        'todos',
        where: 'account_id = ?',
        whereArgs: [accountId],
        orderBy: 'date DESC, id DESC',
      );

      print('Found ${maps.length} todos for account $accountId');
      for (final map in maps) {
        print('  - Todo: ${map['todo']}, Account: ${map['account_id']}, Synced: ${map['synced']}');
      }

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
    } catch (e) {
      print('Error getting todos: $e');
      try {
        final maps = await db.query(
          'todos',
          where: 'account_id = ?',
          whereArgs: [accountId],
          orderBy: 'date DESC, id DESC',
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
      } catch (e2) {
        print('Error getting todos (fallback): $e2');
        return [];
      }
    }
  }

  Future<void> updateTodo(Todo todo) async {
    final db = await instance.database;
    
    try {
      if (todo.id != null) {
        await db.update(
          'todos',
          {
            'todo': todo.todo,
            'date': todo.date.toIso8601String().split('T')[0],
            'done': todo.done ? 1 : 0,
            'synced': todo.synced ? 1 : 0,
          },
          where: 'server_id = ? OR (server_id IS NULL AND id = ?)',
          whereArgs: [todo.id, todo.id],
        );
      }
    } catch (e) {
      print('Error updating todo: $e');
    }
  }

  Future<void> deleteTodo(int todoId) async {
    final db = await instance.database;
    try {
      await db.delete(
        'todos',
        where: 'server_id = ? OR (server_id IS NULL AND id = ?)',
        whereArgs: [todoId, todoId],
      );
    } catch (e) {
      print('Error deleting todo: $e');
    }
  }

  // CORRIGÉ : Obtenir les tâches non synchronisées avec le bon account_id
  Future<List<Todo>> getUnsyncedTodos(int accountId) async {
    final db = await instance.database;
    
    print('Looking for unsynced todos for account: $accountId');
    
    final maps = await db.query(
      'todos',
      where: 'account_id = ? AND synced = 0',
      whereArgs: [accountId],
    );

    print('Found ${maps.length} unsynced todos for account $accountId');
    for (final map in maps) {
      print('  - Todo: ${map['todo']}, Account: ${map['account_id']}, Local ID: ${map['id']}');
    }

    return List.generate(maps.length, (i) {
      return Todo(
        id: maps[i]['id'] as int, // Utiliser l'ID local pour les tâches non synchronisées
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
    try {
      await db.update(
        'todos',
        {
          'synced': 1,
          'server_id': serverId,
        },
        where: 'id = ?',
        whereArgs: [localId],
      );
      print('Marked todo $localId as synced with server ID $serverId');
    } catch (e) {
      print('Error marking todo as synced: $e');
    }
  }

  // NOUVEAU : Méthode pour nettoyer seulement lors d'un reset complet
  Future<void> clearUserSession() async {
    print('Clearing user session (keeping user data and todos)');
    // Cette méthode ne supprime rien de la base de données
    // Elle sert juste à marquer la fin de session dans les logs
    // Les données utilisateur et todos restent intactes
  }

  // MODIFIÉ : clearTodos ne doit être utilisé que pour un reset complet
  Future<void> clearTodos() async {
    final db = await instance.database;
    try {
      await db.delete('todos');
      print('All todos cleared (complete reset)');
    } catch (e) {
      print('Error clearing todos: $e');
    }
  }

  Future<void> resetDatabase() async {
    final db = await instance.database;
    try {
      await db.delete('users');
      await db.delete('todos');
      print('Database reset completed');
    } catch (e) {
      print('Error resetting database: $e');
    }
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
