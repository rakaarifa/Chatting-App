import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'theme_provider.dart';
import 'components/my_button.dart';
import 'components/my_textfield.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _statusController = TextEditingController();

  // PENANDA UPDATE GAMBAR
  int _imageRefreshCounter = 0;

  bool _isLoading = false;
  bool _init = false;

  @override
  void dispose() {
    _nameController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await _authService.updateDisplayName(_nameController.text);
      await _authService.updateUserStatus(_statusController.text);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Profil diperbarui")));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _upload() async {
    final img = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (img != null) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Mengupload...")));

      try {
        await _authService.uploadToImgBB(await img.readAsBytes());

        if (mounted) {
          // PERBAIKAN DI SINI: HAPUS 'await' KARENA FUNGSI INI SYNCHRONOUS
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();

          setState(() {
            _imageRefreshCounter++;
          });

          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Foto Berhasil Diganti!")));
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Gagal: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: color.surface,
      appBar: AppBar(title: const Text("Edit Profil")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _authService.getCurrentUserStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          if (!_init) {
            _nameController.text = data['displayName'] ?? '';
            _statusController.text = data['status'] ?? '';
            _init = true;
          }

          // URL DENGAN QUERY PARAMETER AGAR BROWSER TIDAK CACHE
          String? photoURL = data['photoURL'];
          if (photoURL != null) {
            photoURL = "$photoURL?v=$_imageRefreshCounter";
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _upload,
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.primaryContainer,
                            border: Border.all(color: color.primary, width: 2)),
                        child: ClipOval(
                          child: data['photoURL'] != null
                              ? CachedNetworkImage(
                                  key: ValueKey(photoURL), // Paksa rebuild
                                  imageUrl: photoURL!,
                                  fit: BoxFit.cover,
                                  placeholder: (c, u) => const Padding(
                                      padding: EdgeInsets.all(40),
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                  errorWidget: (c, u, e) =>
                                      const Icon(Icons.person, size: 60),
                                )
                              : const Icon(Icons.person, size: 60),
                        ),
                      ),
                      Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: color.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: color.surface, width: 3)),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 20)))
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                MyTextField(
                    controller: _nameController,
                    hintText: "Nama Lengkap",
                    obscureText: false,
                    prefixIcon: Icons.person),
                const SizedBox(height: 16),
                MyTextField(
                    controller: _statusController,
                    hintText: "Status / Bio",
                    obscureText: false,
                    prefixIcon: Icons.info_outline),
                const SizedBox(height: 20),
                SwitchListTile(
                    title: const Text("Dark Mode"),
                    value: theme.themeMode == ThemeMode.dark,
                    onChanged: (v) => theme
                        .setThemeMode(v ? ThemeMode.dark : ThemeMode.light)),
                ListTile(
                  title: const Text("Copy ID"),
                  subtitle: Text(data['uid'] ?? '',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  leading: const Icon(Icons.fingerprint),
                  trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: data['uid']))),
                ),
                const SizedBox(height: 30),
                MyButton(text: "SIMPAN", onTap: _save, isLoading: _isLoading),
                TextButton(
                    onPressed: () => _authService.logout(),
                    child: const Text("Log Out",
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold)))
              ],
            ),
          );
        },
      ),
    );
  }
}
