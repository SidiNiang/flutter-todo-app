import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  static const String apiKey = 'YOUR_OPENWEATHER_API_KEY'; // Replace with your API key
  static const String baseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  static Future<double?> getTemperature(double latitude, double longitude) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?lat=$latitude&lon=$longitude&appid=$apiKey&units=metric'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['main']['temp'].toDouble();
      }
      return null;
    } catch (e) {
      print('Weather error: $e');
      return null;
    }
  }
}
