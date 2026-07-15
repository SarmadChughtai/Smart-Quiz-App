import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'HistoryDetailScreen.dart'; // We create this next

class HostHistoryScreen extends StatelessWidget {
  const HostHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirestoreService service = FirestoreService();
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: const Text("Quiz History", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E2C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: service.getHostHistoryStream(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No past quizzes found.", style: TextStyle(color: Colors.white54, fontSize: 16)),
            );
          }

          // 1. Filter for 'finished' games locally
          var docs = snapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return data['status'] == 'finished';
          }).toList();

          // 2. Sort by date (Newest first)
          docs.sort((a, b) {
            Timestamp t1 = (a.data() as Map)['createdAt'] ?? Timestamp.now();
            Timestamp t2 = (b.data() as Map)['createdAt'] ?? Timestamp.now();
            return t2.compareTo(t1);
          });

          if (docs.isEmpty) {
            return const Center(child: Text("No finished quizzes yet.", style: TextStyle(color: Colors.white54)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String roomName = data['roomName'] ?? 'Unnamed Quiz';
              String roomId = data['roomId'] ?? '???';
              Timestamp? timestamp = data['createdAt'];

              // Simple Date Format
              String dateStr = "Unknown Date";
              if (timestamp != null) {
                DateTime d = timestamp.toDate();
                dateStr = "${d.day}/${d.month}/${d.year}  ${d.hour}:${d.minute.toString().padLeft(2,'0')}";
              }

              return Card(
                color: Colors.white10,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  title: Text(roomName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text("Room ID: $roomId", style: const TextStyle(color: Colors.orangeAccent)),
                      Text(dateStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HistoryDetailScreen(roomId: roomId, roomName: roomName),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}