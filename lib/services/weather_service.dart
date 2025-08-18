import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  static const String apiKey = '638d81e58870c0d141c62ba76459c338';
  static const String baseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  static Future<double?> getTemperature(double latitude, double longitude) async {
    try {
      print('🌡️ Requesting weather for: $latitude, $longitude');
      
      final url = '$baseUrl?lat=$latitude&lon=$longitude&appid=$apiKey&units=metric';
      print('🌐 URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'FlutterTodoApp/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      print('📡 Weather API Response Status: ${response.statusCode}');
      print('📄 Weather API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final temperature = data['main']['temp'].toDouble();
        print('🌡️ Temperature obtained: ${temperature}°C');
        return temperature;
      } else {
        print('❌ API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('💥 Weather service error: $e');
      return null;
    }
  }

  // Méthode de fallback avec une ville par défaut (Paris)
  static Future<double?> getTemperatureByCity({String city = 'Paris'}) async {
    try {
      print('🏙️ Requesting weather for city: $city');
      
      final url = '$baseUrl?q=$city&appid=$apiKey&units=metric';
      print('🌐 URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'FlutterTodoApp/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      print('📡 Weather API Response Status: ${response.statusCode}');
      print('📄 Weather API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final temperature = data['main']['temp'].toDouble();
        final cityName = data['name'];
        print('🌡️ Temperature obtained for $cityName: ${temperature}°C');
        return temperature;
      } else {
        print('❌ API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('💥 Weather service error: $e');
      return null;
    }
  }

  // Test direct de l'API avec votre URL Postman
  static Future<double?> testWeatherAPI() async {
    try {
      print('🧪 Testing weather API with your Postman URL...');
      
      const url = 'https://api.openweathermap.org/data/2.5/weather?id=2246678&appid=638d81e58870c0d141c62ba76459c338&units=metric';
      print('🌐 Test URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'FlutterTodoApp/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      print('📡 Test API Response Status: ${response.statusCode}');
      print('📄 Test API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final temperature = data['main']['temp'].toDouble();
        final cityName = data['name'];
        print('🌡️ Test temperature obtained for $cityName: ${temperature}°C');
        return temperature;
      } else {
        print('❌ Test API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('💥 Test weather service error: $e');
      return null;
    }
  }
}
