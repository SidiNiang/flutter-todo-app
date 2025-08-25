import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class ProfileProvider with ChangeNotifier {
  String? _profileImagePath;
  bool _isLoading = false;
  int? _currentUserId;
  int? _previousUserId; // NOUVEAU : Pour détecter les changements d'ID

  String? get profileImagePath => _profileImagePath;
  bool get isLoading => _isLoading;

  ProfileProvider() {
    // Ne pas charger automatiquement, attendre l'ID utilisateur
  }

  // NOUVEAU : Méthode principale qui gère automatiquement la migration
  Future<void> loadProfileImageForUser(int userId) async {
    print('📸 Loading profile image for user $userId (previous: $_currentUserId)');
    
    // Détecter si l'ID utilisateur a changé (signe de synchronisation)
    bool userIdChanged = _currentUserId != null && _currentUserId != userId;
    int? oldUserId = _currentUserId;
    
    _currentUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    _profileImagePath = prefs.getString('profile_image_path_$userId');
    
    print('📸 Direct image found for user $userId: $_profileImagePath');
    
    // Si pas de photo trouvée ET que l'ID a changé, essayer la migration
    if (_profileImagePath == null && userIdChanged && oldUserId != null) {
      print('🔄 User ID changed from $oldUserId to $userId, attempting migration...');
      await _attemptMigration(oldUserId, userId);
    }
    
    // Si toujours pas de photo et que l'ancien ID était négatif, chercher toute photo à migrer
    if (_profileImagePath == null && oldUserId != null && oldUserId < 0) {
      print('🔍 No direct migration possible, searching for any offline profile image...');
      await _searchAndMigrateAnyOfflineImage(userId);
    }
    
    _previousUserId = oldUserId;
    notifyListeners();
  }

  // NOUVEAU : Tenter de migrer depuis un ID spécifique
  Future<void> _attemptMigration(int fromUserId, int toUserId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final oldImagePath = prefs.getString('profile_image_path_$fromUserId');
      
      if (oldImagePath != null && File(oldImagePath).existsSync()) {
        print('✅ Found image to migrate from $fromUserId: $oldImagePath');
        
        // Migrer vers le nouvel ID
        await prefs.setString('profile_image_path_$toUserId', oldImagePath);
        await prefs.remove('profile_image_path_$fromUserId');
        
        _profileImagePath = oldImagePath;
        print('✅ Migration successful from $fromUserId to $toUserId');
      } else {
        print('❌ No valid image found for user $fromUserId');
      }
    } catch (e) {
      print('❌ Error during specific migration: $e');
    }
  }

  // NOUVEAU : Chercher n'importe quelle photo offline à migrer
  Future<void> _searchAndMigrateAnyOfflineImage(int toUserId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      // Chercher toutes les clés de photos avec des IDs négatifs
      final offlineImageKeys = keys.where((key) => 
        key.startsWith('profile_image_path_-') && 
        key != 'profile_image_path_$toUserId'
      ).toList();
      
      print('🔍 Found ${offlineImageKeys.length} offline image keys: $offlineImageKeys');
      
      for (final key in offlineImageKeys) {
        final imagePath = prefs.getString(key);
        if (imagePath != null && File(imagePath).existsSync()) {
          print('✅ Found valid offline image: $imagePath');
          
          // Migrer cette image
          await prefs.setString('profile_image_path_$toUserId', imagePath);
          await prefs.remove(key);
          
          _profileImagePath = imagePath;
          print('✅ Migrated offline image to user $toUserId');
          return; // Arrêter après la première migration réussie
        } else {
          print('🗑️ Cleaning invalid image reference: $key');
          await prefs.remove(key);
        }
      }
      
      print('ℹ️ No valid offline images found to migrate');
    } catch (e) {
      print('❌ Error during offline image search: $e');
    }
  }

  Future<void> pickProfileImage() async {
    if (_currentUserId == null) {
      print('❌ Cannot pick image: no current user ID');
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
        
        print('📸 Image selected: ${pickedFile.path}');
        print('📏 File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
        
        if (fileSize > 5 * 1024 * 1024) {
          print('⚠️ Image too large, rejecting');
          _setError('Image trop volumineuse (max 5MB)');
          return;
        }
        
        _profileImagePath = pickedFile.path;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image_path_$_currentUserId', _profileImagePath!);
        
        print('✅ Profile image saved for user $_currentUserId: $_profileImagePath');
        notifyListeners();
      }
    } on OutOfMemoryError catch (e) {
      print('💥 OutOfMemoryError: Image too large to process');
      _setError('Image trop volumineuse pour être traitée');
    } catch (e) {
      print('❌ Error picking image: $e');
      _setError('Erreur lors de la sélection: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> takeProfilePhoto() async {
    if (_currentUserId == null) {
      print('❌ Cannot take photo: no current user ID');
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
        
        print('📸 Photo taken: ${pickedFile.path}');
        print('📏 File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
        
        _profileImagePath = pickedFile.path;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image_path_$_currentUserId', _profileImagePath!);
        
        print('✅ Profile photo saved for user $_currentUserId: $_profileImagePath');
        notifyListeners();
      }
    } on OutOfMemoryError catch (e) {
      print('💥 OutOfMemoryError: Photo too large to process');
      _setError('Photo trop volumineuse pour être traitée');
    } catch (e) {
      print('❌ Error taking photo: $e');
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
    print('🗑️ Profile image removed for user $_currentUserId');
    notifyListeners();
  }

  Future<void> switchUser(int newUserId) async {
    if (_currentUserId == newUserId) return;
    
    print('🔄 Switching from user $_currentUserId to user $newUserId');
    await loadProfileImageForUser(newUserId);
  }

  Future<void> clearTemporaryData() async {
    _currentUserId = null;
    _previousUserId = null;
    _profileImagePath = null;
    _isLoading = false;
    _lastError = null;
    print('🧹 Cleared temporary profile data');
    notifyListeners();
  }

  Future<void> deleteUserProfileImage(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('profile_image_path_$userId');
    
    if (_currentUserId == userId) {
      _profileImagePath = null;
      notifyListeners();
    }
    
    print('🗑️ Deleted profile image for user $userId');
  }

  // SIMPLIFIÉ : Migration manuelle (pour cas spéciaux)
  Future<void> migrateProfileImage(int oldUserId, int newUserId) async {
    await _attemptMigration(oldUserId, newUserId);
  }

  // Gestion des erreurs
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

  // NOUVEAU : Méthode pour déboguer l'état
  void debugProfileState() {
    print('🔍 === PROFILE PROVIDER DEBUG ===');
    print('Current User ID: $_currentUserId');
    print('Previous User ID: $_previousUserId');
    print('Profile Image Path: $_profileImagePath');
    print('Is Loading: $_isLoading');
    print('Last Error: $_lastError');
    print('🔍 === END DEBUG ===');
  }
}
