import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'quiz_screen.dart';
// Import the service file to fetch data
import '../services/firestore_service.dart';
import 'login_screen.dart';

// --- NEW SCREENS (You will need to create these files) ---
import 'create_room_screen.dart';
import 'join_room_screen.dart';
// 🚨 NEW IMPORT: Profile Screen
import 'profile_screen.dart';
// -----------------------------------------------------------

// --- NEW DATA MODEL FOR CATEGORY DISPLAY ---
typedef CategoryData = Map<String, String>;

// Helper function to capitalize the first letter of the username for display
String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1).toLowerCase();
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _service = FirestoreService();

  Future<List<CategoryData>>? _categoriesFuture;

  // Use a String to track the current view state: 'welcome', 'solo_categories', 'multiplayer', 'about'
  String _currentView = 'welcome';

  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Custom colors for the category buttons (using a fixed map for styling)
  final Map<String, Color> categoryColors = {
    "Computer Science": Colors.blueAccent,
    "Engineering": Colors.orangeAccent,
    "Mathematics": Colors.purpleAccent,
    "Biomedical": Colors.greenAccent,
    "General Knowledge": Colors.tealAccent,
  };

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _service.getQuizCategories();
  }

  void navigateToQuiz(BuildContext context, String categoryId, String categoryName) {
    // Ensure QuizScreen is updated to accept the timeLimitSeconds parameter, defaulting to 1200
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          categoryId: categoryId,
          categoryName: categoryName,
          // 🚨 Passing default time limit for Solo Quizzes
          timeLimitSeconds: 1200,
        ),
      ),
    );
  }

  void navigateToCreateRoom(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateRoomScreen()),
    );
  }

  void navigateToJoinRoom(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const JoinRoomScreen()),
    );
  }

  // 🚨 NEW: Function to open the Profile Screen
  void navigateToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String rawUsername = currentUser?.displayName ?? "User";
    final String formattedUsername = _capitalize(rawUsername);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: Text(
          "Welcome, $formattedUsername",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          // 🚨 NEW: Profile Icon Button
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white, size: 28),
            onPressed: () => navigateToProfile(context),
            tooltip: "My Profile",
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _logout(context),
            tooltip: "Logout",
          ),
          // Add a back button for category/multiplayer/about views
          if (_currentView != 'welcome')
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                setState(() {
                  _currentView = 'welcome';
                });
              },
              tooltip: "Go Back",
            ),
        ],
        backgroundColor: const Color(0xFF1E1E2C),
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: _buildBodyContent(),
        ),
      ),
    );
  }

  // --- BUILD METHOD FOR DYNAMIC CONTENT ---
  Widget _buildBodyContent() {
    switch (_currentView) {
      case 'solo_categories':
        return _buildCategorySelectionSection();
      case 'multiplayer':
        return _buildMultiplayerSection();
      case 'about':
        return _buildAboutSection();
      case 'welcome':
      default:
        return _buildWelcomeSection();
    }
  }

  // --- WELCOME SECTION ---
  Widget _buildWelcomeSection() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Welcome to Smart Quiz",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // --- RANDOM QUIZ BUTTON (Leads to Solo Categories) ---
        _menuButton(
          "Random Quiz",
              () {
            setState(() {
              _currentView = 'solo_categories'; // Change view to categories
            });
          },
          Colors.orangeAccent,
          Icons.shuffle,
        ),
        const SizedBox(height: 20),
        // --- QUIZ ROOM BUTTON (Leads to Multiplayer options) ---
        _menuButton(
          "Quiz Room",
              () {
            setState(() {
              _currentView = 'multiplayer'; // Change view to multiplayer options
            });
          },
          Colors.blueAccent,
          Icons.group,
        ),
        const SizedBox(height: 20),
        // ⭐️ ABOUT US BUTTON
        _menuButton(
          "About Us",
              () {
            setState(() {
              _currentView = 'about'; // Change view to about section
            });
          },
          const Color(0xFF9C27B0), // Purple for About
          Icons.info_outline,
        ),
      ],
    );
  }

  // --- ⭐️ ABOUT SECTION WIDGET ---
  Widget _buildAboutSection() {
    const teamMembers = [
      'Sarmad Chughtai',
      'Shahroz Khalid',
      'Kashan Shahid',
      'Sinwan Haider'
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "About Smart Quiz",
            style: TextStyle(
              color: Colors.amber,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(color: Colors.white38, height: 20),

          const Text(
            "Project Overview:",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "The Smart Quiz application is a comprehensive platform built using Flutter and Firebase Firestore, designed to provide dynamic and engaging quiz experiences. It supports both solo play across various categories (Computer Science, Mathematics, Engineering, etc.) and future expansion into real-time multiplayer rooms.",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 20),

          const Text(
            "Core Features:",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BulletPoint("Dynamic Data Fetching (Firebase Firestore)"),
              _BulletPoint("Strict Quiz Integrity (No cheating/changing answers)"),
              _BulletPoint("Immediate Answer Feedback (Green/Red highlights)"),
              _BulletPoint("Score Tracking and Review System"),
              _BulletPoint("Randomized Question Ordering"),
              _BulletPoint("Authentication via Firebase Auth"),
            ],
          ),
          const SizedBox(height: 20),

          const Text(
            "Project Team:",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...teamMembers.map((name) => Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              children: [
                const Icon(Icons.person, color: Colors.blueAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          )).toList(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ⭐️ Helper widget for the About Section bullets
  static Widget _BulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: TextStyle(color: Colors.greenAccent, fontSize: 16)),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 16))),
        ],
      ),
    );
  }


  // --- Multiplayer Menu Section ---
  Widget _buildMultiplayerSection() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Multiplayer Options",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // --- CREATE ROOM BUTTON ---
        _menuButton(
          "Create Room",
              () => navigateToCreateRoom(context),
          const Color(0xFF4CAF50), // Green for Create
          Icons.meeting_room,
        ),
        const SizedBox(height: 20),
        // --- JOIN ROOM BUTTON ---
        _menuButton(
          "Join Room",
              () => navigateToJoinRoom(context),
          const Color(0xFF2196F3), // Blue for Join
          Icons.group_add,
        ),
      ],
    );
  }

  // --- 🎨 REFACTORED: Glassy Button Widget ---
  Widget _menuButton(String text, VoidCallback onPressed, Color color, IconData icon) {
    final Color accentColor = color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withOpacity(0.15),
            border: Border.all(
              color: accentColor.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(icon, color: accentColor, size: 28),
              const SizedBox(width: 15),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Category Selection Section ---
  Widget _buildCategorySelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Choose Your Solo Quiz Category",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: FutureBuilder<List<CategoryData>>(
            future: _categoriesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error loading categories: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
              }

              final categories = snapshot.data ?? [];

              if (categories.isEmpty) {
                return const Center(child: Text('No categories found.', style: TextStyle(color: Colors.white70)));
              }

              return ListView.builder(
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final categoryId = category["id"]!;
                  final categoryName = category["name"]!;

                  final color = categoryColors[categoryName] ?? Colors.deepPurple;

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => navigateToQuiz(context, categoryId, categoryName),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.85,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: Colors.white.withOpacity(0.15),
                              border: Border.all(
                                color: color.withOpacity(0.5),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Text(
                              categoryName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}