import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ChatService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String _getChatRoomId(String userId1, String userId2) {
    return userId1.hashCode <= userId2.hashCode
        ? '${userId1}_$userId2'
        : '${userId2}_$userId1';
  }

  // --- KIRIM PESAN ---
  Future<void> sendMessage(String recipientId, String message,
      {Map<String, dynamic>? replyTo}) async {
    await _sendToFirestore(recipientId, message, 'text', replyTo: replyTo);
  }

  Future<void> sendImageMessage(
      String recipientId, Uint8List fileBytes, String fileName,
      {Map<String, dynamic>? replyTo}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      String uniqueName = "${DateTime.now().millisecondsSinceEpoch}_$fileName";
      Reference ref = _storage.ref().child('chat_images/$uniqueName');

      final metadata = SettableMetadata(contentType: 'image/jpeg');
      UploadTask uploadTask = ref.putData(fileBytes, metadata);
      String downloadUrl = await (await uploadTask).ref.getDownloadURL();

      await _sendToFirestore(recipientId, downloadUrl, 'image',
          replyTo: replyTo);
    } catch (e) {
      throw Exception("Gagal kirim gambar: $e");
    }
  }

  // --- CORE LOGIC ---
  Future<void> _sendToFirestore(String recipientId, String content, String type,
      {Map<String, dynamic>? replyTo}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final chatRoomId = _getChatRoomId(currentUser.uid, recipientId);

    final messageData = {
      'senderId': currentUser.uid,
      'receiverId': recipientId,
      'message': content,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'replyTo': replyTo,
      'isEdited': false, // Field baru: Status Edit
      'reactions': {}, // Field baru: Reactions Map {uid: emoji}
    };

    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add(messageData);

    String previewMsg = type == 'image' ? '📷 Gambar' : content;
    await _firestore.collection('chat_rooms').doc(chatRoomId).set({
      'participants': [currentUser.uid, recipientId],
      'lastMessage': previewMsg,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'senderId': currentUser.uid,
      'unreadCount_${recipientId}': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  // --- FITUR BARU: EDIT PESAN ---
  Future<void> editMessage(
      String recipientId, String messageId, String newContent) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final chatRoomId = _getChatRoomId(currentUser.uid, recipientId);

    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .update({
      'message': newContent,
      'isEdited': true, // Tandai sebagai diedit
    });
  }

  // --- FITUR BARU: TOGGLE REACTION ---
  Future<void> toggleReaction(
      String recipientId, String messageId, String emoji) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final chatRoomId = _getChatRoomId(currentUser.uid, recipientId);

    final docRef = _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId);
    final docSnapshot = await docRef.get();

    if (docSnapshot.exists) {
      Map<String, dynamic> reactions = docSnapshot.data()?['reactions'] ?? {};

      // Jika user sudah kasih reaksi yg sama -> Hapus (Toggle Off)
      // Jika beda atau belum ada -> Update (Toggle On)
      if (reactions[currentUser.uid] == emoji) {
        reactions.remove(currentUser.uid);
      } else {
        reactions[currentUser.uid] = emoji;
      }

      await docRef.update({'reactions': reactions});
    }
  }

  // --- STANDARD FEATURES ---
  Stream<QuerySnapshot> getMessages(String recipientId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User null');
    final chatRoomId = _getChatRoomId(currentUser.uid, recipientId);
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Future<void> markMessagesAsRead(String recipientId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final chatRoomId = _getChatRoomId(currentUser.uid, recipientId);
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .update({'unreadCount_${currentUser.uid}': 0});
  }

  Future<void> deleteMessage(String recipientId, String messageId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final chatRoomId = _getChatRoomId(currentUser.uid, recipientId);
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  Future<void> setTypingStatus(String recipientId, bool isTyping) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final chatRoomId = _getChatRoomId(currentUser.uid, recipientId);
    await _firestore.collection('chat_rooms').doc(chatRoomId).set({
      'typing': {currentUser.uid: isTyping}
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot> getChatRoomStream(String recipientId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.empty();
    final chatRoomId = _getChatRoomId(currentUser.uid, recipientId);
    return _firestore.collection('chat_rooms').doc(chatRoomId).snapshots();
  }
}
