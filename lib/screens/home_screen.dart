import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/todo_provider.dart';
import '../providers/weather_provider.dart';
import '../providers/profile_provider.dart';
import '../models/todo.dart';
import '../widgets/todo_item.dart';
import '../widgets/add_todo_dialog.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final todoProvider = Provider.of<TodoProvider>(context, listen: false);
    final weatherProvider = Provider.of<WeatherProvider>(context, listen: false);

    if (authProvider.user != null) {
      await todoProvider.loadTodos(authProvider.user!.id);
      await weatherProvider.loadWeatherData();
    }
  }

  Future<void> _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _showAddTodoDialog() {
    showDialog(
      context: context,
      builder: (context) => const AddTodoDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Tâches'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Se déconnecter',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildUserInfo(),
                const SizedBox(height: 16),
                _buildSearchBar(),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: const [
              Tab(text: 'Toutes'),
              Tab(text: 'En cours'),
              Tab(text: 'Terminées'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTodoList('all'),
                _buildTodoList('pending'),
                _buildTodoList('completed'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTodoDialog,
        backgroundColor: Colors.blue,
        tooltip: 'Ajouter une tâche',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildUserInfo() {
    return Consumer3<AuthProvider, WeatherProvider, ProfileProvider>(
      builder: (context, authProvider, weatherProvider, profileProvider, child) {
        return Row(
          children: [
            GestureDetector(
              onTap: () => profileProvider.pickProfileImage(),
              child: CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                backgroundImage: profileProvider.profileImagePath != null
                    ? FileImage(File(profileProvider.profileImagePath!))
                    : null,
                child: profileProvider.profileImagePath == null
                    ? const Icon(Icons.person, size: 30, color: Colors.blue)
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bienvenue, ${authProvider.user?.email ?? 'Utilisateur'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (weatherProvider.temperature != null)
                    Text(
                      'Température : ${weatherProvider.temperature!.toStringAsFixed(1)}°C',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    )
                  else if (weatherProvider.isLoading)
                    const Text(
                      'Chargement de la météo...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    )
                  else
                    const Text(
                      'Météo indisponible',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Consumer<TodoProvider>(
      builder: (context, todoProvider, child) {
        return TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Rechercher des tâches...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      todoProvider.searchTodos('');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (value) {
            todoProvider.searchTodos(value);
          },
        );
      },
    );
  }

  Widget _buildTodoList(String filter) {
    return Consumer<TodoProvider>(
      builder: (context, todoProvider, child) {
        if (todoProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        List<Todo> todos;
        switch (filter) {
          case 'pending':
            todos = todoProvider.pendingTodos;
            break;
          case 'completed':
            todos = todoProvider.completedTodos;
            break;
          default:
            todos = todoProvider.todos;
        }

        if (todos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  filter == 'completed' ? Icons.check_circle_outline : Icons.task_alt,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  filter == 'completed' 
                      ? 'Aucune tâche terminée'
                      : filter == 'pending'
                          ? 'Aucune tâche en cours'
                          : 'Aucune tâche',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
                if (filter != 'completed') ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Appuyez sur + pour ajouter votre première tâche',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadData,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: todos.length,
            itemBuilder: (context, index) {
              return TodoItem(todo: todos[index]);
            },
          ),
        );
      },
    );
  }
}
