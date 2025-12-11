import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:any_link_preview/any_link_preview.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final String type;
  final bool isMe;
  final String time;
  final bool isFirstInSequence;
  final bool isLastInSequence;
  final Map<String, dynamic>? replyTo;
  final bool isEdited;
  final bool isRead;
  final String? senderPhoto;
  final String senderName; // <-- VARIABEL INI YANG TADI HILANG
  final Function() onLongPress;
  final Function() onSwipe;
  final Function(String) onImageTap;

  const ChatBubble({
    super.key,
    required this.message,
    required this.type,
    required this.isMe,
    required this.time,
    required this.isFirstInSequence,
    required this.isLastInSequence,
    this.replyTo,
    this.isEdited = false,
    this.isRead = false,
    this.senderPhoto,
    required this.senderName, // <-- WAJIB ADA
    required this.onLongPress,
    required this.onSwipe,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final isImage = type == 'image';
    final hasUrl = !isImage &&
        (message.contains('http://') || message.contains('https://'));

    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(isMe ? 20 : (isFirstInSequence ? 20 : 5)),
      topRight: Radius.circular(isMe ? (isFirstInSequence ? 20 : 5) : 20),
      bottomLeft: Radius.circular(isMe ? 20 : (isLastInSequence ? 20 : 5)),
      bottomRight: Radius.circular(isMe ? (isLastInSequence ? 20 : 5) : 20),
    );

    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        onSwipe();
        return false;
      },
      child: Container(
        margin: EdgeInsets.only(
            top: isFirstInSequence ? 4 : 1,
            bottom: isLastInSequence ? 8 : 1,
            left: isMe ? 64 : 16,
            right: isMe ? 16 : 64),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMe)
              Container(
                width: 32,
                margin: const EdgeInsets.only(right: 8),
                child: isLastInSequence
                    ? CircleAvatar(
                        radius: 16,
                        backgroundColor: color.surfaceContainerHighest,
                        backgroundImage: senderPhoto != null
                            ? CachedNetworkImageProvider(senderPhoto!)
                            : null,
                        child: senderPhoto == null
                            ? Text(
                                senderName.isNotEmpty
                                    ? senderName[0].toUpperCase()
                                    : "?",
                                style: const TextStyle(fontSize: 12))
                            : null,
                      )
                    : const SizedBox(),
              ),
            Flexible(
              child: GestureDetector(
                onLongPress: onLongPress,
                child: Container(
                  padding: isImage
                      ? const EdgeInsets.all(4)
                      : const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? LinearGradient(
                            colors: [color.primary, color.secondary])
                        : null,
                    color: isMe
                        ? null
                        : (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1E293B)
                            : Colors.white),
                    borderRadius: borderRadius,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (replyTo != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border(
                                left: BorderSide(
                                    color: isMe ? Colors.white : color.primary,
                                    width: 3)),
                          ),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(replyTo!['senderName'] ?? 'Unknown',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: isMe
                                            ? Colors.white70
                                            : color.primary)),
                                Text(
                                    replyTo!['type'] == 'image'
                                        ? '📷 Foto'
                                        : (replyTo!['message'] ?? ''),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: isMe
                                            ? Colors.white70
                                            : Colors.grey[700])),
                              ]),
                        ),
                      if (isImage)
                        GestureDetector(
                            onTap: () => onImageTap(message),
                            child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: CachedNetworkImage(
                                    imageUrl: message,
                                    height: 200,
                                    width: 200,
                                    fit: BoxFit.cover)))
                      else
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(message,
                                  style: TextStyle(
                                      color:
                                          isMe ? Colors.white : color.onSurface,
                                      fontSize: 15,
                                      height: 1.3)),
                              if (hasUrl)
                                Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: AnyLinkPreview(
                                        link: message,
                                        displayDirection:
                                            UIDirection.uiDirectionVertical,
                                        bodyMaxLines: 2,
                                        backgroundColor: isMe
                                            ? Colors.white.withOpacity(0.1)
                                            : Colors.grey[50],
                                        errorWidget: const SizedBox())),
                            ]),
                      const SizedBox(height: 4),
                      Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (isEdited)
                              const Icon(Icons.edit,
                                  size: 10, color: Colors.white60),
                            Text(time,
                                style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        isMe ? Colors.white70 : Colors.grey)),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.done_all_rounded,
                                  size: 14,
                                  color: isRead ? Colors.white : Colors.white54)
                            ]
                          ])
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
