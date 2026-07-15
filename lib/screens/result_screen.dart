import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'quiz_screen.dart';
import '../models/question_model.dart';

class ResultScreen extends StatefulWidget {
  final int score;
  final int totalQuestions;
  final int notAttempted;
  final String categoryId;
  final String categoryName;
  final List<Question> questions;
  final Map<int, int?> userAnswers;
  final String? roomId;
  final String? playerId;
  final int timeLimitSeconds; // Added to persist timer on retake

  const ResultScreen({
    super.key,
    required this.score,
    required this.totalQuestions,
    required this.notAttempted,
    required this.categoryId,
    required this.categoryName,
    required this.questions,
    required this.userAnswers,
    this.roomId,
    this.playerId,
    this.timeLimitSeconds = 1200,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  // Request Retake
  void _requestRetake() {
    if (widget.roomId != null && widget.playerId != null) {
      FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('players')
          .doc(widget.playerId)
          .update({'retakeStatus': 'pending'});
    }
  }

  // Review Answers
  void _showReview() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        expand: false,
        builder: (_, controller) => ListView.builder(
          controller: controller,
          padding: const EdgeInsets.all(20),
          itemCount: widget.questions.length,
          itemBuilder: (context, index) {
            final q = widget.questions[index];
            final int? userIdx = widget.userAnswers[index];
            final bool isCorrect = userIdx == q.correctAnswerIndex;
            return Card(
              color: isCorrect ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              child: ListTile(
                title: Text("Q${index+1}: ${q.text}", style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  isCorrect
                      ? "Correct Answer: ${q.options[q.correctAnswerIndex]}"
                      : "Your Answer: ${userIdx != null ? q.options[userIdx] : 'Skipped'}",
                  style: TextStyle(color: isCorrect ? Colors.greenAccent : Colors.redAccent),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.roomId == null) return _buildUI(null);

    // Listen for Host Approval
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('players').doc(widget.playerId).snapshots(),
      builder: (context, snapshot) {
        String status = 'none';
        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>;
          status = data['retakeStatus'] ?? 'none';

          if (status == 'approved') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => QuizScreen(
                    categoryId: widget.categoryId,
                    categoryName: widget.categoryName,
                    isCustomGame: true,
                    roomId: widget.roomId,
                    preloadedQuestions: widget.questions,
                    timeLimitSeconds: widget.timeLimitSeconds,
                  ))
              );
            });
          }
        }
        return _buildUI(status);
      },
    );
  }

  Widget _buildUI(String? retakeStatus) {
    bool isPending = retakeStatus == 'pending';
    bool isRejected = retakeStatus == 'rejected';
    bool isMultiplayer = widget.roomId != null;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(title: const Text("Results"), backgroundColor: Colors.transparent, elevation: 0, automaticallyImplyLeading: false),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("${widget.score} / ${widget.totalQuestions}", style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            const Text("Final Score", style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: _showReview,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, minimumSize: const Size(200, 50)),
              child: const Text("Review Answers"),
            ),
            const SizedBox(height: 20),

            // Logic for Retake Button
            if (isMultiplayer) ...[
              if (isPending)
                const Chip(
                  label: Text("Waiting for Host...", style: TextStyle(color: Colors.white)),
                  backgroundColor: Colors.orange,
                  avatar: Padding(padding: EdgeInsets.all(4), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                )
              else if (isRejected)
                const Chip(
                  label: Text("Retake Denied", style: TextStyle(color: Colors.white)),
                  backgroundColor: Colors.red,
                  avatar: Icon(Icons.block, color: Colors.white, size: 18),
                )
              else
                ElevatedButton(
                  onPressed: _requestRetake,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, minimumSize: const Size(200, 50)),
                  child: const Text("Request Retake"),
                ),
            ] else ...[
              // Solo Retake
              ElevatedButton(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => QuizScreen(categoryId: widget.categoryId, categoryName: widget.categoryName))),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, minimumSize: const Size(200, 50)),
                child: const Text("Retake Quiz"),
              ),
            ],

            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false),
              child: const Text("Go Home", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}