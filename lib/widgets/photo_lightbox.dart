import 'dart:io';

import 'package:flutter/material.dart';

/// Full-screen photo viewer (user 2026-08-19: tapping an attendance photo
/// opens it "like a modal or lightbox").
///
/// Pinch-zoom + pan via [InteractiveViewer]; tap anywhere outside the
/// image or the ✕ to close. Renders network URLs and local file paths.
void showPhotoLightbox(BuildContext context, String path, {String? title}) {
  if (path.trim().isEmpty) return;
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.9),
    builder: (ctx) => GestureDetector(
      onTap: () => Navigator.pop(ctx),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(children: [
            Center(
              child: GestureDetector(
                onTap: () {}, // swallow taps on the image itself
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: path.startsWith('http')
                      ? Image.network(path, fit: BoxFit.contain,
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                                  ? child
                                  : const Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white)),
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white54, size: 56))
                      : Image.file(File(path), fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white54, size: 56)),
                ),
              ),
            ),
            if (title != null && title.isNotEmpty)
              Positioned(top: 10, left: 16, right: 60, child: Text(
                title,
                style: const TextStyle(color: Colors.white,
                    fontSize: 14, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis)),
            Positioned(top: 4, right: 8, child: IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close, color: Colors.white, size: 26),
            )),
          ]),
        ),
      ),
    ),
  );
}
