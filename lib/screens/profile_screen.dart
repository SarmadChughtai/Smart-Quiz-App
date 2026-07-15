import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/firestore_service.dart';
import 'HostHistoryScreen.dart'; // 1. Import History Screen

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  String? _profileImageUrl;
  String? _bio;
  List<Map<String, String>> _education = [];
  List<Map<String, String>> _experience = [];

  // Controllers
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _sapIdController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // --- DATA LOADING ---
  Future<void> _loadUserProfile() async {
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    _displayNameController.text = currentUser!.displayName ?? '';
    _emailController.text = currentUser!.email ?? '';

    try {
      final userData = await _firestoreService.getUserProfile(currentUser!.uid);
      if (userData != null) {
        setState(() {
          _profileImageUrl = userData['profileImageUrl'] as String?;
          _bio = userData['bio'] as String?;
          _bioController.text = _bio ?? '';

          _sapIdController.text = userData['sapId'] as String? ?? '';

          _education = List<Map<String, String>>.from(
              (userData['education'] as List? ?? []).map((item) => Map<String, String>.from(item))
          );
          _experience = List<Map<String, String>>.from(
              (userData['experience'] as List? ?? []).map((item) => Map<String, String>.from(item))
          );
        });
      }
    } catch (e) {
      debugPrint("Error loading user profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load profile: $e'))
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- DATA UPDATING AND SAVING ---
  Future<void> _updateProfile() async {
    if (currentUser == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      if (_displayNameController.text != (currentUser!.displayName ?? '')) {
        await currentUser!.updateDisplayName(_displayNameController.text);
      }

      await _firestoreService.updateUserProfile(
        currentUser!.uid,
        {
          'displayName': _displayNameController.text,
          'sapId': _sapIdController.text,
          'bio': _bioController.text,
          'education': _education,
          'experience': _experience,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!'))
        );
      }
    } catch (e) {
      debugPrint("Error updating profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update profile: $e'))
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final file = await image.readAsBytes();
      final String fileName = 'profile_pictures/${currentUser!.uid}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);

      final UploadTask uploadTask = storageRef.putData(file, SettableMetadata(contentType: 'image/jpeg'));
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _profileImageUrl = downloadUrl;
      });
      await _firestoreService.updateUserProfile(currentUser!.uid, {'profileImageUrl': downloadUrl});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated!'))
        );
      }
    } catch (e) {
      debugPrint("Error uploading image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload image: $e'))
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showAddEditDialog({
    required List<Map<String, String>> list,
    required String titleKey,
    required String subtitleKey,
    String dialogTitle = "Add Item",
    int? indexToEdit,
  }) {
    TextEditingController titleController = TextEditingController();
    TextEditingController subtitleController = TextEditingController();

    if (indexToEdit != null) {
      titleController.text = list[indexToEdit][titleKey] ?? '';
      subtitleController.text = list[indexToEdit][subtitleKey] ?? '';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C40),
        title: Text(dialogTitle, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: titleKey == 'degree' ? 'Degree/Course' : 'Job Title',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
              ),
            ),
            TextField(
              controller: subtitleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: subtitleKey == 'institution' ? 'Institution' : 'Company',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              setState(() {
                final newItem = {
                  titleKey: titleController.text,
                  subtitleKey: subtitleController.text,
                };
                if (indexToEdit != null) {
                  list[indexToEdit] = newItem;
                } else {
                  list.add(newItem);
                }
              });
              Navigator.pop(context);
              _updateProfile();
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('Please log in to view your profile.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E2C),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          _isSaving
              ? const Padding(
            padding: EdgeInsets.all(12.0),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
          )
              : IconButton(
            icon: const Icon(Icons.save, color: Colors.greenAccent),
            onPressed: _updateProfile,
            tooltip: 'Save Profile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: _pickAndUploadImage,
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.blueAccent.withOpacity(0.2),
                          backgroundImage: _profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null,
                          child: _profileImageUrl == null ? const Icon(Icons.person, size: 70, color: Colors.white) : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _displayNameController.text.isNotEmpty ? _displayNameController.text : 'No Name Set',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    currentUser!.email ?? 'No Email',
                    style: const TextStyle(fontSize: 14, color: Colors.white54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            _buildSectionHeader('Personal Info', Icons.person_outline),
            const SizedBox(height: 10),
            TextField(
              controller: _displayNameController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Display Name', Icons.person),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _sapIdController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('SAP ID', Icons.badge),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white70),
              readOnly: true,
              decoration: _inputDecoration('Email', Icons.email_outlined).copyWith(fillColor: Colors.black12),
            ),

            const SizedBox(height: 30),

            _buildSectionHeader('About Me', Icons.info_outline),
            const SizedBox(height: 10),
            TextField(
              controller: _bioController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Write a short bio...', Icons.description),
            ),

            const SizedBox(height: 30),

            _buildSectionHeader('Education', Icons.school),
            ..._education.asMap().entries.map((entry) {
              return _buildListItem(
                title: entry.value['degree'] ?? '',
                subtitle: entry.value['institution'] ?? '',
                onEdit: () => _showAddEditDialog(list: _education, titleKey: 'degree', subtitleKey: 'institution', dialogTitle: 'Edit Education', indexToEdit: entry.key),
                onDelete: () { setState(() => _education.removeAt(entry.key)); _updateProfile(); },
              );
            }).toList(),
            _buildAddButton('Add Education', () => _showAddEditDialog(list: _education, titleKey: 'degree', subtitleKey: 'institution', dialogTitle: 'Add Education')),

            const SizedBox(height: 30),

            _buildSectionHeader('Experience', Icons.work),
            ..._experience.asMap().entries.map((entry) {
              return _buildListItem(
                title: entry.value['title'] ?? '',
                subtitle: entry.value['company'] ?? '',
                onEdit: () => _showAddEditDialog(list: _experience, titleKey: 'title', subtitleKey: 'company', dialogTitle: 'Edit Experience', indexToEdit: entry.key),
                onDelete: () { setState(() => _experience.removeAt(entry.key)); _updateProfile(); },
              );
            }).toList(),
            _buildAddButton('Add Experience', () => _showAddEditDialog(list: _experience, titleKey: 'title', subtitleKey: 'company', dialogTitle: 'Add Experience')),

            const SizedBox(height: 30),

            // --- 2. UPDATED SETTINGS SECTION ---
            _buildSectionHeader('Settings', Icons.settings),

            // Quiz History Button
            Card(
              color: Colors.grey.shade800.withOpacity(0.5),
              child: ListTile(
                leading: const Icon(Icons.history, color: Colors.purpleAccent),
                title: const Text('Quiz History', style: TextStyle(color: Colors.white)),
                subtitle: const Text('View past quizzes you hosted', style: TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HostHistoryScreen()),
                  );
                },
              ),
            ),

            // Privacy Settings
            Card(
              color: Colors.grey.shade800.withOpacity(0.5),
              child: ListTile(
                leading: const Icon(Icons.privacy_tip, color: Colors.white70),
                title: const Text('Privacy Settings', style: TextStyle(color: Colors.white)),
                onTap: () {}, // TODO: Implement
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- UI Helpers ---

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blueAccent, size: 24),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildListItem({required String title, required String subtitle, required VoidCallback onEdit, required VoidCallback onDelete}) {
    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20), onPressed: onEdit),
            IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20), onPressed: onDelete),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(String text, VoidCallback onPressed) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        icon: const Icon(Icons.add, color: Colors.blueAccent),
        label: Text(text, style: const TextStyle(color: Colors.blueAccent)),
        onPressed: onPressed,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent)),
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _sapIdController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}