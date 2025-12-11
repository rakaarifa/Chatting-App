import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'chat_service.dart';
import 'components/chat_bubble.dart';

class ChatPage extends StatefulWidget {
  final String roomId;
  final String title;
  final String? chatIcon; // Foto Profil lawan atau Grup

  const ChatPage(
      {super.key, required this.roomId, required this.title, this.chatIcon});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final currentUser = FirebaseAuth.instance.currentUser!;
  bool _isUploading = false;

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    String text = _controller.text;
    _controller.clear();
    await _chatService.sendMessage(widget.roomId, text);
    if (_scrollController.hasClients)
      _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut);
  }

  void _sendImage() async {
    final img = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (img != null) {
      setState(() => _isUploading = true);
      await _chatService.sendImageMessage(
          widget.roomId, await img.readAsBytes());
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: color.surface,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          CircleAvatar(
            backgroundImage: widget.chatIcon != null
                ? CachedNetworkImageProvider(widget.chatIcon!)
                : null,
            child: widget.chatIcon == null ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(widget.title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis)),
        ]),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(widget.roomId),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                var docs = snapshot.data!.docs;
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    var msg = docs[i].data() as Map<String, dynamic>;
                    bool isMe = msg['senderId'] == currentUser.uid;
                    // Tampilkan nama pengirim jika dalam Grup dan bukan pesan kita
                    // (Logika sederhana, bisa dikembangkan lagi fetch namanya)

                    return ChatBubble(
                      message: msg['message'],
                      type: msg['type'],
                      isMe: isMe,
                      time: DateFormat('HH:mm')
                          .format((msg['timestamp'] as Timestamp).toDate()),
                      isFirstInSequence: true, isLastInSequence: true,
                      replyTo: null, isRead: false,
                      senderName: isMe
                          ? "Anda"
                          : "Member", // Simplifikasi untuk performa
                      senderPhoto: null,
                      onLongPress: () {}, onSwipe: () {}, onImageTap: (url) {},
                    );
                  },
                );
              },
            ),
          ),
          if (_isUploading)
            LinearProgressIndicator(color: color.primary, minHeight: 2),
          Container(
            padding: const EdgeInsets.all(10),
            color: Theme.of(context).cardColor,
            child: Row(children: [
              IconButton(
                  onPressed: _sendImage,
                  icon: Icon(Icons.add_photo_alternate, color: color.primary)),
              Expanded(
                  child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                          hintText: "Ketik pesan...",
                          filled: true,
                          fillColor: color.surface,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 20)))),
              const SizedBox(width: 8),
              CircleAvatar(
                  backgroundColor: color.primary,
                  child: IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send, color: Colors.white))),
            ]),
          )
        ],
      ),
    );
  }
}
