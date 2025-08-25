import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class ProfileProvider with ChangeNotifier {
  String? _profileImagePath;
  bool _isLoading = false;
  int? _currentUserId;
  int? _previousUserId;

  String? get profileImagePath => _profileImagePath;
  bool get isLoading => _isLoading;

  Future<void> loadProfileImageForUser(int userId) async {
    print('Chargement de l\'image de profil pour l\'utilisateur $userId (précédent: $_currentUserId)');
    
    bool userIdChanged = _currentUserId != null && _currentUserId != userId;
    int? oldUserId = _currentUserId;
    
    _currentUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    _profileImagePath = prefs.getString('profile_image_path_$userId');
    
    print('Image directe trouvée pour l\'utilisateur $userId: $_profileImagePath');
    
    if (_profileImagePath == null && userIdChanged && oldUserId != null) {
      print('ID utilisateur changé de $oldUserId vers $userId, tentative de migration...');
      await _attemptMigration(oldUserId, userId);
    }
    
    if (_profileImagePath == null && oldUserId != null && oldUserId < 0) {
      print('Aucune migration directe possible, recherche d\'image hors ligne...');
      await _searchAndMigrateAnyOfflineImage(userId);
    }
    
    _previousUserId = oldUserId;
    notifyListeners();
  }

  Future<void> _attemptMigration(int fromUserId, int toUserId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final oldImagePath = prefs.getString('profile_image_path_$fromUserId');
      
      if (oldImagePath != null && File(oldImagePath).existsSync()) {
        print('Image trouvée pour migration de $fromUserId: $oldImagePath');
        
        await prefs.setString('profile_image_path_$toUserId', oldImagePath);
        await prefs.remove('profile_image_path_$fromUserId');
        
        _profileImagePath = oldImagePath;
        print('Migration réussie de $fromUserId vers $toUserId');
      } else {
        print('Aucune image valide trouvée pour l\'utilisateur $fromUserId');
      }
    } catch (e) {
      print('Erreur lors de la migration spécifique: $e');
    }
  }

  Future<void> _searchAndMigrateAnyOfflineImage(int toUserId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      final offlineImageKeys = keys.where((key) => 
        key.startsWith('profile_image_path_-') && 
        key != 'profile_image_path_$toUserId'
      ).toList();
      
      print('${offlineImageKeys.length} clés d\'images hors ligne trouvées: $offlineImageKeys');
      
      for (final key in offlineImageKeys) {
        final imagePath = prefs.getString(key);
        if (imagePath != null && File(imagePath).existsSync()) {
          print('Image hors ligne valide trouvée: $imagePath');
          
          await prefs.setString('profile_image_path_$toUserId', imagePath);
          await prefs.remove(key);
          
          _profileImagePath = imagePath;
          print('Image hors ligne migrée vers l\'utilisateur $toUserId');
          return;
        } else {
          print('Nettoyage de la référence d\'image invalide: $key');
          await prefs.remove(key);
        }
      }
      
      print('Aucune image hors ligne valide trouvée pour migration');
    } catch (e) {
      print('Erreur lors de la recherche d\'image hors ligne: $e');
    }
  }

  Future<void> pickProfileImage() async {
    if (_currentUserId == null) {
      print('Impossible de sélectionner une image: aucun ID utilisateur actuel');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final picker = ImagePicker();
      
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 200,
        maxHeight: 200,
        imageQuality: 60,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSize = await file.length();
        
        print('Image sélectionnée: ${pickedFile.path}');
        print('Taille du fichier: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
        
        if (fileSize > 5 * 1024 * 1024) {
          print('Image trop volumineuse, rejetée');
          _setError('Image trop volumineuse (max 5MB)');
          return;
        }
        
        _profileImagePath = pickedFile.path;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image_path_$_currentUserId', _profileImagePath!);
        
        print('Image de profil sauvegardée pour l\'utilisateur $_currentUserId: $_profileImagePath');
        notifyListeners();
      }
    } on OutOfMemoryError catch (e) {
      print('Erreur de mémoire: Image trop volumineuse pour être traitée');
      _setError('Image trop volumineuse pour être traitée');
    } catch (e) {
      print('Erreur lors de la sélection d\'image: $e');
      _setError('Erreur lors de la sélection: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> takeProfilePhoto() async {
    if (_currentUserId == null) {
      print('Impossible de prendre une photo: aucun ID utilisateur actuel');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final picker = ImagePicker();
      
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 200,
        maxHeight: 200,
        imageQuality: 60,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSize = await file.length();
        
        print('Photo prise: ${pickedFile.path}');
        print('Taille du fichier: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
        
        _profileImagePath = pickedFile.path;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image_path_$_currentUserId', _profileImagePath!);
        
        print('Photo de profil sauvegardée pour l\'utilisateur $_currentUserId: $_profileImagePath');
        notifyListeners();
      }
    } on OutOfMemoryError catch (e) {
      print('Erreur de mémoire: Photo trop volumineuse pour être traitée');
      _setError('Photo trop volumineuse pour être traitée');
    } catch (e) {
      print('Erreur lors de la prise de photo: $e');
      _setError('Erreur lors de la prise de photo: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> removeProfileImage() async {
    if (_currentUserId == null) return;

    _profileImagePath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('profile_image_path_$_currentUserId');
    print('Image de profil supprimée pour l\'utilisateur $_currentUserId');
    notifyListeners();
  }

  Future<void> switchUser(int newUserId) async {
    if (_currentUserId == newUserId) return;
    
    print('Changement d\'utilisateur de $_currentUserId vers $newUserId');
    await loadProfileImageForUser(newUserId);
  }

  Future<void> clearTemporaryData() async {
    _currentUserId = null;
    _previousUserId = null;
    _profileImagePath = null;
    _isLoading = false;
    _lastError = null;
    print('Données temporaires de profil effacées');
    notifyListeners();
  }

  Future<void> deleteUserProfileImage(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('profile_image_path_$userId');
    
    if (_currentUserId == userId) {
      _profileImagePath = null;
      notifyListeners();
    }
    
    print('Image de profil supprimée pour l\'utilisateur $userId');
  }

  Future<void> migrateProfileImage(int oldUserId, int newUserId) async {
    await _attemptMigration(oldUserId, newUserId);
  }

  String? _lastError;
  String? get lastError => _lastError;

  void _setError(String error) {
    _lastError = error;
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  void debugProfileState() {
    print('=== DÉBOGAGE FOURNISSEUR DE PROFIL ===');
    print('ID utilisateur actuel: $_currentUserId');
    print('ID utilisateur précédent: $_previousUserId');
    print('Chemin image de profil: $_profileImagePath');
    print('En cours de chargement: $_isLoading');
    print('Dernière erreur: $_lastError');
    print('=== FIN DÉBOGAGE ===');
  }
}
