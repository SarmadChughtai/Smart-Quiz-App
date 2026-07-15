import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/question_model.dart';

class HistoryDetailScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  const HistoryDetailScreen({super.key, required this.roomId, required this.roomName});

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  List<Question> _questions = [];
  bool _isLoadingQuestions = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  // 1. Load Questions for this specific historical room
  Future<void> _loadQuestions() async {
    try {
      DocumentSnapshot roomSnap = await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).get();
      if (roomSnap.exists) {
        Map<String, dynamic> data = roomSnap.data() as Map<String, dynamic>;
        List<dynamic> qList = data['questionBank'] ?? data['questions'] ?? [];

        setState(() {
          _questions = qList.map((q) => Question.fromMap(q)).toList();
          _isLoadingQuestions = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading history questions: $e");
      setState(() => _isLoadingQuestions = false);
    }
  }

  // 2. Show Detailed Report (Reused Logic)
  void _showStudentReport(BuildContext context, Map<String, dynamic> studentData) {
    List<dynamic> rawAnswers = studentData['answers'] ?? [];
    List<int?> userAnswers = rawAnswers.map((e) => e as int?).toList();
    String name = studentData['name'] ?? 'Student';
    int score = studentData['score'] ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text("$name's Report", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              Text("Final Score: $score / ${_questions.length}", style: const TextStyle(color: Colors.blueAccent, fontSize: 16)),
              const Divider(color: Colors.white24, height: 30),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    final q = _questions[index];
                    final int? userIdx = (index < userAnswers.length) ? userAnswers[index] : null;

                    final bool isCorrect = userIdx == q.correctAnswerIndex;
                    final bool isSkipped = userIdx == null;

                    Color color = isCorrect ? Colors.green : Colors.red;
                    if (isSkipped) color = Colors.grey;

                    return Card(
                      color: color.withOpacity(0.1),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Icon(
                          isCorrect ? Icons.check_circle : (isSkipped ? Icons.help : Icons.cancel),
                          color: color,
                        ),
                        title: Text("Q${index+1}: ${q.text}", style: const TextStyle(color: Colors.white)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isCorrect && !isSkipped)
                              Text("Selected: ${q.options[userIdx!]}", style: const TextStyle(color: Colors.redAccent)),
                            Text("Correct: ${q.options[q.correctAnswerIndex]}", style: const TextStyle(color: Colors.greenAccent)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: Text(widget.roomName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E2C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingQuestions
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
        // Fetch players for this room
        stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('players').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var players = snapshot.data!.docs;

          if (players.isEmpty) return const Center(child: Text("No players found.", style: TextStyle(color: Colors.white54)));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: players.length,
            itemBuilder: (context, index) {
              var data = players[index].data() as Map<String, dynamic>;
              String name = data['name'] ?? 'Unknown';
              String sapId = data['sapId'] ?? 'N/A';
              int score = data['score'] ?? 0;

              return Card(
                color: Colors.white10,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueGrey,
                    child: Text("${index+1}", style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text("SAP ID: $sapId", style: const TextStyle(color: Colors.white54)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blueAccent)
                    ),
                    child: Text("$score/${_questions.length}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  onTap: () => _showStudentReport(context, data),
                ),
              );
            },
          );
        },
      ),
    );
  }
}