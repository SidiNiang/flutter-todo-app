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
      
      // Load from local database first
      _todos = await DatabaseService.instance.getTodos(accountId);
      print('Loaded ${_todos.length} todos from local database');
      _applyFilter();

      // Try to sync with server if connected
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        print('Internet available, syncing with server...');
        await _syncWithServer(accountId);
      } else {
        print('No internet connection, using local data only');
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Error loading todos: $e';
      print('Error in loadTodos: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _syncWithServer(int accountId) async {
    try {
      // Get todos from server
      final serverTodos = await ApiService.getTodos(accountId);
      print('Received ${serverTodos.length} todos from server');
      
      // Clear local database and insert server data to avoid duplicates
      await DatabaseService.instance.clearTodos();
      
      // Insert server todos as synced
      for (var serverTodo in serverTodos) {
        await DatabaseService.instance.insertTodo(serverTodo.copyWith(synced: true));
      }

      // Sync unsynced local todos to server (this shouldn't happen after clearing, but just in case)
      final unsyncedTodos = await DatabaseService.instance.getUnsyncedTodos(accountId);
      print('Found ${unsyncedTodos.length} unsynced todos');
      
      for (var todo in unsyncedTodos) {
        final success = await ApiService.createTodo(todo);
        if (success) {
          await DatabaseService.instance.markTodoAsSynced(todo.id!, todo.id!);
        }
      }

      // Reload from local database
      _todos = await DatabaseService.instance.getTodos(accountId);
      print('After sync: ${_todos.length} todos in local database');
      _applyFilter();
    } catch (e) {
      print('Sync error: $e');
    }
  }

  Future<void> addTodo(Todo todo) async {
    try {
      print('Adding todo: ${todo.todo} for account: ${todo.accountId}');
      
      // Check internet connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      bool isOnline = connectivityResult != ConnectivityResult.none;
      
      if (isOnline) {
        // If online, create on server first
        print('Online mode: creating todo on server');
        final success = await ApiService.createTodo(todo);
        if (success) {
          print('Todo created successfully on server');
          // Reload todos from server to get the server ID
          await loadTodos(todo.accountId);
        } else {
          // If server creation fails, save locally as unsynced
          print('Server creation failed, saving locally');
          await DatabaseService.instance.insertTodo(todo.copyWith(synced: false));
          await loadTodos(todo.accountId);
        }
      } else {
        // If offline, save locally as unsynced
        print('Offline mode: saving locally');
        await DatabaseService.instance.insertTodo(todo.copyWith(synced: false));
        await loadTodos(todo.accountId);
      }
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
        final success = await ApiService.updateTodo(todo);
        if (success) {
          // Mark as synced if server update successful
          await DatabaseService.instance.updateTodo(todo.copyWith(synced: true));
        }
      }

      // Reload todos
      await loadTodos(todo.accountId);
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
        await ApiService.deleteTodo(todo.id!);
      }

      // Reload todos
      await loadTodos(todo.accountId);
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
}
