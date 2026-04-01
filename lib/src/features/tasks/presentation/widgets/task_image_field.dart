import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../data/task_image_attachment_service.dart';

class TaskImageField extends StatelessWidget {
  const TaskImageField({
    super.key,
    required this.imagePaths,
    required this.onAddImages,
    required this.onRemoveImage,
  });

  final List<String> imagePaths;
  final Future<void> Function() onAddImages;
  final void Function(String imagePath) onRemoveImage;

  String _fileNameFor(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImages = imagePaths.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: onAddImages,
          icon: const Icon(Icons.image_outlined),
          label:
              Text(hasImages ? 'Images (${imagePaths.length})' : 'Add images'),
        ),
        if (hasImages) ...<Widget>[
          const SizedBox(height: 8),
          for (final String imagePath in imagePaths)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text(
                  _fileNameFor(imagePath),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  imagePath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  onPressed: () => onRemoveImage(imagePath),
                  tooltip: 'Remove image',
                  icon: const Icon(Icons.close_outlined),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

Future<List<String>> pickAndImportTaskImages({
  TaskImageAttachmentService service = const TaskImageAttachmentService(),
}) async {
  final List<XFile> files = await openFiles(
    acceptedTypeGroups: const <XTypeGroup>[
      TaskImageAttachmentService.imageTypeGroup,
    ],
    confirmButtonText: 'Attach',
  );
  if (files.isEmpty) {
    return const <String>[];
  }
  return service.importSelectedImages(files);
}
