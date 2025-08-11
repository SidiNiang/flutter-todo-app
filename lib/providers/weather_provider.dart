import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/weather_service.dart';

class WeatherProvider with ChangeNotifier {
  double? _temperature;
  Position? _position;
  bool _isLoading = false;
  String? _error;

  double? get temperature => _temperature;
  Position? get position => _position;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadWeatherData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Request location permission
      final permission = await Permission.location.request();
      if (permission != PermissionStatus.granted) {
        _error = 'Location permission denied';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Get current position
      _position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      // Get weather data
      _temperature = await WeatherService.getTemperature(
        _position!.latitude,
        _position!.longitude,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Error loading weather: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
}
