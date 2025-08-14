import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/todo.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.1.109/todo'; // Votre IP
  
  static Future<User?> register(String email, String password) async {
    try {
      print('Attempting to register: $email'); // Debug
      
      final response = await http.post(
        Uri.parse('$baseUrl/register.php'), // Ajout de .php
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      print('Register response status: ${response.statusCode}'); // Debug
      print('Register response body: ${response.body}'); // Debug

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return User.fromJson(data['user']);
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
      print('Attempting to login: $email'); // Debug
      
      final response = await http.post(
        Uri.parse('$baseUrl/login.php'), // Ajout de .php
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      print('Login response status: ${response.statusCode}'); // Debug
      print('Login response body: ${response.body}'); // Debug

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return User.fromJson(data['user']);
        } else {
          print('Login failed: ${data['message']}');
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
      print('Getting todos for account: $accountId'); // Debug
      
      final response = await http.post(
        Uri.parse('$baseUrl/todos.php'), // Ajout de .php
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': accountId,
        }),
      );

      print('Get todos response: ${response.body}'); // Debug

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
      print('Creating todo: ${todo.todo}'); // Debug
      
      final response = await http.post(
        Uri.parse('$baseUrl/inserttodo.php'), // Ajout de .php
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(todo.toApiJson()),
      );

      print('Create todo response: ${response.body}'); // Debug

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
      print('Updating todo: ${todo.id}'); // Debug
      
      final response = await http.post(
        Uri.parse('$baseUrl/updatetodo.php'), // Ajout de .php
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': todo.id,
          'date': todo.date.toIso8601String().split('T')[0],
          'todo': todo.todo,
          'done': todo.done,
        }),
      );

      print('Update todo response: ${response.body}'); // Debug

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
      print('Deleting todo: $todoId'); // Debug
      
      final response = await http.post(
        Uri.parse('$baseUrl/deletetodo.php'), // Ajout de .php
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': todoId,
        }),
      );

      print('Delete todo response: ${response.body}'); // Debug

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
