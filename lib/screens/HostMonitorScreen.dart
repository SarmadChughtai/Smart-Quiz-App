import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../models/question_model.dart';
import 'home_screen.dart';

class HostMonitorScreen extends StatefulWidget {
  final String roomId;
  const HostMonitorScreen({super.key, required this.roomId});

  @override
  State<HostMonitorScreen> createState() => _HostMonitorScreenState();
}

class _HostMonitorScreenState extends State<HostMonitorScreen> {
  final FirestoreService _service = FirestoreService();
  List<Question> _questions = [];
  bool _isLoadingQuestions = true;
  int _previousPendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

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
      debugPrint("Error loading questions: $e");
    }
  }

  void _handleRetake(String playerId, bool approve) {
    FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('players').doc(playerId)
        .update({
      'retakeStatus': approve ? 'approved' : 'rejected',
      if (approve) ...{'score': 0, 'answers': [], 'status': 'playing'}
    });
  }

  Future<void> _endQuiz() async {
    await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({'status': 'finished'});
    if(mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
  }

  // --- NOTIFICATION PANEL ---
  void _showNotifications(List<QueryDocumentSnapshot> requests) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Retake Requests", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (requests.isEmpty) const Text("No pending requests.", style: TextStyle(color: Colors.white54)),

            ...requests.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              return Card(
                color: Colors.white10,
                child: ListTile(
                  leading: const Icon(Icons.refresh, color: Colors.orange),
                  title: Text(data['name'] ?? 'Unknown', style: const TextStyle(color: Colors.white)),
                  subtitle: const Text("Wants to try again", style: TextStyle(color: Colors.grey)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () { _handleRetake(doc.id, true); Navigator.pop(context); }),
                      IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () { _handleRetake(doc.id, false); Navigator.pop(context); }),
                    ],
                  ),
                ),
              );
            }).toList()
          ],
        ),
      ),
    );
  }

  // --- DETAILED REPORT CARD ---
  void _showReportCard(Map<String, dynamic> data) {
    List<dynamic> rawAnswers = data['answers'] ?? [];
    List<int?> userAnswers = rawAnswers.map((e) => e as int?).toList();
    String name = data['name'] ?? 'Student';

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("$name's Performance", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white24),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    final q = _questions[index];
                    final int? userIdx = (index < userAnswers.length) ? userAnswers[index] : null;

                    final bool isCorrect = userIdx == q.correctAnswerIndex;
                    final bool notReached = index >= userAnswers.length;
                    final bool isSkipped = userIdx == null && !notReached;

                    Color cardColor = Colors.white10;
                    IconData icon = Icons.hourglass_empty;
                    Color color = Colors.grey;

                    if (!notReached) {
                      if (isCorrect) { cardColor = Colors.green.withOpacity(0.1); icon = Icons.check_circle; color = Colors.green; }
                      else if (isSkipped) { cardColor = Colors.orange.withOpacity(0.1); icon = Icons.help; color = Colors.orange; }
                      else { cardColor = Colors.red.withOpacity(0.1); icon = Icons.cancel; color = Colors.red; }
                    }

                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(icon, color: color),
                        title: Text("Q${index+1}: ${q.text}", style: const TextStyle(color: Colors.white)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!notReached && !isCorrect && !isSkipped)
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
    if (_isLoadingQuestions) return const Scaffold(backgroundColor: Color(0xFF1E1E2C), body: Center(child: CircularProgressIndicator()));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('players').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(backgroundColor: Color(0xFF1E1E2C), body: Center(child: CircularProgressIndicator()));

        var players = snapshot.data!.docs;
        var pending = players.where((d) => (d.data() as Map)['retakeStatus'] == 'pending').toList();

        if (pending.length > _previousPendingCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("${pending.length} Retake Request(s)!"),
              backgroundColor: Colors.orange,
              action: SnackBarAction(label: "VIEW", textColor: Colors.white, onPressed: () => _showNotifications(pending)),
            ));
          });
        }
        _previousPendingCount = pending.length;

        return Scaffold(
          backgroundColor: const Color(0xFF1E1E2C),
          appBar: AppBar(
            title: const Text("Host Monitor", style: TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF1E1E2C),
            automaticallyImplyLeading: false,
            actions: [
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(icon: const Icon(Icons.notifications, color: Colors.white), onPressed: () => _showNotifications(pending)),
                  if (pending.isNotEmpty)
                    Positioned(right: 8, top: 8, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text("${pending.length}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
                ],
              ),
              const SizedBox(width: 15),
            ],
          ),
          body: Column(
            children: [
              // 🚨 LIVE PLAYER COUNT HEADER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.black26,
                child: Text(
                  "Active Players: ${players.length}",
                  style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),

              // 🚨 PLAYER LIST (Shows everyone)
              Expanded(
                child: players.isEmpty
                    ? const Center(child: Text("Waiting for players to join...", style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    var doc = players[index];
                    var data = doc.data() as Map<String, dynamic>;

                    String name = data['name'] ?? 'Unknown';
                    int score = data['score'] ?? 0;
                    String status = data['status'] ?? 'joined';
                    String retakeStatus = data['retakeStatus'] ?? 'none';
                    List ans = data['answers'] ?? [];

                    bool finished = status == 'finished';
                    bool requesting = retakeStatus == 'pending';

                    // Determine Status Icon & Color
                    Color statusColor = Colors.blue;
                    IconData statusIcon = Icons.person;
                    String statusText = "Ready";

                    if (requesting) {
                      statusColor = Colors.orange;
                      statusIcon = Icons.notification_important;
                      statusText = "Requesting Retake";
                    } else if (finished) {
                      statusColor = Colors.green;
                      statusIcon = Icons.check_circle;
                      statusText = "Score: $score";
                    } else if (ans.isNotEmpty) {
                      statusColor = Colors.blueAccent;
                      statusIcon = Icons.play_circle_fill;
                      statusText = "Progress: ${ans.length}/${_questions.length}";
                    }

                    return Card(
                      color: Colors.white10,
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: statusColor, child: Icon(statusIcon, color: Colors.white)),
                        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(statusText, style: TextStyle(color: statusColor.withOpacity(0.8))),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
                        onTap: () {
                          if (requesting) _showNotifications(pending);
                          else _showReportCard(data);
                        },
                      ),
                    );
                  },
                ),
              ),

              // End Quiz Button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: _endQuiz, child: const Text("END QUIZ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
              )
            ],
          ),
        );
      },
    );
  }
}