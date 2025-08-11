import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/todo.dart';

class ApiService {
  static const String baseUrl = 'http://localhost/todo'; // Change to your IP for mobile
  
  static Future<User?> register(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return User.fromJson(data['user']);
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
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return User.fromJson(data['user']);
        }
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  static Future<List<Todo>> getTodos(int accountId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/todos'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': accountId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          List<Todo> todos = [];
          for (var todoData in data['todos']) {
            todos.add(Todo.fromJson(todoData));
          }
          return todos;
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
      final response = await http.post(
        Uri.parse('$baseUrl/inserttodo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(todo.toApiJson()),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Create todo error: $e');
      return false;
    }
  }

  static Future<bool> updateTodo(Todo todo) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/updatetodo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': todo.id,
          'date': todo.date.toIso8601String().split('T')[0],
          'todo': todo.todo,
          'done': todo.done,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Update todo error: $e');
      return false;
    }
  }

  static Future<bool> deleteTodo(int todoId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/deletetodo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': todoId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Delete todo error: $e');
      return false;
    }
  }
}
