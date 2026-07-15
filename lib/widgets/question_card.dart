import 'package:flutter/material.dart';
import 'custom_button.dart';

class QuestionCard extends StatelessWidget {
  final String question;
  final List<String> options;
  final Function(String) onSelect;
  final String? selectedOption;
  final String correctAnswer;

  const QuestionCard({
    required this.question,
    required this.options,
    required this.onSelect,
    required this.selectedOption,
    required this.correctAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          question,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white, // ✅ Question text white
          ),
        ),
        const SizedBox(height: 20),

        ...options.map((option) {
          bool isSelected = selectedOption == option;
          bool isCorrect = option == correctAnswer;
          bool isWrong = isSelected && option != correctAnswer;

          Color btnColor = Colors.blue; // Default color
          if (isCorrect && selectedOption != null) btnColor = Colors.green;
          if (isWrong) btnColor = Colors.red;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: CustomButton(
              text: option,
              color: btnColor,
              textColor: Colors.white, // ✅ Option text color white
              onPressed: () => onSelect(option),
            ),
          );
        }).toList(),
      ],
    );
  }
}
