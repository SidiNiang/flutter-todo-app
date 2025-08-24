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
      version: 6, // AUGMENTÉ encore pour forcer la mise à jour complète
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    print('🏗️ Creating database tables...');
    
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
    
    print('✅ Database tables created successfully');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    print('🔄 Upgrading database from version $oldVersion to $newVersion');
    
    if (oldVersion < 6) {
      // SOLUTION RADICALE : Recréer toutes les tables pour éviter les problèmes
      await _recreateAllTables(db);
    }
  }

  // NOUVEAU : Recréer toutes les tables proprement
  Future<void> _recreateAllTables(Database db) async {
    try {
      print('🔄 Recreating all tables...');
      
      // Sauvegarder les données existantes
      List<Map<String, dynamic>> existingUsers = [];
      List<Map<String, dynamic>> existingTodos = [];
      
      try {
        existingUsers = await db.query('users');
        print('📦 Backed up ${existingUsers.length} users');
      } catch (e) {
        print('No existing users to backup: $e');
      }
      
      try {
        existingTodos = await db.query('todos');
        print('📦 Backed up ${existingTodos.length} todos');
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
      
      print('✅ All tables recreated successfully');
      print('📊 Restored ${existingUsers.length} users and ${existingTodos.length} todos');
      
    } catch (e) {
      print('❌ Error recreating tables: $e');
    }
  }

  // CORRIGÉ : Sauvegarder utilisateur avec mot de passe (pour mode offline)
  Future<void> saveUserWithPassword(User user, String password) async {
    final db = await instance.database;
    final passwordHash = _hashPassword(password);
    
    print('💾 Saving user with password:');
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
    
    print('✅ User saved successfully');
    
    // Vérifier immédiatement que l'utilisateur est bien sauvé
    await debugDatabase();
  }

  // User operations
  Future<void> saveUser(User user) async {
    final db = await instance.database;
    await db.insert(
      'users',
      {
        'id': user.id,
        'email': user.email,
        'profile_image_path': user.profileImagePath,
        'is_synced': 1,
        'created_at': DateTime.now().toIso8601String(),
      },
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

  // NOUVEAU : Obtenir utilisateur par email
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

  // CORRIGÉ : Vérifier les identifiants offline avec debug
  Future<bool> verifyUserCredentials(String email, String password) async {
    final db = await instance.database;
    
    print('🔍 Verifying credentials:');
    print('  - Email: $email');
    print('  - Password: $password');
    
    // D'abord, afficher tous les utilisateurs pour debug
    final allUsers = await db.query('users');
    print('👥 All users in database (${allUsers.length}):');
    for (final user in allUsers) {
      print('  - ID: ${user['id']}, Email: ${user['email']}, Hash: ${user['password_hash']}');
    }
    
    // Chercher l'utilisateur spécifique
    final userMaps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    
    if (userMaps.isEmpty) {
      print('❌ User not found in database');
      return false;
    }
    
    final userData = userMaps.first;
    print('👤 User found:');
    print('  - ID: ${userData['id']}');
    print('  - Email: ${userData['email']}');
    print('  - Stored password hash: ${userData['password_hash']}');
    print('  - Stored password plain: ${userData['password_plain']}');
    
    // Vérifier avec le hash
    final passwordHash = _hashPassword(password);
    print('🔐 Generated hash for input: $passwordHash');
    
    final hashMatch = userData['password_hash'] == passwordHash;
    print('🔍 Hash match: $hashMatch');
    
    // Vérifier aussi avec le mot de passe en clair (pour debug)
    final plainMatch = userData['password_plain'] == password;
    print('🔍 Plain match: $plainMatch');
    
    return hashMatch || plainMatch;
  }

  // NOUVEAU : Obtenir tous les utilisateurs avec debug
  Future<List<User>> getAllUsers() async {
    final db = await instance.database;
    final maps = await db.query('users');
    
    print('📋 All users in database:');
    for (final map in maps) {
      print('  - ID: ${map['id']}, Email: ${map['email']}, Synced: ${map['is_synced']}');
    }
    
    return List.generate(maps.length, (i) {
      return User.fromJson(maps[i]);
    });
  }

  // NOUVEAU : Obtenir les utilisateurs non synchronisés
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

  // CORRIGÉ : Obtenir le mot de passe d'un utilisateur
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

  // NOUVEAU : Mettre à jour un utilisateur après synchronisation
  Future<void> updateUserAfterSync(int oldId, User newUser) async {
    final db = await instance.database;
    
    // Mettre à jour l'utilisateur
    await db.update(
      'users',
      {
        'id': newUser.id,
        'email': newUser.email,
        'is_synced': 1,
      },
      where: 'id = ?',
      whereArgs: [oldId],
    );
    
    // Mettre à jour les todos associés
    await db.update(
      'todos',
      {'account_id': newUser.id},
      where: 'account_id = ?',
      whereArgs: [oldId],
    );
  }

  // MODIFIÉ : Ne pas supprimer l'utilisateur actuel lors du logout
  Future<void> deleteUser() async {
    final db = await instance.database;
    // Ne supprimer que les données de session, pas l'utilisateur
    print('🗑️ Clearing user session (keeping user data)');
    // await db.delete('users'); // COMMENTÉ pour garder les utilisateurs
  }

  // NOUVEAU : Supprimer vraiment tous les utilisateurs (pour reset complet)
  Future<void> deleteAllUsers() async {
    final db = await instance.database;
    await db.delete('users');
    print('🗑️ All users deleted');
  }

  // Fonction helper pour hasher les mots de passe
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // NOUVEAU : Méthode de debug pour voir le contenu de la base
  Future<void> debugDatabase() async {
    final db = await instance.database;
    
    print('🔍 === DATABASE DEBUG ===');
    
    // Afficher la structure de la table users
    final usersTableInfo = await db.rawQuery('PRAGMA table_info(users)');
    print('📋 Users table structure:');
    for (final column in usersTableInfo) {
      print('  - ${column['name']}: ${column['type']}');
    }
    
    // Afficher la structure de la table todos
    final todosTableInfo = await db.rawQuery('PRAGMA table_info(todos)');
    print('📋 Todos table structure:');
    for (final column in todosTableInfo) {
      print('  - ${column['name']}: ${column['type']}');
    }
    
    // Afficher tous les utilisateurs
    final users = await db.query('users');
    print('👥 Users in database (${users.length}):');
    for (final user in users) {
      print('  - ID: ${user['id']}, Email: ${user['email']}, Hash: ${user['password_hash']}, Plain: ${user['password_plain']}');
    }
    
    // Afficher tous les todos
    final todos = await db.query('todos');
    print('📝 Todos in database (${todos.length}):');
    for (final todo in todos) {
      print('  - ID: ${todo['id']}, Account: ${todo['account_id']}, Todo: ${todo['todo']}');
    }
    
    print('🔍 === END DEBUG ===');
  }

  // Todo operations - CORRIGÉ pour éviter l'erreur created_at
  Future<int> insertTodo(Todo todo) async {
    final db = await instance.database;
    
    try {
      if (todo.id != null && todo.id! > 0) {
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

  // CORRIGÉ : getTodos sans created_at si la colonne n'existe pas
  Future<List<Todo>> getTodos(int accountId) async {
    final db = await instance.database;
    
    try {
      final maps = await db.query(
        'todos',
        where: 'account_id = ?',
        whereArgs: [accountId],
        orderBy: 'date DESC, id DESC', // Utiliser id au lieu de created_at comme fallback
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
    } catch (e) {
      print('Error getting todos: $e');
      // Si erreur avec created_at, essayer sans
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
    } catch (e) {
      print('Error marking todo as synced: $e');
    }
  }

  Future<void> clearTodos() async {
    final db = await instance.database;
    try {
      await db.delete('todos');
      print('Cleared all todos from local database');
    } catch (e) {
      print('Error clearing todos: $e');
    }
  }

  Future<void> resetDatabase() async {
    final db = await instance.database;
    try {
      await db.delete('users');
      await db.delete('todos');
      print('🗑️ Database reset completed');
    } catch (e) {
      print('❌ Error resetting database: $e');
    }
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
