import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'chat_service.dart';
import 'components/my_button.dart';
import 'components/my_textfield.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final TextEditingController _groupNameController = TextEditingController();
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<String> _selectedUserIds = [];
  bool _isLoading = false;
  Uint8List? _imageBytes;

  Future<void> _pickImage() async {
    final img = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (img != null) {
      final bytes = await img.readAsBytes();
      setState(() => _imageBytes = bytes);
    }
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.isEmpty || _selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Nama grup dan anggota wajib diisi!")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _chatService.createGroup(
          _groupNameController.text, _selectedUserIds, _imageBytes);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Grup Berhasil Dibuat!")));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text("Buat Grup Baru")),
      body: Column(
        children: [
          // Header: Foto & Nama Grup
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: color.primaryContainer,
                    backgroundImage:
                        _imageBytes != null ? MemoryImage(_imageBytes!) : null,
                    child: _imageBytes == null
                        ? const Icon(Icons.camera_alt)
                        : null,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                    child: MyTextField(
                        controller: _groupNameController,
                        hintText: "Nama Grup",
                        obscureText: false,
                        prefixIcon: Icons.group)),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text("Pilih Anggota",
                    style: TextStyle(fontWeight: FontWeight.bold))),
          ),

          // List User Selection
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('uid', isNotEqualTo: _auth.currentUser!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final users = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final data = users[index].data() as Map<String, dynamic>;
                    final uid = data['uid'];
                    final isSelected = _selectedUserIds.contains(uid);

                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(data['displayName'] ?? "User"),
                      secondary: CircleAvatar(
                        backgroundImage: data['photoURL'] != null
                            ? NetworkImage(data['photoURL'])
                            : null,
                        child: data['photoURL'] == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedUserIds.add(uid);
                          } else {
                            _selectedUserIds.remove(uid);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: MyButton(
                text: "BUAT GRUP (${_selectedUserIds.length})",
                onTap: _createGroup,
                isLoading: _isLoading),
          )
        ],
      ),
    );
  }
}
