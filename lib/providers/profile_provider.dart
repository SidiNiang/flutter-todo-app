import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class ProfileProvider with ChangeNotifier {
  String? _profileImagePath;
  bool _isLoading = false;
  int? _currentUserId;

  String? get profileImagePath => _profileImagePath;
  bool get isLoading => _isLoading;

  ProfileProvider() {
    // Ne pas charger automatiquement, attendre l'ID utilisateur
  }

  // NOUVEAU : Charger la photo pour un utilisateur spécifique
  Future<void> loadProfileImageForUser(int userId) async {
    _currentUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    _profileImagePath = prefs.getString('profile_image_path_$userId');
    print('📸 Loaded profile image for user $userId: $_profileImagePath');
    notifyListeners();
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
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        _profileImagePath = pickedFile.path;
        
        // MODIFIÉ : Sauvegarder avec l'ID utilisateur
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image_path_$_currentUserId', _profileImagePath!);
        
        print('✅ Profile image saved for user $_currentUserId: $_profileImagePath');
        notifyListeners();
      }
    } catch (e) {
      print('Error picking image: $e');
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

  // MODIFIÉ : Changer d'utilisateur sans supprimer les photos
  Future<void> switchUser(int newUserId) async {
    if (_currentUserId == newUserId) return;
    
    print('🔄 Switching from user $_currentUserId to user $newUserId');
    await loadProfileImageForUser(newUserId);
  }

  // NOUVEAU : Nettoyer seulement les données temporaires, pas les photos
  Future<void> clearTemporaryData() async {
    _currentUserId = null;
    _profileImagePath = null;
    _isLoading = false;
    print('🧹 Cleared temporary profile data');
    notifyListeners();
  }

  // OPTIONNEL : Supprimer la photo d'un utilisateur spécifique
  Future<void> deleteUserProfileImage(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('profile_image_path_$userId');
    
    if (_currentUserId == userId) {
      _profileImagePath = null;
      notifyListeners();
    }
    
    print('🗑️ Deleted profile image for user $userId');
  }
}
