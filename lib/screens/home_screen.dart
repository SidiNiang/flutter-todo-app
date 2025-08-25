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

  // SIMPLIFIÉ : Chargement des données sans logique de migration complexe
  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final todoProvider = Provider.of<TodoProvider>(context, listen: false);
    final weatherProvider = Provider.of<WeatherProvider>(context, listen: false);
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);

    if (authProvider.user != null) {
      print('🔄 Loading data for user: ${authProvider.user!.id}');
      
      // Le ProfileProvider détecte automatiquement les changements d'ID et fait la migration
      await profileProvider.loadProfileImageForUser(authProvider.user!.id);
      
      await todoProvider.loadTodos(authProvider.user!.id);
      await weatherProvider.loadWeatherData();
      
      print('✅ Data loading completed');
    }
  }

  Future<void> _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    
    await profileProvider.clearTemporaryData();
    await authProvider.logout();
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<void> _manualSync() async {
    print('🔄 Manual sync requested');
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Déboguer l'état avant sync
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    profileProvider.debugProfileState();
    
    await authProvider.manualSync();
    
    // Recharger les données après synchronisation
    await _loadData();
    
    // Déboguer l'état après sync
    profileProvider.debugProfileState();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Synchronisation terminée')),
      );
    }
  }

  void _showAddTodoDialog() {
    showDialog(
      context: context,
      builder: (context) => const AddTodoDialog(),
    );
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Photo de profil'),
        content: const Text('Choisissez une source pour votre photo de profil'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _pickImageFromGallery();
            },
            icon: const Icon(Icons.photo_library),
            label: const Text('Galerie'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _takePhoto();
            },
            icon: const Icon(Icons.camera_alt),
            label: const Text('Caméra'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    
    try {
      await profileProvider.pickProfileImage();
      
      if (mounted && profileProvider.lastError == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo de profil mise à jour')),
        );
      } else if (mounted && profileProvider.lastError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(profileProvider.lastError!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        profileProvider.clearError();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    
    try {
      await profileProvider.takeProfilePhoto();
      
      if (mounted && profileProvider.lastError == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo de profil mise à jour')),
        );
      } else if (mounted && profileProvider.lastError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(profileProvider.lastError!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        profileProvider.clearError();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // AppBar personnalisée avec plus d'espace
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue, Color(0xFF1976D2)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header avec titre et boutons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Mes Tâches',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                offset: Offset(1, 1),
                                blurRadius: 3,
                                color: Colors.black26,
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Consumer<AuthProvider>(
                              builder: (context, authProvider, child) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: IconButton(
                                    icon: authProvider.isSyncing
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.sync,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                    onPressed: authProvider.isSyncing ? null : _manualSync,
                                    tooltip: 'Synchroniser',
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.logout,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                onPressed: _logout,
                                tooltip: 'Se déconnecter',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Informations utilisateur et météo
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildUserInfo(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Barre de recherche
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildSearchBar(),
                  ),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          
          // Onglets de navigation
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              indicatorWeight: 3,
              tabs: const [
                Tab(
                  text: 'Toutes',
                  icon: Icon(Icons.list, size: 20),
                ),
                Tab(
                  text: 'En cours',
                  icon: Icon(Icons.pending_actions, size: 20),
                ),
                Tab(
                  text: 'Terminées',
                  icon: Icon(Icons.check_circle, size: 20),
                ),
              ],
            ),
          ),
          
          // Contenu des onglets
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
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildUserInfo() {
    return Consumer3<AuthProvider, WeatherProvider, ProfileProvider>(
      builder: (context, authProvider, weatherProvider, profileProvider, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _showImageSourceDialog,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white,
                        backgroundImage: profileProvider.profileImagePath != null
                            ? FileImage(File(profileProvider.profileImagePath!))
                            : null,
                        child: profileProvider.profileImagePath == null
                            ? const Icon(Icons.person, size: 32, color: Colors.blue)
                            : null,
                      ),
                      if (profileProvider.isLoading)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bienvenue,',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            authProvider.user?.email.split('@')[0] ?? 'Utilisateur',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  offset: Offset(1, 1),
                                  blurRadius: 2,
                                  color: Colors.black26,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: authProvider.isOfflineMode 
                                ? Colors.orange.withOpacity(0.8)
                                : Colors.green.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                authProvider.isOfflineMode ? Icons.wifi_off : Icons.wifi,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                authProvider.isOfflineMode ? 'Offline' : 'Online',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Colors.white.withOpacity(0.8),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: weatherProvider.weatherData != null
                              ? Text(
                                  '${weatherProvider.weatherData!.cityName}, ${weatherProvider.weatherData!.temperature.toStringAsFixed(1)}°C',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(1, 1),
                                        blurRadius: 2,
                                        color: Colors.black26,
                                      ),
                                    ],
                                  ),
                                )
                              : weatherProvider.isLoading
                                  ? Row(
                                      children: [
                                        SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.8)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Chargement...',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.8),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      'Météo indisponible',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 14,
                                      ),
                                    ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: IconButton(
                            onPressed: weatherProvider.isLoading 
                                ? null 
                                : () => weatherProvider.refreshWeather(),
                            icon: Icon(
                              weatherProvider.isLoading 
                                  ? Icons.hourglass_empty 
                                  : Icons.refresh,
                              color: Colors.white,
                              size: 18,
                            ),
                            tooltip: 'Actualiser la météo',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Consumer<TodoProvider>(
      builder: (context, todoProvider, child) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Rechercher des tâches...',
              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
              prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 24),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[600]),
                      onPressed: () {
                        _searchController.clear();
                        todoProvider.searchTodos('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
            onChanged: (value) {
              todoProvider.searchTodos(value);
            },
          ),
        );
      },
    );
  }

  Widget _buildTodoList(String filter) {
    return Consumer<TodoProvider>(
      builder: (context, todoProvider, child) {
        if (todoProvider.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                SizedBox(height: 16),
                Text(
                  'Chargement des tâches...',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
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
                  filter == 'completed' 
                      ? Icons.check_circle_outline 
                      : filter == 'pending'
                          ? Icons.pending_actions
                          : Icons.task_alt,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 24),
                Text(
                  filter == 'completed' 
                      ? 'Aucune tâche terminée'
                      : filter == 'pending'
                          ? 'Aucune tâche en cours'
                          : 'Aucune tâche',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                if (filter != 'completed') ...[
                  const SizedBox(height: 12),
                  Text(
                    'Appuyez sur + pour ajouter votre première tâche',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadData,
          color: Colors.blue,
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
