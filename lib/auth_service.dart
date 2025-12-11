import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // API KEY IMGBB
  final String imgbbApiKey = '66db1b42ef2a5648c56f4a36a3ac907f';

  User? get currentUser => _auth.currentUser;

  Stream<DocumentSnapshot> getCurrentUserStream() {
    if (_auth.currentUser == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .snapshots();
  }

  // Login
  Future<UserCredential> signInWithEmailPassword(
      String email, String password) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      await setUserOnlineStatus(true);
      return cred;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // Register
  Future<UserCredential> signUpWithEmailPassword(
      String email, String password) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'email': email,
        'displayName': email.split('@')[0],
        'photoURL': null,
        'status': 'Hey there! I am using NeoChat.',
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return cred;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> logout() async {
    await setUserOnlineStatus(false);
    await _auth.signOut();
  }

  Future<void> setUserOnlineStatus(bool isOnline) async {
    if (_auth.currentUser != null) {
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> updateDisplayName(String name) async {
    if (_auth.currentUser != null) {
      await _auth.currentUser!.updateDisplayName(name);
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .update({'displayName': name});
    }
  }

  Future<void> updateUserStatus(String status) async {
    if (_auth.currentUser != null) {
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .update({'status': status});
    }
  }

  // --- UPLOAD KE IMGBB ---
  Future<String> uploadToImgBB(Uint8List fileBytes) async {
    try {
      var uri = Uri.parse("https://api.imgbb.com/1/upload?key=$imgbbApiKey");
      var request = http.MultipartRequest("POST", uri);
      request.files.add(http.MultipartFile.fromBytes('image', fileBytes,
          filename: 'upload.jpg'));

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.toBytes();
        var json = jsonDecode(String.fromCharCodes(responseData));
        String url = json['data']['url'];

        // Simpan ke Profil
        await _auth.currentUser!.updatePhotoURL(url);
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .update({'photoURL': url});
        return url;
      } else {
        throw Exception("Gagal upload ke ImgBB.");
      }
    } catch (e) {
      throw Exception("Error Upload: $e");
    }
  }
}
