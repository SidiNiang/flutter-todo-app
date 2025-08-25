import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/todo.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.1.8/todo';

  static Future<bool> testConnection() async {
    try {

      final response = await http.get(
        Uri.parse('$baseUrl/test_connection.php'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));


      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          return data['success'] == true;
        } catch (e) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<User?> register(String email, String password) async {
    try {

      final response = await http
          .post(
            Uri.parse('$baseUrl/register.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10)); // AJOUTÉ timeout


      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.body.trim().isEmpty) {
          return null;
        }

        final data = jsonDecode(response.body);
        if (data['success'] == true && data['user'] != null) {
          try {
            return User.fromJson(data['user']);
          } catch (parseError) {
            print('Error parsing user data: $parseError');
            print('User data received: ${data['user']}');
            return null;
          }
        } else {
          print('Register failed: ${data['message']}');
        }
      }
      return null;
    } catch (e) {
      print('Register error: $e');
      return null;
    }
  }

  static Future<User?> login(String email, String password) async {
    try {
      print('Attempting to login: $email');
      print('Using base URL: $baseUrl');

      final response = await http
          .post(
            Uri.parse('$baseUrl/login.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10)); // AJOUTÉ timeout


      if (response.statusCode == 200) {
        if (response.body.trim().isEmpty) {
          print("l'API retourne rien");
          return null;
        }

        try {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['user'] != null) {
            try {
              return User.fromJson(data['user']);
            } catch (parseError) {
              print('$parseError');
              return null;
            }
          } else {
            print('connexion echoue : ${data['message']}');
          }
        } catch (jsonError) {
          return null;
        }
      } else {
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<Todo>> getTodos(int accountId) async {
    try {

      final response = await http
          .post(
            Uri.parse('$baseUrl/todos.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id': accountId,
            }),
          )
          .timeout(const Duration(seconds: 10)); // AJOUTÉ timeout


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['todos'] != null) {
          List<Todo> todos = [];
          try {
            for (var todoData in data['todos']) {
              todos.add(Todo.fromJson(todoData));
            }
            return todos;
          } catch (parseError) {
            return [];
          }
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> createTodo(Todo todo) async {
    try {

      final response = await http
          .post(
            Uri.parse('$baseUrl/inserttodo.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(todo.toApiJson()),
          )
          .timeout(const Duration(seconds: 10)); // AJOUTÉ timeout


      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateTodo(Todo todo) async {
    try {

      final response = await http
          .post(
            Uri.parse('$baseUrl/updatetodo.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id': todo.id,
              'date': todo.date.toIso8601String().split('T')[0],
              'todo': todo.todo,
              'done': todo.done,
            }),
          )
          .timeout(const Duration(seconds: 10)); // AJOUTÉ timeout

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteTodo(int todoId) async {
    try {

      final response = await http
          .post(
            Uri.parse('$baseUrl/deletetodo.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id': todoId,
            }),
          )
          .timeout(const Duration(seconds: 10)); // AJOUTÉ timeout


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
