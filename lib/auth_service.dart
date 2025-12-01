import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // API Key ImgBB (Pastikan ini valid/tidak limit)
  final String imgbbApiKey = '66db1b42ef2a5648c56f4a36a3ac907f';

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // --- REGISTER ---
  Future<void> signUpWithEmailPassword(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Inisialisasi data user baru yang lebih lengkap
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email,
        'displayName': email.split('@')[0],
        'status': 'Available',
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'photoURL': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // --- LOGIN ---
  Future<void> signInWithEmailPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await setUserOnlineStatus(true);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // --- LOGOUT ---
  Future<void> logout() async {
    await setUserOnlineStatus(false);
    await _auth.signOut();
  }

  // --- STATUS ONLINE ---
  Future<void> setUserOnlineStatus(bool isOnline) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
  }

  // --- UPLOAD KE IMGBB (FITUR UTAMA) ---
  Future<String> uploadToImgBB(Uint8List fileBytes) async {
    try {
      var uri = Uri.parse("https://api.imgbb.com/1/upload?key=$imgbbApiKey");
      var request = http.MultipartRequest("POST", uri);

      // Kirim file sebagai binary
      request.files.add(
        http.MultipartFile.fromBytes('image', fileBytes,
            filename: 'upload.jpg'),
      );

      print("⏳ Mengupload ke ImgBB...");
      var response = await request.send();

      if (response.statusCode == 200) {
        var responseData = await response.stream.toBytes();
        var responseString = String.fromCharCodes(responseData);
        var json = jsonDecode(responseString);

        String url = json['data']['url'];
        print("✅ Sukses Upload! URL: $url");

        // Simpan URL ke Firestore user yang sedang login
        await updateUserPhotoURL(url);
        return url;
      } else {
        print("❌ Gagal Upload. Status: ${response.statusCode}");
        throw Exception(
            "Gagal upload ke server gambar. Kode: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error: $e");
      throw Exception("Terjadi kesalahan koneksi saat upload.");
    }
  }

  // --- UPDATE DATA USER ---
  Future<void> updateUserPhotoURL(String photoURL) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({'photoURL': photoURL});
    }
  }

  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({'displayName': name});
    }
  }

  Future<void> updateUserStatus(String statusText) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({'status': statusText});
    }
  }

  Stream<DocumentSnapshot> getCurrentUserStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.empty();
    return _firestore.collection('users').doc(user.uid).snapshots();
  }
}
