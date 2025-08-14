import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    _user = await DatabaseService.instance.getUser();
    notifyListeners();
  }

  Future<bool> register(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('AuthProvider: Début de l\'inscription pour $email');
      
      final user = await ApiService.register(email, password);
      if (user != null) {
        print('AuthProvider: Inscription réussie');
        _user = user;
        await DatabaseService.instance.saveUser(user);
        await _saveLoginState(true);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        print('AuthProvider: Échec de l\'inscription - aucun utilisateur retourné');
        _error = 'Échec de l\'inscription. Veuillez réessayer.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('AuthProvider: Exception lors de l\'inscription: $e');
      _error = 'Erreur d\'inscription: $e';
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
      
      final user = await ApiService.login(email, password);
      if (user != null) {
        print('AuthProvider: Connexion réussie');
        _user = user;
        await DatabaseService.instance.saveUser(user);
        await _saveLoginState(true);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        print('AuthProvider: Échec de la connexion - aucun utilisateur retourné');
        _error = 'Email ou mot de passe invalide';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('AuthProvider: Exception lors de la connexion: $e');
      _error = 'Erreur de connexion: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _user = null;
    await DatabaseService.instance.deleteUser();
    await DatabaseService.instance.clearTodos();
    await _saveLoginState(false);
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
