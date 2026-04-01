import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../data/task_image_attachment_service.dart';

class TaskImageField extends StatelessWidget {
  const TaskImageField({
    super.key,
    required this.imagePaths,
    required this.resizeOption,
    required this.onAddImages,
    required this.onRemoveImage,
    required this.onResizeOptionChanged,
  });

  final List<String> imagePaths;
  final TaskImageResizeOption resizeOption;
  final Future<void> Function() onAddImages;
  final void Function(String imagePath) onRemoveImage;
  final ValueChanged<TaskImageResizeOption> onResizeOptionChanged;

  String _fileNameFor(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImages = imagePaths.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DropdownButtonFormField<TaskImageResizeOption>(
          value: resizeOption,
          decoration: const InputDecoration(labelText: 'Image size'),
          items: TaskImageResizeOption.values
              .map(
                (TaskImageResizeOption option) =>
                    DropdownMenuItem<TaskImageResizeOption>(
                  value: option,
                  child: Text(option.label),
                ),
              )
              .toList(growable: false),
          onChanged: (TaskImageResizeOption? value) {
            if (value != null) {
              onResizeOptionChanged(value);
            }
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onAddImages,
          icon: const Icon(Icons.image_outlined),
          label: Text(
            hasImages
                ? 'Images (${imagePaths.length}) - ${resizeOption.label}'
                : 'Add images (${resizeOption.label})',
          ),
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
  TaskImageResizeOption resizeOption = TaskImageResizeOption.original,
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
  return service.importSelectedImages(files, resizeOption: resizeOption);
}
