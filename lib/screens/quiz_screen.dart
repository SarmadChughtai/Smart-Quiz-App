import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/question_model.dart';
import '../services/firestore_service.dart';
import 'result_screen.dart';
import 'home_screen.dart';

class QuizScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  final bool isCustomGame;
  final String? roomId;
  final String? playerId;
  final List<Question>? preloadedQuestions;
  final int timeLimitSeconds;

  // 🚨 NEW: Settings passed from Host
  final bool allowBack;
  final bool requireAllAnswers;

  const QuizScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.isCustomGame = false,
    this.roomId,
    this.playerId,
    this.preloadedQuestions,
    this.timeLimitSeconds = 1200,
    // Default settings (true for Solo, passed values for Live)
    this.allowBack = true,
    this.requireAllAnswers = false,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final FirestoreService _service = FirestoreService();
  List<Question> _questions = [];
  int currentQuestion = 0;
  int score = 0;
  int notAttempted = 0;
  bool _isAnswerRevealed = false;
  int totalTimeLeft = 1200;
  Timer? timer;

  // Stores indices: <QuestionIndex, OptionIndex>
  final Map<int, int?> userAnswers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    totalTimeLeft = widget.timeLimitSeconds;
    _loadData();
    startGlobalTimer();
  }

  void _loadData() async {
    if (widget.isCustomGame && widget.preloadedQuestions != null) {
      setState(() {
        _questions = widget.preloadedQuestions!;
        _isLoading = false;
      });
    } else {
      // Solo Mode
      final fetched = await _service.getQuestions(widget.categoryId);
      fetched.shuffle();
      setState(() {
        _questions = fetched.take(10).toList();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void startGlobalTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (totalTimeLeft > 0) {
        if (mounted) setState(() => totalTimeLeft--);
      } else {
        submitQuiz(timeUp: true);
      }
    });
  }

  String formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  void onOptionSelected(int optionIndex) {
    if (_isAnswerRevealed) return;

    setState(() {
      userAnswers[currentQuestion] = optionIndex;
      _isAnswerRevealed = true;
    });

    // Live Update to Host
    if (widget.roomId != null && widget.playerId != null) {
      List<int?> answersList = List.filled(_questions.length, null);
      userAnswers.forEach((k, v) {
        if (k < answersList.length) answersList[k] = v;
      });

      FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('players')
          .doc(widget.playerId)
          .update({'answers': answersList});
    }

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _isAnswerRevealed = false);
    });
  }

  // 🚨 NEW: Back Button Logic
  void goToPreviousQuestion() {
    if (currentQuestion > 0) {
      setState(() => currentQuestion--);
    }
  }

  void goToNextQuestion() {
    if (currentQuestion < _questions.length - 1) {
      setState(() => currentQuestion++);
    } else {
      _validateAndSubmit();
    }
  }

  // 🚨 NEW: Validation Logic before Submit
  void _validateAndSubmit() {
    if (widget.requireAllAnswers) {
      // Check if the user has answered every question
      bool allAnswered = true;
      for (int i = 0; i < _questions.length; i++) {
        if (!userAnswers.containsKey(i) || userAnswers[i] == null) {
          allAnswered = false;
          break;
        }
      }

      if (!allAnswered) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Host requires you to answer ALL questions before submitting."),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }
    _showSubmitConfirmationDialog();
  }

  void _showSubmitConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text("Submit Quiz?"),
        content: const Text("Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          TextButton(onPressed: () { Navigator.pop(c); submitQuiz(); }, child: const Text("Submit")),
        ],
      ),
    );
  }

  void submitQuiz({bool timeUp = false}) {
    timer?.cancel();
    score = 0;
    notAttempted = 0;
    int incorrectCount = 0;

    List<int?> answersList = List.filled(_questions.length, null);

    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final int? userIdx = userAnswers[i];
      answersList[i] = userIdx;

      if (userIdx == null) notAttempted++;
      else if (userIdx == q.correctAnswerIndex) score++;
      else incorrectCount++;
    }

    if (widget.roomId != null && widget.playerId != null) {
      FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('players')
          .doc(widget.playerId)
          .update({
        'score': score,
        'answers': answersList,
        'status': 'finished'
      });

      _service.submitScore(
        roomId: widget.roomId!,
        finalScore: score,
        correctCount: score,
        incorrectCount: incorrectCount,
        skippedCount: notAttempted,
      );
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          score: score,
          totalQuestions: _questions.length,
          notAttempted: notAttempted,
          categoryId: widget.categoryId,
          categoryName: widget.categoryName,
          questions: _questions,
          userAnswers: userAnswers,
          roomId: widget.roomId,
          playerId: widget.playerId,
          timeLimitSeconds: widget.timeLimitSeconds,
        ),
      ),
    );
  }

  Color _getOptionColor(int index, int? selectedIndex, int correctIndex) {
    if (!_isAnswerRevealed) return index == selectedIndex ? Colors.orange : Colors.blueAccent;
    if (index == correctIndex) return Colors.green;
    if (index == selectedIndex) return Colors.red;
    return Colors.blueAccent;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: Color(0xFF1E1E2C), body: Center(child: CircularProgressIndicator()));
    }
    if (_questions.isEmpty) {
      return const Scaffold(backgroundColor: Color(0xFF1E1E2C), body: Center(child: Text("No Questions", style: TextStyle(color: Colors.white))));
    }

    final q = _questions[currentQuestion];
    final selectedIdx = userAnswers[currentQuestion];
    // Allow next if option selected OR (if back nav allowed, allow skipping to next if already answered previously)
    final bool canProceed = selectedIdx != null && !_isAnswerRevealed;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: const Text("Quiz", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E1E2C),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Q${currentQuestion+1}/${_questions.length}", style: const TextStyle(color: Colors.white, fontSize: 18)),
                Text(formatTime(totalTimeLeft), style: const TextStyle(color: Colors.amber, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 30),
            Text(q.text, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 20),

            ...q.options.asMap().entries.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _getOptionColor(e.key, selectedIdx, q.correctAnswerIndex),
                        padding: const EdgeInsets.all(15)
                    ),
                    onPressed: !_isAnswerRevealed ? () => onOptionSelected(e.key) : null,
                    child: Text(e.value, style: const TextStyle(color: Colors.white)),
                  ),
                ),
              );
            }).toList(),

            const Spacer(),

            // 🚨 UPDATED NAVIGATION ROW
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Previous Button (Only if allowed by host and not on first question)
                if (widget.allowBack && currentQuestion > 0)
                  ElevatedButton.icon(
                    onPressed: goToPreviousQuestion,
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    label: const Text("Prev", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]),
                  )
                else
                  const SizedBox(), // Spacer if no button

                // Next/Submit Button
                ElevatedButton.icon(
                  // Allow next if an answer is selected OR if it's not the last question (skipping technically allowed unless locked logic enforced)
                  // For strict "requireAll", we validate at the END.
                  onPressed: canProceed || userAnswers.containsKey(currentQuestion) ? goToNextQuestion : null,
                  icon: Icon(currentQuestion == _questions.length - 1 ? Icons.check : Icons.arrow_forward, color: Colors.white),
                  label: Text(currentQuestion == _questions.length - 1 ? "Submit" : "Next", style: const TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: currentQuestion == _questions.length - 1 ? Colors.green : Colors.blueAccent
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}