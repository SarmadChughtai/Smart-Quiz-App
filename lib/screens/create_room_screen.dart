import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'RoomLobbyScreen.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final FirestoreService _service = FirestoreService();
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _timeLimitController = TextEditingController(text: '5');
  bool _isLoading = false;

  // --- New Settings State ---
  bool _allowBackNavigation = true; // User can go back to previous questions
  bool _requireAllAnswers = true;   // User must answer all to submit

  // --- State for Custom Questions ---
  // Structure: {
  //   'text': TextEditingController,
  //   'options': List<TextEditingController>,
  //   'correctOptionIndex': int?
  // }
  List<Map<String, dynamic>> _customQuestions = [];

  @override
  void initState() {
    super.initState();
    _addQuestionField(); // Start with 1 question
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _timeLimitController.dispose();
    for (var qMap in _customQuestions) {
      (qMap['text'] as TextEditingController).dispose();
      for (var controller in (qMap['options'] as List<TextEditingController>)) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  // --- Question Management ---

  void _addQuestionField() {
    setState(() {
      _customQuestions.add({
        'text': TextEditingController(),
        // Start with 2 empty options by default
        'options': [TextEditingController(), TextEditingController()],
        'correctOptionIndex': null,
      });
    });
  }

  void _removeQuestionField(int index) {
    if (_customQuestions.length > 1) {
      (_customQuestions[index]['text'] as TextEditingController).dispose();
      for (var controller in (_customQuestions[index]['options'] as List<TextEditingController>)) {
        controller.dispose();
      }
      setState(() {
        _customQuestions.removeAt(index);
      });
    } else {
      _showSnackbar("You must have at least one question.", Colors.redAccent);
    }
  }

  // --- Option Management (New Feature) ---

  void _addOptionToQuestion(int questionIndex) {
    setState(() {
      (_customQuestions[questionIndex]['options'] as List<TextEditingController>).add(TextEditingController());
    });
  }

  void _removeOptionFromQuestion(int questionIndex, int optionIndex) {
    List<TextEditingController> options = _customQuestions[questionIndex]['options'];
    if (options.length > 2) {
      // Handle Logic: If we remove the option that was the correct answer
      int? currentIndex = _customQuestions[questionIndex]['correctOptionIndex'];

      if (currentIndex == optionIndex) {
        // We deleted the correct answer, reset selection
        _customQuestions[questionIndex]['correctOptionIndex'] = null;
      } else if (currentIndex != null && optionIndex < currentIndex) {
        // We deleted an option above the correct one, shift index down
        _customQuestions[questionIndex]['correctOptionIndex'] = currentIndex - 1;
      }

      options[optionIndex].dispose();
      setState(() {
        options.removeAt(optionIndex);
      });
    } else {
      _showSnackbar("A question must have at least 2 options.", Colors.orange);
    }
  }

  // --- Core Logic: Create Room ---
  Future<void> _createRoom() async {
    final roomName = _roomNameController.text.trim();
    final timeLimitMinutes = int.tryParse(_timeLimitController.text.trim()) ?? 0;

    if (roomName.isEmpty || timeLimitMinutes <= 0) {
      _showSnackbar("Please enter a room name and valid time limit.", Colors.redAccent);
      return;
    }

    final List<Map<String, dynamic>> finalQuestionBank = [];

    for (int i = 0; i < _customQuestions.length; i++) {
      var qMap = _customQuestions[i];
      final questionText = (qMap['text'] as TextEditingController).text.trim();
      final List<TextEditingController> optionControllers = qMap['options'];
      final int? correctIndex = qMap['correctOptionIndex'];

      if (questionText.isEmpty) {
        _showSnackbar("Question ${i + 1} is missing text.", Colors.redAccent);
        return;
      }

      List<String> optionStrings = optionControllers.map((c) => c.text.trim()).toList();
      if (optionStrings.any((o) => o.isEmpty)) {
        _showSnackbar("All options in Question ${i + 1} must be filled.", Colors.redAccent);
        return;
      }

      if (correctIndex == null) {
        _showSnackbar("Select a correct answer for Question ${i + 1}.", Colors.redAccent);
        return;
      }

      finalQuestionBank.add({
        'text': questionText,
        'options': optionStrings,
        'correctAnswerIndex': correctIndex, // Storing Index
        'answer': optionStrings[correctIndex], // Storing Text as backup
      });
    }

    setState(() => _isLoading = true);

    try {
      // Pass new settings to FirestoreService
      // NOTE: You might need to update your FirestoreService 'createCustomRoom' method
      // to accept 'allowBack' and 'requireAllAnswers' and save them to the room document.
      final String roomId = await _service.createCustomRoom(
        roomName: roomName,
        questionBank: finalQuestionBank,
        timeLimitSeconds: timeLimitMinutes * 60,
        allowBack: _allowBackNavigation, // Passing New Setting
        requireAllAnswers: _requireAllAnswers, // Passing New Setting
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => RoomLobbyScreen(roomId: roomId)),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Error: ${e.toString()}', Colors.red);
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Custom Room", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E2C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFF1E1E2C),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // --- Room Details ---
            const Text("Room Settings", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            _buildGlassyTextField(controller: _roomNameController, hintText: "Room Name", icon: Icons.meeting_room),
            const SizedBox(height: 15),
            _buildGlassyTextField(controller: _timeLimitController, hintText: "Time Limit (Minutes)", icon: Icons.timer, keyboardType: TextInputType.number),

            const SizedBox(height: 20),

            // --- NEW: Quiz Rules Switches ---
            Container(
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text("Allow Going Back", style: TextStyle(color: Colors.white)),
                    subtitle: const Text("Users can change previous answers", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    value: _allowBackNavigation,
                    activeColor: Colors.greenAccent,
                    onChanged: (val) => setState(() => _allowBackNavigation = val),
                  ),
                  Divider(color: Colors.white24, height: 1),
                  SwitchListTile(
                    title: const Text("Require All Answers", style: TextStyle(color: Colors.white)),
                    subtitle: const Text("User cannot submit until all attempted", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    value: _requireAllAnswers,
                    activeColor: Colors.greenAccent,
                    onChanged: (val) => setState(() => _requireAllAnswers = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- Questions Header ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Questions (${_customQuestions.length})", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.add_circle, color: Colors.greenAccent), onPressed: _addQuestionField),
              ],
            ),
            const SizedBox(height: 10),

            // --- Questions List ---
            ..._customQuestions.asMap().entries.map((entry) {
              return _buildQuestionEditor(entry.key, entry.value);
            }).toList(),

            const SizedBox(height: 50),

            // --- Create Button ---
            Center(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createRoom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : const Text("Create Room", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widget Builders ---

  Widget _buildQuestionEditor(int index, Map<String, dynamic> qMap) {
    List<TextEditingController> options = qMap['options'];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Question ${index + 1}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _removeQuestionField(index)),
            ],
          ),
          const SizedBox(height: 10),

          // Question Text
          _buildInnerTextField(qMap['text'], hintText: "Enter question text", icon: Icons.question_mark),
          const SizedBox(height: 15),
          const Text("Options (Select Correct Answer):", style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 5),

          // Options List (Dynamic)
          ...options.asMap().entries.map((optionEntry) {
            int optIdx = optionEntry.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  // Radio
                  Transform.scale(
                    scale: 1.2,
                    child: Radio<int>(
                      value: optIdx,
                      groupValue: qMap['correctOptionIndex'],
                      onChanged: (val) => setState(() => qMap['correctOptionIndex'] = val),
                      activeColor: Colors.greenAccent,
                      fillColor: MaterialStateProperty.resolveWith((states) => states.contains(MaterialState.selected) ? Colors.greenAccent : Colors.white54),
                    ),
                  ),
                  // Input
                  Expanded(
                    child: _buildInnerTextField(optionEntry.value, hintText: "Option ${optIdx + 1}", icon: Icons.edit),
                  ),
                  // Delete Option Button (Only if more than 2 options)
                  if (options.length > 2)
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                      onPressed: () => _removeOptionFromQuestion(index, optIdx),
                    ),
                ],
              ),
            );
          }).toList(),

          // Add Option Button
          Center(
            child: TextButton.icon(
              onPressed: () => _addOptionToQuestion(index),
              icon: const Icon(Icons.add, color: Colors.blueAccent),
              label: const Text("Add Option", style: TextStyle(color: Colors.blueAccent)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassyTextField({required TextEditingController controller, required String hintText, required IconData icon, TextInputType keyboardType = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14), color: Colors.white.withOpacity(0.15),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hintText, hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 10.0),
        ),
      ),
    );
  }

  Widget _buildInnerTextField(TextEditingController controller, {required String hintText, required IconData icon}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10), color: Colors.black.withOpacity(0.3),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hintText, hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.blueGrey, size: 18),
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
        ),
      ),
    );
  }
}