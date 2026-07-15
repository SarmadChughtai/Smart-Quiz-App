import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/question_model.dart';
import 'dart:math'; // Required for random room ID

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Utility Functions ---

  String formatCategoryId(String id) {
    final parts = id.split('_');
    return parts.map((word) =>
    word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  User get currentUser {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User not logged in.");
    }
    return user;
  }

  String _generateRoomId() {
    const String chars = '0123456789';
    return List.generate(6, (index) => chars[DateTime.now().microsecondsSinceEpoch % chars.length]).join();
  }

  // --- 1. Fetching Category List ---

  Future<List<Map<String, String>>> getQuizCategories() async {
    try {
      final QuerySnapshot snapshot = await _firestore.collection('quizzes').get();
      final List<Map<String, String>> categories = snapshot.docs.map((doc) {
        final categoryId = doc.id;
        return {
          'id': categoryId,
          'name': formatCategoryId(categoryId),
        };
      }).toList();
      return categories;
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }

  // --- 2. Fetching Questions for a Category ---

  Future<List<Question>> getQuestions(String categoryId) async {
    try {
      final collectionRef = _firestore
          .collection('quizzes')
          .doc(categoryId)
          .collection('questions');

      final QuerySnapshot snapshot = await collectionRef.get();

      final List<Question> questions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Question.fromFirestore(data);
      }).toList();

      return questions;
    } catch (e) {
      print('Error fetching questions for $categoryId: $e');
      return [];
    }
  }

  // -----------------------------------------------------------------
  // --- 3. MULTIPLAYER ROOM MANAGEMENT ---
  // -----------------------------------------------------------------

  /// Creates a new room with a custom question bank and time limit.
  Future<String> createCustomRoom({
    required String roomName,
    required List<Map<String, dynamic>> questionBank,
    required int timeLimitSeconds,
    bool allowBack = true,         // Default true
    bool requireAllAnswers = true, // Default true
  }) async {
    final user = currentUser;
    final roomId = _generateRoomId();
    final roomRef = _firestore.collection('rooms').doc(roomId);

    final roomData = {
      'roomId': roomId,
      'roomName': roomName,
      'hostId': user.uid,
      'status': 'lobby',
      'createdAt': FieldValue.serverTimestamp(),
      'isCustom': true,
      'timeLimitSeconds': timeLimitSeconds,
      'questionBank': questionBank,

      // Settings
      'allowBack': allowBack,
      'requireAllAnswers': requireAllAnswers,

      'players': [],
    };

    await roomRef.set(roomData);
    return roomId;
  }

  /// Gets a real-time stream of a specific room document.
  Stream<DocumentSnapshot> getRoomStream({required String roomId}) {
    return _firestore.collection('rooms').doc(roomId).snapshots();
  }

  /// Host method to start the game (change status and fetch questions).
  Future<void> startGame({required String roomId, required String categoryId}) async {
    await _firestore.collection('rooms').doc(roomId).update({
      'status': 'in_game',
      'categoryId': categoryId,
      'gameStartedAt': FieldValue.serverTimestamp(),
    });
  }

  // Join Room Validation (Actual player add happens in UI for ID retrieval)
  Future<void> joinRoom({required String roomId}) async {
    final doc = await _firestore.collection('rooms').doc(roomId).get();
    if (!doc.exists) throw Exception("Room NOT_FOUND");
  }

  // -----------------------------------------------------------------
  // --- 4. HISTORY & ANALYTICS ---
  // -----------------------------------------------------------------

  // 🚨 NEW: Get list of rooms created by this host (for History Screen)
  Stream<QuerySnapshot> getHostHistoryStream(String hostId) {
    return _firestore
        .collection('rooms')
        .where('hostId', isEqualTo: hostId)
    // Note: To order by 'createdAt', you will need to create a Composite Index in Firebase Console.
    // For now, we filter by hostId and sort in the UI to avoid crashes.
        .snapshots();
  }

  // -----------------------------------------------------------------
  // --- 5. SCORE/GAME FINALIZATION METHODS ---
  // -----------------------------------------------------------------

  Future<void> submitScore({
    required String roomId,
    required int finalScore,
    required int correctCount,
    required int incorrectCount,
    required int skippedCount,
  }) async {
    // Logic handled directly in QuizScreen via subcollection updates
  }

  // -----------------------------------------------------------------
  // --- 6. USER PROFILE MANAGEMENT METHODS ---
  // -----------------------------------------------------------------

  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).set(data, SetOptions(merge: true));
    } catch (e) {
      print('Error updating user profile for $userId: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      print('Error fetching user profile for $userId: $e');
      return null;
    }
  }
}