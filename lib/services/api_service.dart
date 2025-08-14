import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/todo.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.1.109/todo';
  
  static Future<User?> register(String email, String password) async {
    try {
      print('Attempting to register: $email');
      
      final response = await http.post(
        Uri.parse('$baseUrl/register.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      print('Register response status: ${response.statusCode}');
      print('Register response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.body.trim().isEmpty) {
          print('Empty response body');
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
      
      final response = await http.post(
        Uri.parse('$baseUrl/login.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      print('Login response status: ${response.statusCode}');
      print('Login response body: "${response.body}"');
      print('Login response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        if (response.body.trim().isEmpty) {
          print('Empty response body from login API');
          return null;
        }
        
        try {
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
            print('Login failed: ${data['message']}');
          }
        } catch (jsonError) {
          print('JSON decode error: $jsonError');
          print('Raw response: "${response.body}"');
          return null;
        }
      } else {
        print('HTTP error: ${response.statusCode}');
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  static Future<List<Todo>> getTodos(int accountId) async {
    try {
      print('Getting todos for account: $accountId');
      
      final response = await http.post(
        Uri.parse('$baseUrl/todos.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': accountId,
        }),
      );

      print('Get todos response: ${response.body}');

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
            print('Error parsing todos: $parseError');
            return [];
          }
        }
      }
      return [];
    } catch (e) {
      print('Get todos error: $e');
      return [];
    }
  }

  static Future<bool> createTodo(Todo todo) async {
    try {
      print('Creating todo: ${todo.todo}');
      
      final response = await http.post(
        Uri.parse('$baseUrl/inserttodo.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(todo.toApiJson()),
      );

      print('Create todo response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Create todo error: $e');
      return false;
    }
  }

  static Future<bool> updateTodo(Todo todo) async {
    try {
      print('Updating todo: ${todo.id}');
      
      final response = await http.post(
        Uri.parse('$baseUrl/updatetodo.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': todo.id,
          'date': todo.date.toIso8601String().split('T')[0],
          'todo': todo.todo,
          'done': todo.done,
        }),
      );

      print('Update todo response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Update todo error: $e');
      return false;
    }
  }

  static Future<bool> deleteTodo(int todoId) async {
    try {
      print('Deleting todo: $todoId');
      
      final response = await http.post(
        Uri.parse('$baseUrl/deletetodo.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': todoId,
        }),
      );

      print('Delete todo response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Delete todo error: $e');
      return false;
    }
  }
}
