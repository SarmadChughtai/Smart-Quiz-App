# Smart Quiz App 🧠

A real-time, multiplayer quiz application built with Flutter and Firebase. Hosts can create custom quiz rooms with their own question banks, invite players via a room code, and monitor live progress — while players compete, answer questions against the clock, and view detailed results.

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.9-02569B?logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Firebase-Firestore%20%7C%20Auth%20%7C%20Storage-FFCA28?logo=firebase&logoColor=black" alt="Firebase">
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-3DDC84?logo=android&logoColor=white" alt="Platform">
  <img src="https://img.shields.io/badge/Realtime-Firestore%20Streams-orange" alt="Realtime">
</p>

---

## ✨ Features

### 🔐 Authentication
- Email/password sign-up and login
- Google Sign-In integration
- "Remember Me" persistent sessions
- Editable user profiles with education, experience, and profile picture (Firebase Storage)

### 🎮 Multiplayer Quiz Rooms
- **Host a Room** — Create a room with a custom question bank, configurable time limit, and rules (allow going back, require all answers before submit)
- **Join a Room** — Join any active room using a 6-digit room code
- **Live Lobby** — Real-time player list synced via Firestore streams before the game starts
- **Host Monitor** — Hosts can watch player progress live as the quiz is in progress

### 📝 Quiz Experience
- Timed questions with an on-screen countdown
- Category-based quiz banks pulled from Firestore
- Score tracking: correct, incorrect, and skipped question counts
- Detailed result breakdown at the end of each session

### 📊 History & Analytics
- Hosts can view a full history of rooms they've created
- Drill into any past room to review its questions and results

---

## 🏗️ Architecture

```
smart_app_quiz/
├── lib/
│   ├── models/
│   │   └── question_model.dart        # Question data model
│   ├── services/
│   │   └── firestore_service.dart     # All Firestore/Auth data operations
│   ├── screens/
│   │   ├── login_screen.dart          # Email + Google authentication
│   │   ├── signup_screen.dart         # Account creation
│   │   ├── home_screen.dart           # Category dashboard
│   │   ├── create_room_screen.dart    # Host: build a custom room
│   │   ├── join_room_screen.dart      # Player: join via room code
│   │   ├── RoomLobbyScreen.dart       # Pre-game live lobby
│   │   ├── HostMonitorScreen.dart     # Host: live player monitoring
│   │   ├── quiz_screen.dart           # Core quiz gameplay
│   │   ├── result_screen.dart         # Post-quiz results
│   │   ├── HostHistoryScreen.dart     # Host's room history
│   │   ├── HistoryDetailScreen.dart   # Detail view of a past room
│   │   └── profile_screen.dart        # User profile management
│   ├── widgets/
│   │   ├── custom_button.dart
│   │   └── question_card.dart
│   └── main.dart
│
└── assets/
    └── images/
```

**Real-time sync:** Room state (players, status, questions, scores) is stored in Firestore and streamed live to every connected client using `snapshots()`, so all players and the host stay in sync without polling.

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) |
| Authentication | Firebase Auth + Google Sign-In |
| Database | Cloud Firestore (real-time) |
| File Storage | Firebase Storage (profile pictures) |
| Local Persistence | shared_preferences |
| Media | image_picker |

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `^3.9.2`
- A [Firebase](https://console.firebase.google.com/) project with:
  - Authentication (Email/Password + Google Sign-In) enabled
  - Cloud Firestore enabled
  - Firebase Storage enabled

### 1. Clone the repository

```bash
git clone https://github.com/<your-username>/smart-quiz-app.git
cd smart-quiz-app
```

### 2. Configure Firebase

- Add your `google-services.json` (Android) to `android/app/`
- Add your `GoogleService-Info.plist` (iOS) to `ios/Runner/`
- Run `flutterfire configure` if you're setting up a new Firebase project, or ensure `firebase_options.dart` matches your project.

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Run the app

```bash
flutter run
```

---

## 🗃️ Firestore Data Structure

```
quizzes/
  {categoryId}/
    questions/
      {questionId}: { text, options[], correctIndex, ... }

rooms/
  {roomId}: {
    roomName, hostId, status,
    timeLimitSeconds, questionBank[],
    allowBack, requireAllAnswers,
    players[], createdAt
  }

users/
  {userId}: { displayName, sapId, bio, education[], experience[], profileImageUrl }
```

---

## 🗺️ Roadmap

- [ ] Push notifications when a room starts
- [ ] Leaderboards across quiz categories
- [ ] Composite Firestore indexes for sorted history queries
- [ ] Offline question caching

---

## 👤 Author

**Muhammad Sarmad Chughtai**
SAP ID: 54915

---

## 📄 License

This project was developed for academic purposes as part of a Human-Computer Interaction / Mobile Application Development course.
