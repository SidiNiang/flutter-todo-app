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
      // Load from local database first
      _todos = await DatabaseService.instance.getTodos(accountId);
      _applyFilter();

      // Try to sync with server if connected
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        await _syncWithServer(accountId);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Error loading todos: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _syncWithServer(int accountId) async {
    try {
      // Get todos from server
      final serverTodos = await ApiService.getTodos(accountId);
      
      // Update local database with server data
      for (var serverTodo in serverTodos) {
        await DatabaseService.instance.insertTodo(serverTodo.copyWith(synced: true));
      }

      // Sync unsynced local todos to server
      final unsyncedTodos = await DatabaseService.instance.getUnsyncedTodos(accountId);
      for (var todo in unsyncedTodos) {
        final success = await ApiService.createTodo(todo);
        if (success) {
          await DatabaseService.instance.markTodoAsSynced(todo.id!, todo.id!);
        }
      }

      // Reload from local database
      _todos = await DatabaseService.instance.getTodos(accountId);
      _applyFilter();
    } catch (e) {
      print('Sync error: $e');
    }
  }

  Future<void> addTodo(Todo todo) async {
    try {
      // Add to local database first
      final localId = await DatabaseService.instance.insertTodo(todo);
      
      // Try to sync with server
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        final success = await ApiService.createTodo(todo);
        if (success) {
          await DatabaseService.instance.markTodoAsSynced(localId, localId);
        }
      }

      // Reload todos
      await loadTodos(todo.accountId);
    } catch (e) {
      _error = 'Error adding todo: $e';
      notifyListeners();
    }
  }

  Future<void> updateTodo(Todo todo) async {
    try {
      // Update local database
      await DatabaseService.instance.updateTodo(todo);
      
      // Try to sync with server
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        await ApiService.updateTodo(todo);
      }

      // Reload todos
      await loadTodos(todo.accountId);
    } catch (e) {
      _error = 'Error updating todo: $e';
      notifyListeners();
    }
  }

  Future<void> deleteTodo(Todo todo) async {
    try {
      // Delete from local database
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
