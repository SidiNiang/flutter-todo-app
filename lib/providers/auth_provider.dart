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

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isOfflineMode => _isOfflineMode;

  AuthProvider() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    _user = await DatabaseService.instance.getUser();
    notifyListeners();
  }

  // NOUVEAU : Vérifier la connectivité
  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isConnected = connectivityResult != ConnectivityResult.none;
      
      if (isConnected) {
        // Test de connectivité avec le serveur
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
      
      // Vérifier la connectivité
      final isOnline = await _checkConnectivity();
      
      if (isOnline) {
        print('📶 Mode ONLINE - Inscription via API');
        final user = await ApiService.register(email, password);
        if (user != null) {
          print('✅ Inscription réussie via API');
          _user = user;
          _isOfflineMode = false;
          await DatabaseService.instance.saveUser(user);
          await _saveLoginState(true);
          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          // Si l'API échoue, basculer en mode offline
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

  // NOUVEAU : Inscription offline
  Future<bool> _registerOffline(String email, String password) async {
    try {
      // Vérifier si l'email existe déjà localement
      final existingUsers = await DatabaseService.instance.getAllUsers();
      final emailExists = existingUsers.any((user) => user.email == email);
      
      if (emailExists) {
        _error = 'Cet email existe déjà localement';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Créer un utilisateur local avec un ID temporaire négatif
      final tempId = -(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      final user = User(
        id: tempId,
        email: email,
      );

      // Sauvegarder localement avec le mot de passe hashé
      await DatabaseService.instance.saveUserWithPassword(user, password);
      
      _user = user;
      _isOfflineMode = true;
      await _saveLoginState(true);
      
      // MODIFIÉ : Message de succès au lieu d'erreur
      _error = null; // Pas d'erreur, c'est un succès !
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
      
      // Vérifier la connectivité
      final isOnline = await _checkConnectivity();
      
      if (isOnline) {
        print('📶 Mode ONLINE - Connexion via API');
        final user = await ApiService.login(email, password);
        if (user != null) {
          print('✅ Connexion réussie via API');
          _user = user;
          _isOfflineMode = false;
          await DatabaseService.instance.saveUser(user);
          await _saveLoginState(true);
          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          // Si l'API échoue, essayer la connexion locale
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

  // NOUVEAU : Connexion offline
  Future<bool> _loginOffline(String email, String password) async {
    try {
      final success = await DatabaseService.instance.verifyUserCredentials(email, password);
      
      if (success) {
        final user = await DatabaseService.instance.getUserByEmail(email);
        if (user != null) {
          _user = user;
          _isOfflineMode = true;
          await _saveLoginState(true);
          
          // MODIFIÉ : Message informatif au lieu d'erreur
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

  // NOUVEAU : Synchroniser les comptes offline avec le serveur
  Future<void> syncOfflineAccounts() async {
    try {
      final isOnline = await _checkConnectivity();
      if (!isOnline) return;

      final offlineUsers = await DatabaseService.instance.getOfflineUsers();
      
      for (final offlineUser in offlineUsers) {
        if (offlineUser.id < 0) { // ID temporaire négatif
          print('🔄 Syncing offline user: ${offlineUser.email}');
          
          // Essayer de créer le compte sur le serveur
          final password = await DatabaseService.instance.getUserPassword(offlineUser.email);
          if (password != null) {
            final serverUser = await ApiService.register(offlineUser.email, password);
            if (serverUser != null) {
              // Remplacer l'utilisateur local par celui du serveur
              await DatabaseService.instance.updateUserAfterSync(offlineUser.id, serverUser);
              print('✅ User synced successfully: ${offlineUser.email}');
            }
          }
        }
      }
    } catch (e) {
      print('Sync error: $e');
    }
  }

  // MODIFIÉ : Logout sans supprimer les utilisateurs
  Future<void> logout() async {
    final currentUserId = _user?.id;
    print('🚪 Logging out user $currentUserId');
    
    _user = null;
    _isOfflineMode = false;
    await DatabaseService.instance.deleteUser(); // Ne supprime plus les utilisateurs
    await DatabaseService.instance.clearTodos();
    await _saveLoginState(false);
    
    print('✅ User logged out, user data preserved');
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
