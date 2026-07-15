// lib/models/question_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Question {
  final String id;
  String text;
  List<String> options;
  int correctAnswerIndex; // 0, 1, 2, or 3

  Question({
    this.id = '',
    required this.text,
    required this.options,
    required this.correctAnswerIndex,
  });

  // Backward compatibility for old code using .question or .answer
  String get question => text;
  String get answer => options.isNotEmpty && correctAnswerIndex < options.length
      ? options[correctAnswerIndex]
      : '';

  // 1. UPLOAD
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
    };
  }

  // 2. DOWNLOAD (Live Quiz)
  factory Question.fromMap(Map<String, dynamic> map) {
    String qText = map['text'] ?? map['question'] ?? '';
    List<String> opts = List<String>.from(map['options'] ?? []);
    int correctIdx = map['correctAnswerIndex'] ?? 0;

    // Fallback for old data using String answers
    if (!map.containsKey('correctAnswerIndex') && map.containsKey('answer')) {
      correctIdx = opts.indexOf(map['answer']);
      if (correctIdx == -1) correctIdx = 0;
    }

    return Question(
      id: map['id'] ?? '',
      text: qText,
      options: opts,
      correctAnswerIndex: correctIdx,
    );
  }

  // 3. FIRESTORE FACTORY
  factory Question.fromFirestore(Map<String, dynamic> data) {
    return Question.fromMap(data);
  }
}