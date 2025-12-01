import 'dart:async';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:any_link_preview/any_link_preview.dart'; // Import Link Preview
import 'chat_service.dart';

class ChatPage extends StatefulWidget {
  final String recipientId;
  final String recipientEmail;

  const ChatPage(
      {super.key, required this.recipientId, required this.recipientEmail});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final currentUser = FirebaseAuth.instance.currentUser!;

  bool _isUploading = false;
  Timer? _typingTimer;
  Map<String, dynamic>? _replyMessage;
  String? _editingMessageId; // ID pesan yang sedang diedit

  @override
  void initState() {
    super.initState();
    _chatService.markMessagesAsRead(widget.recipientId);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100, // Extra offset
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onTextChanged(String text) {
    _chatService.setTypingStatus(widget.recipientId, true);
    if (_typingTimer?.isActive ?? false) _typingTimer!.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 1500), () {
      _chatService.setTypingStatus(widget.recipientId, false);
    });
  }

  // --- SEND & EDIT LOGIC ---
  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    _chatService.setTypingStatus(widget.recipientId, false);

    if (_editingMessageId != null) {
      // MODE EDIT
      await _chatService.editMessage(
          widget.recipientId, _editingMessageId!, text);
      setState(() => _editingMessageId = null);
    } else {
      // MODE KIRIM BARU
      await _chatService.sendMessage(widget.recipientId, text,
          replyTo: _replyMessage);
      _cancelReply();
      _scrollToBottom();
    }
  }

  // --- REPLY LOGIC ---
  void _replyToMessage(Map<String, dynamic> msg, String senderName) {
    setState(() {
      _editingMessageId = null; // Batal edit jika reply
      _replyMessage = {
        'message': msg['message'],
        'senderName': senderName,
        'type': msg['type']
      };
    });
  }

  void _cancelReply() {
    setState(() {
      _replyMessage = null;
      _editingMessageId = null;
      _controller.clear();
    });
  }

  // --- MENU OPSI (REACTION & EDIT) ---
  void _showMessageOptions(
      String messageId, Map<String, dynamic> msg, bool isMe) {
    // List Emoji Populer
    final emojis = ['❤️', '😂', '👍', '😢', '🔥', '🎉'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final color = Theme.of(context).colorScheme;
        return Container(
          decoration: BoxDecoration(
              color: color.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20))),
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Baris Reaksi
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: emojis
                      .map((e) => GestureDetector(
                            onTap: () {
                              _chatService.toggleReaction(
                                  widget.recipientId, messageId, e);
                              Navigator.pop(context);
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: color.surfaceContainerHighest,
                                  shape: BoxShape.circle),
                              child:
                                  Text(e, style: const TextStyle(fontSize: 24)),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const Divider(height: 30),

              // 2. Opsi Standar
              if (msg['type'] == 'text')
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text("Salin"),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: msg['message']));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Teks disalin")));
                  },
                ),
              if (isMe && msg['type'] == 'text')
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text("Edit Pesan"),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _editingMessageId = messageId;
                      _controller.text =
                          msg['message']; // Isi text field dengan pesan lama
                      _replyMessage = null;
                    });
                  },
                ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title:
                      const Text("Hapus", style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete(messageId);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(String messageId) {
    _chatService.deleteMessage(widget.recipientId, messageId);
  }

  // --- IMAGE PICKER ---
  Future<void> _pickAndSendImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() => _isUploading = true);
      try {
        final Uint8List bytes = await image.readAsBytes();
        await _chatService.sendImageMessage(
            widget.recipientId, bytes, image.name,
            replyTo: _replyMessage);
        _cancelReply();
        _scrollToBottom();
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: color.surface,
      appBar: _buildAppBar(color),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(widget.recipientId),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                // Auto scroll Logic yg lebih aman
                if (docs.isNotEmpty) {
                  // Cek apakah user sedang scroll ke atas? Kalau tidak, auto scroll
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final msg = docs[i].data() as Map<String, dynamic>;
                    final docId = docs[i].id;
                    final isMe = msg['senderId'] == currentUser.uid;
                    return _buildMessageItem(msg, docId, isMe, color);
                  },
                );
              },
            ),
          ),
          if (_isUploading)
            LinearProgressIndicator(color: color.primary, minHeight: 2),

          // --- PREVIEW BOX (REPLY / EDIT) ---
          if (_replyMessage != null || _editingMessageId != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.surfaceContainerHighest,
                  border: Border(top: BorderSide(color: color.outlineVariant))),
              child: Row(
                children: [
                  Icon(_editingMessageId != null ? Icons.edit : Icons.reply,
                      color: color.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            _editingMessageId != null
                                ? "Mengedit Pesan"
                                : "Membalas ${_replyMessage!['senderName']}",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: color.primary)),
                        Text(
                            _editingMessageId != null
                                ? "Tekan kirim untuk update"
                                : (_replyMessage!['type'] == 'image'
                                    ? "📷 Foto"
                                    : _replyMessage!['message']),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                      icon: const Icon(Icons.close), onPressed: _cancelReply)
                ],
              ),
            ),

          _buildInputArea(color),
        ],
      ),
    );
  }

  // --- ITEM PESAN SUPER CANGGIH ---
  Widget _buildMessageItem(
      Map<String, dynamic> msg, String docId, bool isMe, ColorScheme color) {
    final isImage = msg['type'] == 'image';
    final timestamp = (msg['timestamp'] as Timestamp?)?.toDate();
    final timeStr =
        timestamp != null ? DateFormat('HH:mm').format(timestamp) : '...';
    final replyData = msg['replyTo'] as Map<String, dynamic>?;
    final isEdited = msg['isEdited'] ?? false;
    final reactions = msg['reactions'] as Map<String, dynamic>? ?? {};

    // Helper: Deteksi Link URL
    final bool hasUrl = !isImage && (msg['message'] as String).contains('http');

    return GestureDetector(
      onLongPress: () => _showMessageOptions(docId, msg, isMe),
      child: Dismissible(
        key: Key(docId),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (_) async {
          _replyToMessage(
              msg, isMe ? "Anda" : widget.recipientEmail.split('@')[0]);
          return false;
        },
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 2, top: 4),
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isMe ? color.primary : color.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft:
                          isMe ? const Radius.circular(16) : Radius.zero,
                      bottomRight:
                          isMe ? Radius.zero : const Radius.circular(16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A. KUTIPAN REPLY
                    if (replyData != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                              left: BorderSide(
                                  color: isMe ? Colors.white : color.primary,
                                  width: 3)),
                        ),
                        child: Text(
                          "${replyData['senderName']}: ${replyData['type'] == 'image' ? '📷 Foto' : replyData['message']}",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              color: isMe
                                  ? Colors.white70
                                  : color.onSurfaceVariant),
                        ),
                      ),

                    // B. CONTENT UTAMA (IMAGE / TEXT / LINK)
                    if (isImage)
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    ImageViewer(imageUrl: msg['message']))),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                              imageUrl: msg['message'],
                              placeholder: (c, u) => Container(
                                  height: 150, color: Colors.grey[300]),
                              errorWidget: (c, u, e) =>
                                  const Icon(Icons.broken_image)),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(msg['message'] ?? '',
                              style: TextStyle(
                                  color: isMe ? Colors.white : color.onSurface,
                                  fontSize: 15)),

                          // FITUR LINK PREVIEW (Hanya muncul jika ada link)
                          if (hasUrl)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: AnyLinkPreview(
                                link: msg['message'],
                                displayDirection:
                                    UIDirection.uiDirectionVertical,
                                showMultimedia: true,
                                bodyMaxLines: 2,
                                bodyTextOverflow: TextOverflow.ellipsis,
                                titleStyle: TextStyle(
                                    color: isMe ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                                bodyStyle: TextStyle(
                                    color: isMe ? Colors.white70 : Colors.grey,
                                    fontSize: 10),
                                backgroundColor: isMe
                                    ? color.primary.withOpacity(0.8)
                                    : Colors.white,
                              ),
                            ),
                        ],
                      ),

                    const SizedBox(height: 4),

                    // C. INFO WAKTU & EDIT
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isEdited)
                          Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(Icons.edit,
                                  size: 10,
                                  color: isMe ? Colors.white70 : Colors.grey)),
                        Text(timeStr,
                            style: TextStyle(
                                fontSize: 10,
                                color: isMe
                                    ? Colors.white70
                                    : color.onSurfaceVariant)),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.done_all, size: 14, color: Colors.white70)
                        ]
                      ],
                    )
                  ],
                ),
              ),

              // D. REACTION EMOJIS (Bubble Kecil di Bawah)
              if (reactions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: color.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2))
                      ],
                      border: Border.all(
                          color: color.outlineVariant.withOpacity(0.3))),
                  child: Text(reactions.values.toSet().join(' '),
                      style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // AppBar & Input sama seperti sebelumnya...
  AppBar _buildAppBar(ColorScheme color) {
    return AppBar(
      titleSpacing: 0,
      leading: IconButton(
          icon: Icon(Icons.arrow_back, color: color.onSurface),
          onPressed: () => Navigator.pop(context)),
      title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.recipientId)
              .snapshots(),
          builder: (context, userSnapshot) {
            return StreamBuilder<DocumentSnapshot>(
                stream: _chatService.getChatRoomStream(widget.recipientId),
                builder: (context, roomSnapshot) {
                  final userData =
                      userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                  final isOnline = userData['isOnline'] ?? false;
                  bool isTyping = false;
                  if (roomSnapshot.hasData && roomSnapshot.data!.exists) {
                    isTyping = (roomSnapshot.data!.data()
                                as Map<String, dynamic>)['typing']
                            ?[widget.recipientId] ??
                        false;
                  }
                  return Row(children: [
                    CircleAvatar(
                        backgroundImage: userData['photoURL'] != null
                            ? CachedNetworkImageProvider(userData['photoURL'])
                            : null,
                        child: userData['photoURL'] == null
                            ? const Icon(Icons.person)
                            : null),
                    const SizedBox(width: 10),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(userData['displayName'] ?? '',
                              style: const TextStyle(fontSize: 16)),
                          Text(
                              isTyping
                                  ? "Sedang mengetik..."
                                  : (isOnline ? "Online" : "Offline"),
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isTyping ? color.primary : Colors.grey))
                        ])
                  ]);
                });
          }),
    );
  }

  Widget _buildInputArea(ColorScheme color) {
    return Container(
      padding: const EdgeInsets.all(10),
      color: color.surface,
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
                onPressed: _isUploading ? null : _pickAndSendImage,
                icon: Icon(Icons.add_photo_alternate, color: color.primary)),
            Expanded(
                child: TextField(
                    controller: _controller,
                    onChanged: _onTextChanged,
                    decoration: InputDecoration(
                        hintText: "Ketik pesan...",
                        filled: true,
                        fillColor:
                            color.surfaceContainerHighest.withOpacity(0.5),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16)),
                    onSubmitted: (_) => _handleSend())),
            IconButton(
                onPressed: _handleSend,
                icon: Icon(
                    _editingMessageId != null ? Icons.check_circle : Icons.send,
                    color: color.primary)),
          ],
        ),
      ),
    );
  }
}

// --- CLASS IMAGE VIEWER (BISA COPY DI BAWAH FILE INI AJA) ---
class ImageViewer extends StatelessWidget {
  final String imageUrl;
  const ImageViewer({super.key, required this.imageUrl});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: CachedNetworkImage(imageUrl: imageUrl)),
      ),
    );
  }
}
