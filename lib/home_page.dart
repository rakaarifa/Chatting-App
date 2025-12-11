import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'chat_page.dart';
import 'auth_service.dart';
import 'profile_page.dart';
import 'create_group_page.dart';
import 'chat_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _authService.setUserOnlineStatus(true);
  }

  // Modal untuk mulai chat baru (Private)
  void _startNewChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Scaffold(
          appBar: AppBar(title: const Text("Mulai Chat Baru")),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('uid', isNotEqualTo: _auth.currentUser!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var user =
                      snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    leading: CircleAvatar(
                        backgroundImage: user['photoURL'] != null
                            ? NetworkImage(user['photoURL'])
                            : null,
                        child: user['photoURL'] == null
                            ? const Icon(Icons.person)
                            : null),
                    title: Text(user['displayName'] ?? "User"),
                    subtitle: Text(user['email']),
                    onTap: () {
                      Navigator.pop(context); // Tutup modal
                      // Buka Chat Page
                      String roomId = _chatService.getPrivateRoomId(
                          _auth.currentUser!.uid, user['uid']);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ChatPage(
                                  roomId: roomId,
                                  title: user['displayName'],
                                  chatIcon: user['photoURL'])));
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
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
        title: const Text("Obrolan",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        actions: [
          IconButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: color.primaryContainer,
              child: const Icon(Icons.person, size: 20),
            ),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfilePage())),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Menu Pilihan: Chat Personal atau Grup
          showModalBottomSheet(
              context: context,
              builder: (c) => Wrap(children: [
                    ListTile(
                        leading: const Icon(Icons.person),
                        title: const Text("Chat Personal"),
                        onTap: () {
                          Navigator.pop(c);
                          _startNewChat();
                        }),
                    ListTile(
                        leading: const Icon(Icons.group_add),
                        title: const Text("Buat Grup Baru"),
                        onTap: () {
                          Navigator.pop(c);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const CreateGroupPage()));
                        }),
                  ]));
        },
        label: const Text("Chat Baru"),
        icon: const Icon(Icons.message),
        backgroundColor: color.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Query ROOMS tempat kita terdaftar
        stream: FirebaseFirestore.instance
            .collection('chat_rooms')
            .where('userIds', arrayContains: currentUser.uid)
            .orderBy('lastTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 20),
                  Text("Belum ada obrolan",
                      style: TextStyle(color: Colors.grey[500]))
                ]));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var roomData =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;
              String roomId = snapshot.data!.docs[index].id;
              bool isGroup = roomData['isGroup'] ?? false;

              // Helper Widget untuk menampilkan item chat
              return _buildChatItem(
                  context, roomId, roomData, isGroup, currentUser.uid);
            },
          );
        },
      ),
    );
  }

  Widget _buildChatItem(BuildContext context, String roomId,
      Map<String, dynamic> roomData, bool isGroup, String myUid) {
    // Jika Grup: Pakai data grup langsung
    if (isGroup) {
      return _chatTile(context, roomId, roomData['groupName'],
          roomData['groupIcon'], roomData, true);
    }
    // Jika Private: Harus cari nama lawan bicara dulu
    else {
      List<dynamic> users = roomData['userIds'];
      String otherId = users.firstWhere((id) => id != myUid, orElse: () => "");

      return FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection('users').doc(otherId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const SizedBox(); // Loading state hidden
          var userData = snapshot.data!.data() as Map<String, dynamic>?;
          String name = userData?['displayName'] ?? "User";
          String? photo = userData?['photoURL'];
          return _chatTile(context, roomId, name, photo, roomData, false);
        },
      );
    }
  }

  Widget _chatTile(BuildContext context, String roomId, String title,
      String? photo, Map<String, dynamic> roomData, bool isGroup) {
    String lastMsg = roomData['lastMessage'] ?? "";
    Timestamp? time = roomData['lastTime'];
    String timeStr =
        time != null ? DateFormat('HH:mm').format(time.toDate()) : "";

    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.withOpacity(0.1))),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    ChatPage(roomId: roomId, title: title, chatIcon: photo))),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          backgroundImage:
              photo != null ? CachedNetworkImageProvider(photo) : null,
          child: photo == null
              ? Icon(isGroup ? Icons.groups : Icons.person,
                  color: Theme.of(context).colorScheme.primary)
              : null,
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text(timeStr,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ),
    );
  }
}
