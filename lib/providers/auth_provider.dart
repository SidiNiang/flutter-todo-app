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
        print('Connectivité restaurée, démarrage de la synchronisation automatique...');
        _autoSync();
      }
    });
  }

  Future<void> _loadUser() async {
    try {
      print('Chargement de l\'utilisateur depuis la base de données...');
      
      final prefs = await SharedPreferences.getInstance();
      final loggedInUserId = prefs.getInt('logged_in_user_id');
      
      if (loggedInUserId != null) {
        print('Recherche de l\'utilisateur avec l\'ID: $loggedInUserId');
        _user = await DatabaseService.instance.getUserById(loggedInUserId);
        
        if (_user != null) {
          print('Utilisateur chargé: ${_user!.email} (ID: ${_user!.id})');
          _isOfflineMode = _user!.id < 0;
        } else {
          print('API échouée, basculement vers inscription hors ligne');
          await prefs.remove('logged_in_user_id');
          await prefs.setBool('is_logged_in', false);
          _isOfflineMode = false;
        }
      } else {
        print('Aucun ID d\'utilisateur connecté trouvé dans SharedPreferences');
        _user = null;
        _isOfflineMode = false;
      }
      
      notifyListeners();
    } catch (e) {
      print('Erreur lors du chargement de l\'utilisateur: $e');
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
      print('Erreur de vérification de connectivité: $e');
      return false;
    }
  }

  Future<bool> register(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('FournisseurAuth: Début de l\'inscription pour $email');
      
      final isOnline = await _checkConnectivity();
      
      if (isOnline) {
        print('Mode EN LIGNE - Inscription via API');
        final user = await ApiService.register(email, password);
        if (user != null) {
          print('Inscription réussie via API');
          _user = user;
          _isOfflineMode = false;
          await DatabaseService.instance.saveUser(user, password: password);
          await _saveLoginState(true, user.id);
          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          print('API échouée, basculement vers inscription hors ligne');
          return await _registerOffline(email, password);
        }
      } else {
        print('Mode HORS LIGNE - Inscription locale');
        return await _registerOffline(email, password);
      }
    } catch (e) {
      print('FournisseurAuth: Exception lors de l\'inscription: $e');
      print('Tentative d\'inscription hors ligne en secours');
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
      print('Erreur d\'inscription hors ligne: $e');
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
      print('FournisseurAuth: Début de la connexion pour $email');
      
      final isOnline = await _checkConnectivity();
      
      if (isOnline) {
        print('Mode EN LIGNE - Connexion via API');
        final user = await ApiService.login(email, password);
        if (user != null) {
          print('Connexion réussie via API');
          _user = user;
          _isOfflineMode = false;
          await DatabaseService.instance.saveUser(user, password: password);
          await _saveLoginState(true, user.id);
          _isLoading = false;
          notifyListeners();
          
          _autoSync();
          return true;
        } else {
          print('API échouée, tentative de connexion hors ligne');
          return await _loginOffline(email, password);
        }
      } else {
        print('Mode HORS LIGNE - Connexion locale');
        return await _loginOffline(email, password);
      }
    } catch (e) {
      print('FournisseurAuth: Exception lors de la connexion: $e');
      print('Tentative de connexion hors ligne en secours');
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
      print('Erreur de connexion hors ligne: $e');
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

      print('Démarrage de la synchronisation automatique...');
      await syncOfflineData();
    } catch (e) {
      print('Erreur de synchronisation automatique: $e');
    }
  }

  Future<void> syncOfflineData() async {
    if (_isSyncing) return;
    
    _isSyncing = true;
    notifyListeners();

    try {
      final isOnline = await _checkConnectivity();
      if (!isOnline) {
        print('Impossible de synchroniser: aucune connexion internet');
        return;
      }

      print('Démarrage de la synchronisation complète des données hors ligne...');

      final oldUserId = _user?.id;
      print('ID utilisateur actuel avant synchronisation: $oldUserId');

      await _syncOfflineUsers();

      if (_user != null) {
        final updatedUser = await DatabaseService.instance.getUserByEmail(_user!.email);
        if (updatedUser != null && updatedUser.id != oldUserId) {
          print('ID utilisateur changé de $oldUserId vers ${updatedUser.id}');
          _user = updatedUser;
          _isOfflineMode = false;
          await _saveLoginState(true, _user!.id);
        }
      }

      if (_user != null) {
        await _syncOfflineTodos();
      }

      print('Synchronisation des données hors ligne terminée');
      
    } catch (e) {
      print('Erreur de synchronisation: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _syncOfflineUsers() async {
    try {
      final offlineUsers = await DatabaseService.instance.getOfflineUsers();
      print('${offlineUsers.length} utilisateurs hors ligne trouvés pour synchronisation');
      
      for (final offlineUser in offlineUsers) {
        if (offlineUser.id < 0) {
          print('Synchronisation de l\'utilisateur hors ligne: ${offlineUser.email}');
          
          final password = await DatabaseService.instance.getUserPassword(offlineUser.email);
          if (password != null) {
            final serverUser = await ApiService.register(offlineUser.email, password);
            if (serverUser != null) {
              print('Utilisateur synchronisé vers le serveur: ${offlineUser.email} -> ID ${serverUser.id}');
              
              await DatabaseService.instance.updateUserAfterSync(offlineUser.id, serverUser);
              
              if (_user?.id == offlineUser.id) {
                _user = serverUser;
                _isOfflineMode = false;
                print('Utilisateur actuel mis à jour vers l\'ID serveur: ${serverUser.id}');
              }
            } else {
              print('Échec de synchronisation de l\'utilisateur vers le serveur: ${offlineUser.email}');
            }
          }
        }
      }
    } catch (e) {
      print('Erreur lors de la synchronisation des utilisateurs hors ligne: $e');
    }
  }

  Future<void> _syncOfflineTodos() async {
    try {
      print('Démarrage de la synchronisation des tâches pour l\'utilisateur ID: ${_user!.id}');
      
      final unsyncedTodos = await DatabaseService.instance.getUnsyncedTodos(_user!.id);
      print('${unsyncedTodos.length} tâches non synchronisées trouvées');
      
      for (final todo in unsyncedTodos) {
        print('Synchronisation de la tâche: ${todo.todo} (Compte: ${todo.accountId})');
        
        final todoForApi = todo.copyWith(accountId: _user!.id);
        
        final success = await ApiService.createTodo(todoForApi);
        if (success) {
          await DatabaseService.instance.markTodoAsSynced(todo.id!, todo.id!);
          print('Tâche synchronisée: ${todo.todo}');
        } else {
          print('Échec de synchronisation de la tâche: ${todo.todo}');
        }
      }
      
      print('Synchronisation des tâches terminée');
    } catch (e) {
      print('Erreur lors de la synchronisation des tâches hors ligne: $e');
    }
  }

  Future<void> manualSync() async {
    await syncOfflineData();
  }

  Future<void> logout() async {
    final currentUserId = _user?.id;
    print('Déconnexion de l\'utilisateur $currentUserId');
  
    _user = null;
    _isOfflineMode = false;
    _isSyncing = false;
    _error = null;
  
    await DatabaseService.instance.clearUserSession();
    await _saveLoginState(false, null);
  
    print('Utilisateur déconnecté, session effacée');
    notifyListeners();
  }

  Future<void> _saveLoginState(bool isLoggedIn, int? userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', isLoggedIn);
    
    if (isLoggedIn && userId != null) {
      await prefs.setInt('logged_in_user_id', userId);
      print('État de connexion sauvegardé: connecté=true, id_utilisateur=$userId');
    } else {
      await prefs.remove('logged_in_user_id');
      print('État de connexion sauvegardé: connecté=false, id_utilisateur=null');
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
      print('Initialisation de l\'authentification...');
      
      final wasLoggedIn = await isLoggedIn();
      print('Était connecté: $wasLoggedIn');
      
      if (wasLoggedIn) {
        await _loadUser();
        
        if (_user != null) {
          print('Utilisateur chargé depuis la base de données: ${_user!.email} (ID: ${_user!.id})');
          _isOfflineMode = _user!.id < 0;
          print('Mode: ${_isOfflineMode ? "HORS LIGNE" : "EN LIGNE"}');
          
          if (!_isOfflineMode) {
            _autoSync();
          }
          
          notifyListeners();
          return true;
        } else {
          print('Aucun utilisateur trouvé dans la base de données malgré l\'état de connexion');
          await _saveLoginState(false, null);
          return false;
        }
      } else {
        print('L\'utilisateur n\'était pas connecté');
        return false;
      }
    } catch (e) {
      print('Erreur lors de l\'initialisation de l\'authentification: $e');
      return false;
    }
  }
}
