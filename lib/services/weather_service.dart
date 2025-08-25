import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherData {
  final double temperature;
  final String cityName;
  final String country;

  WeatherData({
    required this.temperature,
    required this.cityName,
    required this.country,
  });
}

class WeatherService {
  static const String apiKey = '638d81e58870c0d141c62ba76459c338';
  static const String baseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  static Future<WeatherData?> getWeatherData(double latitude, double longitude) async {
    try {
      print('Demande météo pour: $latitude, $longitude');
      
      final url = '$baseUrl?lat=$latitude&lon=$longitude&appid=$apiKey&units=metric';
      print('URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'FlutterTodoApp/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      print('Statut de réponse API météo: ${response.statusCode}');
      print('Corps de réponse API météo: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final weatherData = WeatherData(
          temperature: data['main']['temp'].toDouble(),
          cityName: data['name'],
          country: data['sys']['country'],
        );
        print('Données météo obtenues: ${weatherData.cityName}, ${weatherData.temperature}°C');
        return weatherData;
      } else {
        print('Erreur API: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Erreur du service météo: $e');
      return null;
    }
  }

  static Future<WeatherData?> getWeatherDataByCity({String city = 'Paris'}) async {
    try {
      print('Demande météo pour la ville: $city');
      
      final url = '$baseUrl?q=$city&appid=$apiKey&units=metric';
      print('URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'FlutterTodoApp/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      print('Statut de réponse API météo: ${response.statusCode}');
      print('Corps de réponse API météo: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final weatherData = WeatherData(
          temperature: data['main']['temp'].toDouble(),
          cityName: data['name'],
          country: data['sys']['country'],
        );
        print('Données météo obtenues pour ${weatherData.cityName}: ${weatherData.temperature}°C');
        return weatherData;
      } else {
        print('Erreur API: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Erreur du service météo: $e');
      return null;
    }
  }

  static Future<WeatherData?> testWeatherAPI() async {
    try {
      print('Test de l\'API météo avec votre URL Postman...');
      
      const url = 'https://api.openweathermap.org/data/2.5/weather?id=2246678&appid=638d81e58870c0d141c62ba76459c338&units=metric';
      print('URL de test: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'FlutterTodoApp/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      print('Statut de réponse API test: ${response.statusCode}');
      print('Corps de réponse API test: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final weatherData = WeatherData(
          temperature: data['main']['temp'].toDouble(),
          cityName: data['name'],
          country: data['sys']['country'],
        );
        print('Données météo de test obtenues: ${weatherData.cityName}, ${weatherData.temperature}°C');
        return weatherData;
      } else {
        print('Erreur API test: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Erreur du service météo test: $e');
      return null;
    }
  }
}
