import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

class TaskImageAttachmentService {
  const TaskImageAttachmentService({
    Future<Directory> Function()? directoryProvider,
  }) : _directoryProvider = directoryProvider;

  final Future<Directory> Function()? _directoryProvider;

  static const XTypeGroup imageTypeGroup = XTypeGroup(
    label: 'images',
    extensions: <String>[
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
      'heic',
      'heif',
    ],
  );

  Future<List<String>> importSelectedImages(List<XFile> files) async {
    if (files.isEmpty) {
      return const <String>[];
    }

    final Directory directory = await _attachmentDirectory();
    await directory.create(recursive: true);

    final List<String> importedPaths = <String>[];
    for (final XFile file in files) {
      final List<int> bytes = await file.readAsBytes();
      final String fileName = _buildFileName(file);
      final File storedFile = File('${directory.path}/$fileName');
      await storedFile.writeAsBytes(bytes, flush: true);
      importedPaths.add(storedFile.path);
    }
    return importedPaths;
  }

  Future<Directory> _attachmentDirectory() async {
    final Future<Directory> Function()? directoryProvider = _directoryProvider;
    if (directoryProvider != null) {
      return directoryProvider();
    }

    final Directory supportDirectory = await getApplicationSupportDirectory();
    return Directory('${supportDirectory.path}/task_images');
  }

  String _buildFileName(XFile file) {
    final String sourceName = file.name.trim().isNotEmpty
        ? file.name.trim()
        : file.path.split(Platform.pathSeparator).last.trim();
    final String extension = _extensionFor(sourceName);
    final String timestamp = DateTime.now().microsecondsSinceEpoch.toString();
    return 'task-image-$timestamp$extension';
  }

  String _extensionFor(String fileName) {
    final int dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == fileName.length - 1) {
      return '.img';
    }
    return fileName.substring(dotIndex).toLowerCase();
  }
}
