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
      print('Démarrage du chargement des données météo...');
      
      print('Test de l\'API d\'abord...');
      final testWeatherData = await WeatherService.testWeatherAPI();
      if (testWeatherData != null) {
        _weatherData = testWeatherData;
        _weatherSource = 'API Test (ID: 2246678)';
        _isLoading = false;
        notifyListeners();
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('Service de localisation activé: $serviceEnabled');
      
      if (!serviceEnabled) {
        print('Services de localisation désactivés, utilisation de la ville de secours');
        await _loadWeatherByCity();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      print('Statut de permission actuel: $permission');
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('Permission après demande: $permission');
        
        if (permission == LocationPermission.denied) {
          print('Permissions de localisation refusées, utilisation de la ville de secours');
          await _loadWeatherByCity();
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        print('Permissions de localisation refusées définitivement, utilisation de la ville de secours');
        await _loadWeatherByCity();
        return;
      }

      print('Obtention de la position actuelle...');
      try {
        _position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 15),
        );
        
        print('Position obtenue: ${_position!.latitude}, ${_position!.longitude}');

        _weatherData = await WeatherService.getWeatherData(
          _position!.latitude,
          _position!.longitude,
        );

        if (_weatherData != null) {
          _weatherSource = 'GPS (${_position!.latitude.toStringAsFixed(2)}, ${_position!.longitude.toStringAsFixed(2)})';
          print('Données météo obtenues via GPS: ${_weatherData!.cityName}, ${_weatherData!.temperature}°C');
        } else {
          print('Échec d\'obtention des données météo par GPS, tentative avec ville de secours');
          await _loadWeatherByCity();
        }
      } catch (e) {
        print('Erreur lors de l\'obtention de la position: $e');
        print('Utilisation de la ville de secours à cause de l\'erreur GPS');
        await _loadWeatherByCity();
      }

    } catch (e) {
      print('Erreur générale dans loadWeatherData: $e');
      _error = 'Erreur lors du chargement de la météo: $e';
      await _loadWeatherByCity();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadWeatherByCity() async {
    try {
      print('Chargement de la météo par ville (secours)...');
      _weatherData = await WeatherService.getWeatherDataByCity(city: 'Paris');
      
      if (_weatherData != null) {
        _weatherSource = 'Paris (secours)';
        print('Données météo de secours obtenues: ${_weatherData!.cityName}, ${_weatherData!.temperature}°C');
        _error = null;
      } else {
        _error = 'Impossible de récupérer la température';
      }
    } catch (e) {
      print('Erreur dans la météo de secours: $e');
      _error = 'Erreur lors du chargement de la météo: $e';
    }
  }

  Future<void> refreshWeather() async {
    await loadWeatherData();
  }
}
