import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/question_model.dart';
import '../services/firestore_service.dart'; // 1. Import Service
import 'RoomLobbyScreen.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final TextEditingController _roomIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _sapIdController = TextEditingController();

  final FirestoreService _service = FirestoreService(); // 2. Initialize Service

  bool _isLoading = false;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData(); // 3. Call function to fetch data on startup
  }

  // --- 4. NEW: Fetch SAP ID & Name from Firestore ---
  Future<void> _loadUserData() async {
    if (currentUser == null) return;

    // 1. Set default name from Auth (immediate)
    if (currentUser?.displayName != null) {
      _nameController.text = currentUser!.displayName!;
    }

    try {
      // 2. Fetch full profile from Firestore to get SAP ID
      final userData = await _service.getUserProfile(currentUser!.uid);

      if (userData != null && mounted) {
        setState(() {
          // Auto-fill SAP ID
          _sapIdController.text = userData['sapId'] as String? ?? '';

          // If Firestore has a display name, prefer it over Auth name
          if (userData['displayName'] != null) {
            _nameController.text = userData['displayName'] as String;
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
    }
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    _nameController.dispose();
    _sapIdController.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    final roomId = _roomIdController.text.trim();
    final name = _nameController.text.trim();
    final sapId = _sapIdController.text.trim();

    // Validate all fields
    if (roomId.isEmpty || name.isEmpty || sapId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter Room ID, Name, and SAP ID")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // A. Check if Room Exists
      DocumentSnapshot roomSnap = await FirebaseFirestore.instance.collection('rooms').doc(roomId).get();

      if (!roomSnap.exists) throw "Room not found.";

      Map<String, dynamic> data = roomSnap.data() as Map<String, dynamic>;

      if (data['status'] != 'waiting') throw "Quiz has already started or finished.";

      // B. Create Player Doc (Include SAP ID)
      DocumentReference playerRef = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('players')
          .add({
        'name': name,
        'sapId': sapId, // Saved to the room player list
        'score': 0,
        'answers': [],
        'joinedAt': FieldValue.serverTimestamp(),
        'status': 'joined',
        'retakeStatus': 'none',
        'uid': currentUser?.uid ?? '',
      });

      // C. Load Questions
      List<dynamic> qList = data['questionBank'] ?? data['questions'] ?? [];

      if (qList.isEmpty) throw "Error: No questions found in this room.";

      List<Question> questions = qList.map((q) => Question.fromMap(q)).toList();
      int timer = (data['timeLimitSeconds'] as num?)?.toInt() ?? 1200;

      // D. Navigate
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RoomLobbyScreen(
              roomId: roomId,
              playerId: playerRef.id,
              questions: questions,
              timerPerQuestion: timer,
            ),
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Widget _buildGlassyTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.15),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 10.0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(title: const Text("Join Live Quiz"), backgroundColor: const Color(0xFF1E1E2C), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text("Student Details", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),

            const SizedBox(height: 30),
            const Text("Room ID", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            _buildGlassyTextField(controller: _roomIdController, hintText: "6-digit code", icon: Icons.vpn_key, keyboardType: TextInputType.number),

            const SizedBox(height: 20),
            const Text("Full Name", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            _buildGlassyTextField(controller: _nameController, hintText: "Your full name", icon: Icons.person),

            // 5. SAP ID Input Field (Auto-filled if available)
            const SizedBox(height: 20),
            const Text("SAP ID", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            _buildGlassyTextField(controller: _sapIdController, hintText: "Enter SAP ID", icon: Icons.badge, keyboardType: TextInputType.number),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _joinRoom,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("JOIN ROOM", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}