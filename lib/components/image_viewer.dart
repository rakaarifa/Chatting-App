import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ImageViewer extends StatelessWidget {
  final String imageUrl;
  const ImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        // InteractiveViewer memungkinkan user cubit (pinch) untuk zoom
        child: InteractiveViewer(
          panEnabled: true, // Bisa geser-geser
          minScale: 0.5,
          maxScale: 4.0, // Zoom sampai 4x
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) =>
                const CircularProgressIndicator(color: Colors.white),
            errorWidget: (context, url, error) =>
                const Icon(Icons.broken_image, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
