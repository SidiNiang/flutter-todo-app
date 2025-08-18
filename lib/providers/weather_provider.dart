import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
// import 'package:permission_handler/permission_handler.dart';
import '../services/weather_service.dart';

class WeatherProvider with ChangeNotifier {
  double? _temperature;
  Position? _position;
  bool _isLoading = false;
  String? _error;
  String _weatherSource = '';

  double? get temperature => _temperature;
  Position? get position => _position;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get weatherSource => _weatherSource;

  Future<void> loadWeatherData() async {
    _isLoading = true;
    _error = null;
    _weatherSource = '';
    notifyListeners();

    try {
      print('🚀 Starting weather data loading...');
      
      // D'abord, tester l'API avec votre URL Postman qui fonctionne
      print('🧪 Testing API first...');
      final testTemp = await WeatherService.testWeatherAPI();
      if (testTemp != null) {
        _temperature = testTemp;
        _weatherSource = 'Test API (ID: 2246678)';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Vérifier si les services de localisation sont activés
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('📍 Location service enabled: $serviceEnabled');
      
      if (!serviceEnabled) {
        print('⚠️ Location services are disabled, using fallback city');
        await _loadWeatherByCity();
        return;
      }

      // Vérifier les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      print('📍 Current permission status: $permission');
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('📍 Permission after request: $permission');
        
        if (permission == LocationPermission.denied) {
          print('⚠️ Location permissions denied, using fallback city');
          await _loadWeatherByCity();
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        print('⚠️ Location permissions permanently denied, using fallback city');
        await _loadWeatherByCity();
        return;
      }

      // Obtenir la position actuelle avec timeout
      print('📍 Getting current position...');
      try {
        _position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 15),
        );
        
        print('✅ Position obtained: ${_position!.latitude}, ${_position!.longitude}');

        // Obtenir les données météo
        _temperature = await WeatherService.getTemperature(
          _position!.latitude,
          _position!.longitude,
        );

        if (_temperature != null) {
          _weatherSource = 'GPS (${_position!.latitude.toStringAsFixed(2)}, ${_position!.longitude.toStringAsFixed(2)})';
          print('✅ Temperature obtained via GPS: ${_temperature}°C');
        } else {
          print('⚠️ Failed to get temperature by GPS, trying fallback city');
          await _loadWeatherByCity();
        }
      } catch (e) {
        print('❌ Error getting position: $e');
        print('⚠️ Using fallback city due to GPS error');
        await _loadWeatherByCity();
      }

    } catch (e) {
      print('💥 General error in loadWeatherData: $e');
      _error = 'Erreur lors du chargement de la météo: $e';
      // Essayer le fallback même en cas d'erreur générale
      await _loadWeatherByCity();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadWeatherByCity() async {
    try {
      print('🏙️ Loading weather by city (fallback)...');
      _temperature = await WeatherService.getTemperatureByCity(city: 'Paris');
      
      if (_temperature != null) {
        _weatherSource = 'Paris (fallback)';
        print('✅ Fallback temperature obtained: ${_temperature}°C');
        _error = null; // Clear any previous error
      } else {
        _error = 'Impossible de récupérer la température';
      }
    } catch (e) {
      print('💥 Error in fallback weather: $e');
      _error = 'Erreur lors du chargement de la météo: $e';
    }
  }

  // Méthode pour forcer le rechargement
  Future<void> refreshWeather() async {
    await loadWeatherData();
  }
}
