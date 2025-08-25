import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/todo.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';

class TodoProvider with ChangeNotifier {
  List<Todo> _todos = [];
  List<Todo> _filteredTodos = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  List<Todo> get todos => _filteredTodos;
  List<Todo> get completedTodos => _filteredTodos.where((todo) => todo.done).toList();
  List<Todo> get pendingTodos => _filteredTodos.where((todo) => !todo.done).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  Future<void> loadTodos(int accountId) async {
    _isLoading = true;
    notifyListeners();

    try {
      print('Loading todos for account: $accountId');
      
      // Check internet connectivity first
      final connectivityResult = await Connectivity().checkConnectivity();
      bool isOnline = connectivityResult != ConnectivityResult.none;
      
      if (isOnline) {
        // Test server connectivity
        final serverReachable = await ApiService.testConnection();
        if (serverReachable) {
          print('Online: Loading from server first');
          // If online, get fresh data from server
          final serverTodos = await ApiService.getTodos(accountId);
          print('Received ${serverTodos.length} todos from server');
          
          // CORRIGÉ : Synchronisation intelligente sans doublons
          for (var serverTodo in serverTodos) {
            await _mergeTodoFromServer(serverTodo);
          }
        } else {
          print('Server not reachable, using local data');
        }
      } else {
        print('Offline: Loading from local database only');
      }
      
      // Load from local database
      _todos = await DatabaseService.instance.getTodos(accountId);
      print('Loaded ${_todos.length} todos from local database');
      
      _applyFilter();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Error loading todos: $e';
      print('Error in loadTodos: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTodo(Todo todo) async {
    try {
      print('Adding todo: ${todo.todo} for account: ${todo.accountId}');
      
      // Check internet connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      bool isOnline = connectivityResult != ConnectivityResult.none;
      
      if (isOnline) {
        // Test server connectivity
        final serverReachable = await ApiService.testConnection();
        if (serverReachable) {
          print('Online mode: creating todo on server');
          final success = await ApiService.createTodo(todo);
          if (success) {
            print('Todo created successfully on server');
            // Reload todos from server to get the updated list
            await loadTodos(todo.accountId);
            return;
          } else {
            print('Server creation failed, saving locally');
          }
        } else {
          print('Server not reachable, saving locally');
        }
      } else {
        print('Offline mode: saving locally');
      }
      
      // Save locally as unsynced (fallback or offline mode)
      print('💾 Saving todo locally as unsynced');
      final localTodo = todo.copyWith(synced: false);
      await DatabaseService.instance.insertTodo(localTodo);
      
      // Reload local todos
      _todos = await DatabaseService.instance.getTodos(todo.accountId);
      _applyFilter();
      notifyListeners();
      
      print('✅ Todo saved locally: ${todo.todo}');
      
    } catch (e) {
      _error = 'Error adding todo: $e';
      print('Error in addTodo: $e');
      notifyListeners();
    }
  }

  Future<void> updateTodo(Todo todo) async {
    try {
      print('Updating todo: ${todo.id}');
      
      // Update local database first
      await DatabaseService.instance.updateTodo(todo.copyWith(synced: false));
      
      // Try to sync with server
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        final serverReachable = await ApiService.testConnection();
        if (serverReachable) {
          final success = await ApiService.updateTodo(todo);
          if (success) {
            // Mark as synced if server update successful
            await DatabaseService.instance.updateTodo(todo.copyWith(synced: true));
          }
        }
      }

      // Reload todos
      _todos = await DatabaseService.instance.getTodos(todo.accountId);
      _applyFilter();
      notifyListeners();
    } catch (e) {
      _error = 'Error updating todo: $e';
      print('Error in updateTodo: $e');
      notifyListeners();
    }
  }

  Future<void> deleteTodo(Todo todo) async {
    try {
      print('Deleting todo: ${todo.id}');
      
      // Delete from local database first
      await DatabaseService.instance.deleteTodo(todo.id!);
      
      // Try to sync with server
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        final serverReachable = await ApiService.testConnection();
        if (serverReachable) {
          await ApiService.deleteTodo(todo.id!);
        }
      }

      // Reload todos
      _todos = await DatabaseService.instance.getTodos(todo.accountId);
      _applyFilter();
      notifyListeners();
    } catch (e) {
      _error = 'Error deleting todo: $e';
      print('Error in deleteTodo: $e');
      notifyListeners();
    }
  }

  Future<void> toggleTodoStatus(Todo todo) async {
    final updatedTodo = todo.copyWith(done: !todo.done);
    await updateTodo(updatedTodo);
  }

  void searchTodos(String query) {
    _searchQuery = query;
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredTodos = List.from(_todos);
    } else {
      _filteredTodos = _todos
          .where((todo) => todo.todo.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // NOUVEAU : Méthode pour merger les tâches du serveur sans doublons
  Future<void> _mergeTodoFromServer(Todo serverTodo) async {
    final db = await DatabaseService.instance.database;
    
    // Vérifier si cette tâche existe déjà localement
    final existingTodos = await db.query(
      'todos',
      where: 'server_id = ? OR (account_id = ? AND todo = ? AND date = ?)',
      whereArgs: [
        serverTodo.id,
        serverTodo.accountId,
        serverTodo.todo,
        serverTodo.date.toIso8601String().split('T')[0],
      ],
    );
    
    if (existingTodos.isEmpty) {
      // Nouvelle tâche du serveur, l'insérer
      print('📥 Inserting new server todo: ${serverTodo.todo}');
      await DatabaseService.instance.insertTodo(serverTodo.copyWith(synced: true));
    } else {
      // Tâche existante, mettre à jour si nécessaire
      final existingTodo = existingTodos.first;
      if (existingTodo['synced'] == 0) {
        // Marquer comme synchronisée
        print('✅ Marking existing todo as synced: ${serverTodo.todo}');
        await db.update(
          'todos',
          {
            'synced': 1,
            'server_id': serverTodo.id,
          },
          where: 'id = ?',
          whereArgs: [existingTodo['id']],
        );
      } else {
        print('📋 Todo already synced: ${serverTodo.todo}');
      }
    }
  }
}
