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
    try {
      print('👤 Loading user from database...');
      
      final prefs = await SharedPreferences.getInstance();
      final loggedInUserId = prefs.getInt('logged_in_user_id');
      
      if (loggedInUserId != null) {
        print('🔍 Looking for user with ID: $loggedInUserId');
        _user = await DatabaseService.instance.getUserById(loggedInUserId);
        
        if (_user != null) {
          print('✅ User loaded: ${_user!.email} (ID: ${_user!.id})');
          _isOfflineMode = _user!.id < 0;
        } else {
          print('⚠️ User with ID $loggedInUserId not found in database');
          await prefs.remove('logged_in_user_id');
          await prefs.setBool('is_logged_in', false);
          _isOfflineMode = false;
        }
      } else {
        print('⚠️ No logged in user ID found in SharedPreferences');
        _user = null;
        _isOfflineMode = false;
      }
      
      notifyListeners();
    } catch (e) {
      print('❌ Error loading user: $e');
      _user = null;
      _isOfflineMode = false;
      notifyListeners();
    }
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
          await _saveLoginState(true, user.id);
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
      await _saveLoginState(true, user.id);
      
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
          await _saveLoginState(true, user.id);
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
          await _saveLoginState(true, user.id);
          
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

  // MODIFIÉ : Synchronisation simplifiée sans flag de migration
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

      // Sauvegarder l'ancien ID utilisateur pour référence
      final oldUserId = _user?.id;
      print('📋 Current user ID before sync: $oldUserId');

      // Synchroniser les utilisateurs
      await _syncOfflineUsers();

      // Recharger l'utilisateur après sync
      if (_user != null) {
        final updatedUser = await DatabaseService.instance.getUserByEmail(_user!.email);
        if (updatedUser != null && updatedUser.id != oldUserId) {
          print('🔄 User ID changed from $oldUserId to ${updatedUser.id}');
          _user = updatedUser;
          _isOfflineMode = false;
          await _saveLoginState(true, _user!.id);
          
          // IMPORTANT : Ne pas appeler notifyListeners() ici pour éviter les rebuilds multiples
          // Le ProfileProvider détectera automatiquement le changement d'ID
        }
      }

      // Synchroniser les tâches
      if (_user != null) {
        await _syncOfflineTodos();
      }

      print('✅ Offline data sync completed');
      
    } catch (e) {
      print('❌ Sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners(); // Un seul notifyListeners() à la fin
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
              
              await DatabaseService.instance.updateUserAfterSync(offlineUser.id, serverUser);
              
              // Mettre à jour l'utilisateur actuel si c'est lui qui a été synchronisé
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

  Future<void> _syncOfflineTodos() async {
    try {
      print('🔄 Starting todos sync for user ID: ${_user!.id}');
      
      final unsyncedTodos = await DatabaseService.instance.getUnsyncedTodos(_user!.id);
      print('📤 Found ${unsyncedTodos.length} unsynced todos');
      
      for (final todo in unsyncedTodos) {
        print('🔄 Syncing todo: ${todo.todo} (Account: ${todo.accountId})');
        
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
    _error = null;
  
    await DatabaseService.instance.clearUserSession();
    await _saveLoginState(false, null);
  
    print('✅ User logged out, session cleared');
    notifyListeners();
  }

  Future<void> _saveLoginState(bool isLoggedIn, int? userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', isLoggedIn);
    
    if (isLoggedIn && userId != null) {
      await prefs.setInt('logged_in_user_id', userId);
      print('💾 Saved login state: logged_in=true, user_id=$userId');
    } else {
      await prefs.remove('logged_in_user_id');
      print('💾 Saved login state: logged_in=false, user_id=null');
    }
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

  Future<bool> initializeAuth() async {
    try {
      print('🔐 Initializing authentication...');
      
      final wasLoggedIn = await isLoggedIn();
      print('📋 Was logged in: $wasLoggedIn');
      
      if (wasLoggedIn) {
        await _loadUser();
        
        if (_user != null) {
          print('✅ User loaded from database: ${_user!.email} (ID: ${_user!.id})');
          _isOfflineMode = _user!.id < 0;
          print('📶 Mode: ${_isOfflineMode ? "OFFLINE" : "ONLINE"}');
          
          if (!_isOfflineMode) {
            _autoSync();
          }
          
          notifyListeners();
          return true;
        } else {
          print('⚠️ No user found in database despite login state');
          await _saveLoginState(false, null);
          return false;
        }
      } else {
        print('📴 User was not logged in');
        return false;
      }
    } catch (e) {
      print('❌ Error initializing auth: $e');
      return false;
    }
  }
}
