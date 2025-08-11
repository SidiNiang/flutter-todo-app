import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class ProfileProvider with ChangeNotifier {
  String? _profileImagePath;
  bool _isLoading = false;

  String? get profileImagePath => _profileImagePath;
  bool get isLoading => _isLoading;

  ProfileProvider() {
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    _profileImagePath = prefs.getString('profile_image_path');
    notifyListeners();
  }

  Future<void> pickProfileImage() async {
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
        
        // Save to shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image_path', _profileImagePath!);
        
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
    _profileImagePath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('profile_image_path');
    notifyListeners();
  }
}
