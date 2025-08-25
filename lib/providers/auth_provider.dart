import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isOfflineMode = false;
  bool _isSyncing = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isOfflineMode => _isOfflineMode;
  bool get isSyncing => _isSyncing;

  AuthProvider() {
    _loadUser();
    _startConnectivityMonitoring();
  }

  void _startConnectivityMonitoring() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none && _user != null) {
        print('🌐 Connectivity restored, starting auto-sync...');
        _autoSync();
      }
    });
  }

  Future<void> _loadUser() async {
    _user = await DatabaseService.instance.getUser();
    notifyListeners();
  }

  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isConnected = connectivityResult != ConnectivityResult.none;
      
      if (isConnected) {
        final serverReachable = await ApiService.testConnection();
        return serverReachable;
      }
      return false;
    } catch (e) {
      print('Connectivity check error: $e');
      return false;
    }
  }

  Future<bool> register(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('AuthProvider: Début de l\'inscription pour $email');
      
      final isOnline = await _checkConnectivity();
      
      if (isOnline) {
        print('📶 Mode ONLINE - Inscription via API');
        final user = await ApiService.register(email, password);
        if (user != null) {
          print('✅ Inscription réussie via API');
          _user = user;
          _isOfflineMode = false;
          await DatabaseService.instance.saveUser(user, password: password);
          await _saveLoginState(true);
          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          print('⚠️ API failed, switching to offline registration');
          return await _registerOffline(email, password);
        }
      } else {
        print('📴 Mode OFFLINE - Inscription locale');
        return await _registerOffline(email, password);
      }
    } catch (e) {
      print('AuthProvider: Exception lors de l\'inscription: $e');
      print('🔄 Trying offline registration as fallback');
      return await _registerOffline(email, password);
    }
  }

  Future<bool> _registerOffline(String email, String password) async {
    try {
      final existingUsers = await DatabaseService.instance.getAllUsers();
      final emailExists = existingUsers.any((user) => user.email == email);
      
      if (emailExists) {
        _error = 'Cet email existe déjà localement';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final tempId = -(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      final user = User(
        id: tempId,
        email: email,
      );

      await DatabaseService.instance.saveUserWithPassword(user, password);
      
      _user = user;
      _isOfflineMode = true;
      await _saveLoginState(true);
      
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Offline registration error: $e');
      _error = 'Erreur d\'inscription hors ligne: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('AuthProvider: Début de la connexion pour $email');
      
      final isOnline = await _checkConnectivity();
      
      if (isOnline) {
        print('📶 Mode ONLINE - Connexion via API');
        final user = await ApiService.login(email, password);
        if (user != null) {
          print('✅ Connexion réussie via API');
          _user = user;
          _isOfflineMode = false;
          await DatabaseService.instance.saveUser(user, password: password);
          await _saveLoginState(true);
          _isLoading = false;
          notifyListeners();
          
          _autoSync();
          return true;
        } else {
          print('⚠️ API failed, trying offline login');
          return await _loginOffline(email, password);
        }
      } else {
        print('📴 Mode OFFLINE - Connexion locale');
        return await _loginOffline(email, password);
      }
    } catch (e) {
      print('AuthProvider: Exception lors de la connexion: $e');
      print('🔄 Trying offline login as fallback');
      return await _loginOffline(email, password);
    }
  }

  Future<bool> _loginOffline(String email, String password) async {
    try {
      final success = await DatabaseService.instance.verifyUserCredentials(email, password);
      
      if (success) {
        final user = await DatabaseService.instance.getUserByEmail(email);
        if (user != null) {
          _user = user;
          _isOfflineMode = user.id < 0;
          await _saveLoginState(true);
          
          _error = null;
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }
      
      _error = 'Email ou mot de passe invalide (mode hors ligne)';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      print('Offline login error: $e');
      _error = 'Erreur de connexion hors ligne: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _autoSync() async {
    if (_isSyncing) return;
    
    try {
      final isOnline = await _checkConnectivity();
      if (!isOnline) return;

      print('🔄 Starting auto-sync...');
      await syncOfflineData();
    } catch (e) {
      print('Auto-sync error: $e');
    }
  }

  Future<void> syncOfflineData() async {
    if (_isSyncing) return;
    
    _isSyncing = true;
    notifyListeners();

    try {
      final isOnline = await _checkConnectivity();
      if (!isOnline) {
        print('❌ Cannot sync: no internet connection');
        return;
      }

      print('🔄 Starting complete offline data sync...');

      // IMPORTANT : Synchroniser les utilisateurs AVANT les tâches
      await _syncOfflineUsers();

      // Recharger l'utilisateur après sync pour avoir le bon ID
      if (_user != null) {
        final updatedUser = await DatabaseService.instance.getUserByEmail(_user!.email);
        if (updatedUser != null) {
          _user = updatedUser;
          _isOfflineMode = false;
          notifyListeners();
        }
      }

      // Maintenant synchroniser les tâches avec le bon account_id
      if (_user != null) {
        await _syncOfflineTodos();
      }

      print('✅ Offline data sync completed');
      
    } catch (e) {
      print('❌ Sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _syncOfflineUsers() async {
    try {
      final offlineUsers = await DatabaseService.instance.getOfflineUsers();
      print('📤 Found ${offlineUsers.length} offline users to sync');
      
      for (final offlineUser in offlineUsers) {
        if (offlineUser.id < 0) {
          print('🔄 Syncing offline user: ${offlineUser.email}');
          
          final password = await DatabaseService.instance.getUserPassword(offlineUser.email);
          if (password != null) {
            final serverUser = await ApiService.register(offlineUser.email, password);
            if (serverUser != null) {
              print('✅ User synced to server: ${offlineUser.email} -> ID ${serverUser.id}');
              
              // IMPORTANT : updateUserAfterSync met à jour les tâches aussi
              await DatabaseService.instance.updateUserAfterSync(offlineUser.id, serverUser);
              
              if (_user?.id == offlineUser.id) {
                _user = serverUser;
                _isOfflineMode = false;
                print('🔄 Current user updated to server ID: ${serverUser.id}');
              }
            } else {
              print('⚠️ Failed to sync user to server: ${offlineUser.email}');
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error syncing offline users: $e');
    }
  }

  // CORRIGÉ : Synchronisation des tâches avec le bon account_id
  Future<void> _syncOfflineTodos() async {
    try {
      print('🔄 Starting todos sync for user ID: ${_user!.id}');
      
      final unsyncedTodos = await DatabaseService.instance.getUnsyncedTodos(_user!.id);
      print('📤 Found ${unsyncedTodos.length} unsynced todos');
      
      for (final todo in unsyncedTodos) {
        print('🔄 Syncing todo: ${todo.todo} (Account: ${todo.accountId})');
        
        // Créer une copie de la tâche avec le bon account_id pour l'API
        final todoForApi = todo.copyWith(accountId: _user!.id);
        
        final success = await ApiService.createTodo(todoForApi);
        if (success) {
          await DatabaseService.instance.markTodoAsSynced(todo.id!, todo.id!);
          print('✅ Todo synced: ${todo.todo}');
        } else {
          print('⚠️ Failed to sync todo: ${todo.todo}');
        }
      }
      
      print('✅ Todos sync completed');
    } catch (e) {
      print('❌ Error syncing offline todos: $e');
    }
  }

  Future<void> manualSync() async {
    await syncOfflineData();
  }

  Future<void> logout() async {
    final currentUserId = _user?.id;
    print('🚪 Logging out user $currentUserId');
    
    _user = null;
    _isOfflineMode = false;
    _isSyncing = false;
    await DatabaseService.instance.deleteUser();
    // CORRIGÉ : Ne PAS supprimer les tâches lors de la déconnexion
    // await DatabaseService.instance.clearTodos(); // SUPPRIMÉ
    await _saveLoginState(false);
    
    print('✅ User logged out, todos preserved locally');
    notifyListeners();
  }

  Future<void> _saveLoginState(bool isLoggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', isLoggedIn);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }

  void updateUser(User updatedUser) {
    _user = updatedUser;
    DatabaseService.instance.saveUser(updatedUser);
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
