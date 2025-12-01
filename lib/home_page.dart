import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_page.dart';
import 'auth_service.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _authService.setUserOnlineStatus(true);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: color.surface,
      appBar: AppBar(
        title:
            const Text("Chats", style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfilePage())),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  final photo = data?['photoURL'];
                  return CircleAvatar(
                    radius: 20,
                    backgroundImage: photo != null
                        ? CachedNetworkImageProvider(photo)
                        : null,
                    backgroundColor: color.surfaceContainerHighest,
                    child: photo == null
                        ? Icon(Icons.person, color: color.onSurfaceVariant)
                        : null,
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, isNotEqualTo: currentUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final users = snapshot.data!.docs;
          if (users.isEmpty)
            return const Center(child: Text("Belum ada kontak"));

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userData = users[index].data() as Map<String, dynamic>;
              final email = userData['email'] ?? '';
              final name = userData['displayName'] ?? email.split('@')[0];
              final photo = userData['photoURL'];
              final recipientId = users[index].id;

              // Helper ID Chat Room
              final chatRoomId =
                  currentUser.uid.hashCode <= recipientId.hashCode
                      ? '${currentUser.uid}_$recipientId'
                      : '${recipientId}_${currentUser.uid}';

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chat_rooms')
                    .doc(chatRoomId)
                    .snapshots(),
                builder: (context, chatSnapshot) {
                  final chatData =
                      chatSnapshot.data?.data() as Map<String, dynamic>?;
                  final lastMessage =
                      chatData?['lastMessage'] ?? "Mulai obrolan";
                  final lastTime = chatData?['lastMessageTime'] as Timestamp?;
                  // AMBIL UNREAD COUNT: Field 'unreadCount_MYUID'
                  final unreadCount =
                      chatData?['unreadCount_${currentUser.uid}'] ?? 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ChatPage(
                                  recipientId: recipientId,
                                  recipientEmail: email))),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ]),
                        child: Row(
                          children: [
                            CircleAvatar(
                                radius: 28,
                                backgroundImage: photo != null
                                    ? CachedNetworkImageProvider(photo)
                                    : null,
                                child: photo == null ? Text(name[0]) : null),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                      // WAKTU LAST MESSAGE
                                      if (lastTime != null)
                                        Text(
                                            "${lastTime.toDate().hour}:${lastTime.toDate().minute.toString().padLeft(2, '0')}",
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: color.onSurfaceVariant))
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                          child: Text(lastMessage,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  color: unreadCount > 0
                                                      ? color.primary
                                                      : color.onSurfaceVariant,
                                                  fontWeight: unreadCount > 0
                                                      ? FontWeight.bold
                                                      : FontWeight.normal))),
                                      // UNREAD BADGE (LINGKARAN MERAH)
                                      if (unreadCount > 0)
                                        Container(
                                          margin:
                                              const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                              color: Colors.redAccent,
                                              shape: BoxShape.circle),
                                          child: Text(unreadCount.toString(),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
