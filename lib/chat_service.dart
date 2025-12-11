import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String imgbbApiKey = '66db1b42ef2a5648c56f4a36a3ac907f';

  // --- FITUR BARU: BUAT GRUP ---
  Future<void> createGroup(
      String groupName, List<String> memberIds, Uint8List? imageFile) async {
    String currentUserId = _auth.currentUser!.uid;
    List<String> allMembers = [...memberIds, currentUserId];
    String? groupIconUrl;

    // 1. Upload Foto Grup jika ada
    if (imageFile != null) {
      groupIconUrl = await _uploadToImgBB(imageFile);
    }

    // 2. Buat Dokumen Grup
    DocumentReference newGroupRef = _firestore.collection('chat_rooms').doc();

    await newGroupRef.set({
      'isGroup': true,
      'groupName': groupName,
      'groupIcon': groupIconUrl,
      'adminId': currentUserId,
      'userIds': allMembers,
      'lastMessage': 'Grup dibuat',
      'lastTime': FieldValue.serverTimestamp(),
      'typing': {},
    });

    // 3. Pesan Sistem Awal
    await newGroupRef.collection('messages').add({
      'senderId': 'system',
      'message': 'Grup "$groupName" telah dibuat.',
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'system',
      'isRead': true,
    });
  }

  // --- KIRIM PESAN (Support Grup & Private) ---
  Future<void> sendMessage(String roomId, String message,
      {Map<String, dynamic>? replyTo}) async {
    final String currentUserId = _auth.currentUser!.uid;
    final Timestamp timestamp = Timestamp.now();

    Map<String, dynamic> newMessage = {
      'senderId': currentUserId,
      'message': message,
      'timestamp': timestamp,
      'type': 'text',
      'isRead': false,
      'replyTo': replyTo,
    };

    await _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .add(newMessage);
    await _firestore.collection('chat_rooms').doc(roomId).update({
      'lastMessage': message,
      'lastTime': timestamp,
      'unreadCount': FieldValue.increment(1), // Simplifikasi untuk grup
    });
  }

  // --- KIRIM GAMBAR ---
  Future<void> sendImageMessage(String roomId, Uint8List file,
      {Map<String, dynamic>? replyTo}) async {
    String currentUserId = _auth.currentUser!.uid;
    String? downloadUrl = await _uploadToImgBB(file);
    if (downloadUrl == null) return;

    Map<String, dynamic> newMessage = {
      'senderId': currentUserId,
      'message': downloadUrl,
      'timestamp': Timestamp.now(),
      'type': 'image',
      'isRead': false,
      'replyTo': replyTo,
    };

    await _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .add(newMessage);
    await _firestore.collection('chat_rooms').doc(roomId).update({
      'lastMessage': '📷 Foto',
      'lastTime': Timestamp.now(),
    });
  }

  // Helper Upload
  Future<String?> _uploadToImgBB(Uint8List file) async {
    try {
      var uri = Uri.parse("https://api.imgbb.com/1/upload?key=$imgbbApiKey");
      var request = http.MultipartRequest("POST", uri);
      request.files.add(
          http.MultipartFile.fromBytes('image', file, filename: 'upload.jpg'));
      var response = await request.send();
      if (response.statusCode == 200) {
        var res = await response.stream.toBytes();
        return jsonDecode(String.fromCharCodes(res))['data']['url'];
      }
    } catch (e) {
      print(e);
    }
    return null;
  }

  // Get Messages
  Stream<QuerySnapshot> getMessages(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Cek ID Room Private (Helper)
  String getPrivateRoomId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return ids.join('_');
  }
}
