// lib/screens/RoomLobbyScreen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/question_model.dart';
import 'quiz_screen.dart';
import 'HostMonitorScreen.dart'; // Ensure this file exists

class RoomLobbyScreen extends StatefulWidget {
  final String roomId;

  // 🚨 FIXED: Added these optional parameters to match JoinRoomScreen calls
  final String? playerId;
  final List<Question>? questions;
  final int? timerPerQuestion;

  const RoomLobbyScreen({
    super.key,
    required this.roomId,
    this.playerId,
    this.questions,
    this.timerPerQuestion,
  });

  @override
  State<RoomLobbyScreen> createState() => _RoomLobbyScreenState();
}

class _RoomLobbyScreenState extends State<RoomLobbyScreen> {
  final FirestoreService _service = FirestoreService();
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // Prevents multiple navigation events
  bool hasTriggeredNavigation = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: const Text("Quiz Lobby",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E2C),
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: !hasTriggeredNavigation, // Hide back button if game starting
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _service.getRoomStream(roomId: widget.roomId),
        builder: (context, snapshot) {
          // 1. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          }

          // 2. Error or Deleted Room State
          if (snapshot.hasError || !snapshot.hasData || snapshot.data?.data() == null) {
            return const Center(
                child: Text("Room no longer exists.", style: TextStyle(color: Colors.red)));
          }

          final Map<String, dynamic> roomData = snapshot.data!.data() as Map<String, dynamic>;

          final String status = roomData['status'] as String? ?? 'lobby';
          final List<Map<String, dynamic>> players = List<Map<String, dynamic>>.from(roomData['players'] ?? []);
          final String hostId = roomData['hostId'] as String? ?? '';
          final bool isHost = currentUserId == hostId;

          // ---------------------------------------------------
          // 3. GAME STARTED LOGIC (Navigation)
          // ---------------------------------------------------
          if (status == 'in_game') {
            if (!hasTriggeredNavigation) {
              hasTriggeredNavigation = true; // Lock navigation

              // Extract necessary data for Quiz Screen
              final String categoryId = roomData['categoryId'] as String? ?? '';
              final String categoryName = roomData['categoryName'] as String? ?? 'Quiz';
              final bool isCustom = roomData['isCustom'] as bool? ?? false;

              // Determine questions source: passed in via widget (Student) or roomData (Host fallback)
              List<Question> gameQuestions = widget.questions ?? [];
              if (gameQuestions.isEmpty && roomData['questionBank'] != null) {
                gameQuestions = (roomData['questionBank'] as List)
                    .map((q) => Question.fromMap(q))
                    .toList();
              }

              // Determine timer
              int timer = widget.timerPerQuestion ?? (roomData['timeLimitSeconds'] as int? ?? 1200);

              // Schedule navigation for the next frame
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => isHost
                        ? HostMonitorScreen(roomId: widget.roomId) // Host view
                        : QuizScreen( // Player view
                      roomId: widget.roomId,
                      playerId: widget.playerId, // 🚨 Pass player ID to update score
                      categoryId: categoryId,
                      categoryName: categoryName,
                      isCustomGame: isCustom,
                      preloadedQuestions: gameQuestions, // 🚨 Pass questions to QuizScreen
                      timeLimitSeconds: timer, // 🚨 Pass timer to QuizScreen
                    ),
                  ),
                );
              });
            }

            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.greenAccent),
                  SizedBox(height: 20),
                  Text("Game Starting...", style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            );
          }

          // ---------------------------------------------------
          // 4. LOBBY UI
          // ---------------------------------------------------
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderCard(roomData),
                const SizedBox(height: 30),
                _buildPlayerList(players, hostId),
                const SizedBox(height: 40),
                if (isHost)
                  _buildStartButton(players.length, roomData),
                if (!isHost)
                  const Center(
                    child: Text(
                      "Waiting for Host to start...",
                      style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
                    ),
                  )
              ],
            ),
          );
        },
      ),
    );
  }

  // --- UI WIDGETS ---

  Widget _buildHeaderCard(Map<String, dynamic> roomData) {
    final int questionCount = roomData['numQuestions'] as int? ??
        (roomData['questionBank'] is List ? (roomData['questionBank'] as List).length : 0);

    final int timeLimit = roomData['timeLimitSeconds'] as int? ?? 60;
    final String roomName = roomData['roomName'] ?? 'Quiz Room';
    final String roomIdDisplay = roomData['roomId'] ?? 'N/A';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(roomName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 10),
          Text("Questions: $questionCount", style: const TextStyle(color: Colors.white70)),
          Text("Time Limit: ${timeLimit ~/ 60} min", style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("ROOM CODE:",
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.bold)),
              SelectableText(
                roomIdDisplay,
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerList(List<Map<String, dynamic>> players, String hostId) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Players Joined (${players.length})",
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(color: Colors.white30, height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];
                final bool isHostPlayer = (player['uid'] == hostId);

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: isHostPlayer ? Colors.amber : Colors.blueGrey,
                    child: Icon(isHostPlayer ? Icons.star : Icons.person, color: Colors.white, size: 20),
                  ),
                  title: Text(
                    player['name'] ?? 'Unknown',
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: Text(
                    isHostPlayer ? "HOST" : "READY",
                    style: TextStyle(
                        color: isHostPlayer ? Colors.amberAccent : Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(int playerCount, Map<String, dynamic> roomData) {
    // Allow start if there is at least 1 player (Host can play alone to test)
    bool canStart = playerCount > 0;

    return ElevatedButton(
      onPressed: canStart ? () => _handleStartGame(roomData) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: canStart ? const Color(0xFF4CAF50) : Colors.grey,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 5,
      ),
      child: Text(
        canStart ? "START QUIZ NOW" : "Waiting for players...",
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _handleStartGame(Map<String, dynamic> roomData) async {
    final bool isCustom = roomData['isCustom'] as bool? ?? false;
    final String categoryId = roomData['categoryId'] as String? ?? '';

    // If Custom Room -> pass empty categoryId (so backend uses custom questions)
    // If Normal Room -> pass the actual categoryId
    await _service.startGame(
      roomId: widget.roomId,
      categoryId: isCustom ? '' : categoryId,
    );
  }
}