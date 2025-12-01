import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'theme_provider.dart';
import 'components/my_button.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _statusController = TextEditingController();

  bool _isLoading = false;
  bool _isUploading = false; // Indikator loading saat upload gambar
  bool _init = false;

  // Fungsi Simpan Teks (Nama & Status)
  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await _authService.updateDisplayName(_nameController.text);
      await _authService.updateUserStatus(_statusController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Profil berhasil diperbarui!"),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Gagal menyimpan: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIKA UPLOAD GAMBAR KE IMGBB ---
  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    // Gunakan kualitas 60% agar proses upload lebih cepat dan hemat kuota
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);

    if (image == null) return; // User batal pilih gambar

    setState(() => _isUploading = true);
    try {
      final Uint8List bytes = await image.readAsBytes();

      // Panggil fungsi uploadToImgBB dari AuthService
      await _authService.uploadToImgBB(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Foto profil berhasil diganti!"),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Gagal Upload: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: color.surface,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _authService.getCurrentUserStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          // Isi controller hanya sekali saat pertama kali load
          if (!_init) {
            _nameController.text = data['displayName'] ?? '';
            _statusController.text = data['status'] ?? '';
            _init = true;
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // --- HEADER MEWAH (GRADIENT) ---
                SizedBox(
                  height: 280,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background Gradient
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [color.primary, color.secondary],
                            ),
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(40)),
                          ),
                        ),
                      ),
                      // Tombol Kembali
                      Positioned(
                        top: 50,
                        left: 16,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios,
                              color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      // Tombol Ganti Tema (Terang/Gelap)
                      Positioned(
                        top: 50,
                        right: 16,
                        child: IconButton(
                          icon: Icon(
                              themeProvider.themeMode == ThemeMode.dark
                                  ? Icons.light_mode
                                  : Icons.dark_mode,
                              color: Colors.white),
                          onPressed: () => themeProvider.setThemeMode(
                              themeProvider.themeMode == ThemeMode.dark
                                  ? ThemeMode.light
                                  : ThemeMode.dark),
                        ),
                      ),
                      // Avatar Profile Besar
                      Positioned(
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _isUploading ? null : _pickAndUploadImage,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: color.surface,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 20,
                                        offset: const Offset(0, 10))
                                  ],
                                ),
                                child: Hero(
                                  tag:
                                      'profile_pic_small', // Tag Hero harus sama dengan di Home Page
                                  child: CircleAvatar(
                                    radius: 65,
                                    backgroundColor: Colors.grey.shade200,
                                    backgroundImage: data['photoURL'] != null
                                        ? CachedNetworkImageProvider(
                                            data['photoURL'])
                                        : null,
                                    child: data['photoURL'] == null
                                        ? Icon(Icons.person,
                                            size: 60,
                                            color: Colors.grey.shade400)
                                        : null,
                                  ),
                                ),
                              ),
                              // Loading Indicator jika sedang upload
                              if (_isUploading)
                                const SizedBox(
                                  width: 130,
                                  height: 130,
                                  child: CircularProgressIndicator(
                                      color: Colors.blue, strokeWidth: 5),
                                ),
                              // Ikon Kamera Kecil
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                      color: color.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: color.surface, width: 3)),
                                  child: const Icon(Icons.camera_alt,
                                      color: Colors.white, size: 20),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // --- FORM MODERN ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Text("Edit Profil",
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: color.onSurface)),
                      const SizedBox(height: 8),
                      Text("Perbarui informasimu agar terlihat profesional",
                          style: TextStyle(
                              color: color.onSurfaceVariant, fontSize: 14)),
                      const SizedBox(height: 30),

                      _buildTextField(context, "Nama Lengkap", _nameController,
                          Icons.person_outline),
                      const SizedBox(height: 20),
                      _buildTextField(context, "Bio Status", _statusController,
                          Icons.short_text_rounded),

                      const SizedBox(height: 40),
                      MyButton(
                          text: "SIMPAN PERUBAHAN",
                          onTap: _save,
                          isLoading: _isLoading),

                      const SizedBox(height: 20),
                      // Tombol Logout Sederhana
                      TextButton.icon(
                        onPressed: () => _authService.logout(),
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text("Keluar Akun",
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // Widget Helper untuk Text Field
  Widget _buildTextField(BuildContext context, String label,
      TextEditingController ctrl, IconData icon) {
    final color = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                TextStyle(fontWeight: FontWeight.w600, color: color.onSurface)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: color.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.outline.withOpacity(0.1)),
          ),
          child: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: color.primary),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
