import 'dart:io';

import 'package:flutter/material.dart';

class TaskImageGallery extends StatelessWidget {
  const TaskImageGallery({
    super.key,
    required this.imagePaths,
    this.height = 120,
  });

  final List<String> imagePaths;
  final double height;

  @override
  Widget build(BuildContext context) {
    final List<String> visiblePaths = imagePaths
        .map((String path) => path.trim())
        .where((String path) => path.isNotEmpty)
        .toList(growable: false);
    if (visiblePaths.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visiblePaths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final String path = visiblePaths[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 1,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
