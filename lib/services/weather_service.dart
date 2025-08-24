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
        final weatherData = WeatherData(
          temperature: data['main']['temp'].toDouble(),
          cityName: data['name'],
          country: data['sys']['country'],
        );
        print('🌡️ Weather data obtained: ${weatherData.cityName}, ${weatherData.temperature}°C');
        return weatherData;
      } else {
        print('❌ API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('💥 Weather service error: $e');
      return null;
    }
  }

  static Future<WeatherData?> getWeatherDataByCity({String city = 'Paris'}) async {
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
        final weatherData = WeatherData(
          temperature: data['main']['temp'].toDouble(),
          cityName: data['name'],
          country: data['sys']['country'],
        );
        print('🌡️ Weather data obtained for ${weatherData.cityName}: ${weatherData.temperature}°C');
        return weatherData;
      } else {
        print('❌ API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('💥 Weather service error: $e');
      return null;
    }
  }

  static Future<WeatherData?> testWeatherAPI() async {
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
        final weatherData = WeatherData(
          temperature: data['main']['temp'].toDouble(),
          cityName: data['name'],
          country: data['sys']['country'],
        );
        print('🌡️ Test weather data obtained: ${weatherData.cityName}, ${weatherData.temperature}°C');
        return weatherData;
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
