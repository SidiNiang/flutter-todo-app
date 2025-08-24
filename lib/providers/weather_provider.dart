import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/weather_service.dart';

class WeatherProvider with ChangeNotifier {
  WeatherData? _weatherData;
  Position? _position;
  bool _isLoading = false;
  String? _error;
  String _weatherSource = '';

  WeatherData? get weatherData => _weatherData;
  double? get temperature => _weatherData?.temperature;
  String? get cityName => _weatherData?.cityName;
  String? get country => _weatherData?.country;
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
      final testWeatherData = await WeatherService.testWeatherAPI();
      if (testWeatherData != null) {
        _weatherData = testWeatherData;
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
        _weatherData = await WeatherService.getWeatherData(
          _position!.latitude,
          _position!.longitude,
        );

        if (_weatherData != null) {
          _weatherSource = 'GPS (${_position!.latitude.toStringAsFixed(2)}, ${_position!.longitude.toStringAsFixed(2)})';
          print('✅ Weather data obtained via GPS: ${_weatherData!.cityName}, ${_weatherData!.temperature}°C');
        } else {
          print('⚠️ Failed to get weather data by GPS, trying fallback city');
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
      _weatherData = await WeatherService.getWeatherDataByCity(city: 'Paris');
      
      if (_weatherData != null) {
        _weatherSource = 'Paris (fallback)';
        print('✅ Fallback weather data obtained: ${_weatherData!.cityName}, ${_weatherData!.temperature}°C');
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
