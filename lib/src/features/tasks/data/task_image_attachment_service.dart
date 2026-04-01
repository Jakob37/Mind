import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../domain/task_models.dart';

enum TaskImageResizeOption {
  original('Original'),
  large('Large'),
  medium('Medium'),
  small('Small');

  const TaskImageResizeOption(this.label);

  final String label;

  int? get maxDimension {
    return switch (this) {
      TaskImageResizeOption.original => null,
      TaskImageResizeOption.large => 1920,
      TaskImageResizeOption.medium => 1280,
      TaskImageResizeOption.small => 800,
    };
  }
}

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

  Future<List<String>> importSelectedImages(
    List<XFile> files, {
    TaskImageResizeOption resizeOption = TaskImageResizeOption.original,
  }) async {
    if (files.isEmpty) {
      return const <String>[];
    }

    final Directory directory = await _attachmentDirectory();
    await directory.create(recursive: true);

    final List<String> importedPaths = <String>[];
    for (final XFile file in files) {
      final List<int> bytes = await file.readAsBytes();
      final List<int> storedBytes = _resizeBytesIfNeeded(
        bytes: bytes,
        sourceName: file.name,
        resizeOption: resizeOption,
      );
      final String fileName = _buildFileName(file);
      final File storedFile = File('${directory.path}/$fileName');
      await storedFile.writeAsBytes(storedBytes, flush: true);
      importedPaths.add(storedFile.path);
    }
    return importedPaths;
  }

  Future<void> pruneUnusedImages(TaskBoardState state) async {
    final Directory directory = await _attachmentDirectory();
    if (!await directory.exists()) {
      return;
    }

    final Set<String> referencedPaths = _referencedImagePaths(state);
    final List<FileSystemEntity> entities =
        directory.listSync(followLinks: false);
    for (final FileSystemEntity entity in entities) {
      if (entity is! File) {
        continue;
      }
      final String path = entity.path;
      if (!referencedPaths.contains(path)) {
        await entity.delete();
      }
    }
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

  List<int> _resizeBytesIfNeeded({
    required List<int> bytes,
    required String sourceName,
    required TaskImageResizeOption resizeOption,
  }) {
    final int? maxDimension = resizeOption.maxDimension;
    if (maxDimension == null) {
      return bytes;
    }

    final img.Image? decoded = img.decodeImage(Uint8List.fromList(bytes));
    if (decoded == null) {
      return bytes;
    }

    final int longestSide = math.max(decoded.width, decoded.height);
    if (longestSide <= maxDimension) {
      return bytes;
    }

    final img.Image resized = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: maxDimension)
        : img.copyResize(decoded, height: maxDimension);

    final String extension = _extensionFor(sourceName);
    return switch (extension) {
      '.jpg' || '.jpeg' => img.encodeJpg(resized, quality: 82),
      '.png' => img.encodePng(resized, level: 6),
      '.gif' => img.encodeGif(resized),
      '.bmp' => img.encodeBmp(resized),
      _ => bytes,
    };
  }

  Set<String> _referencedImagePaths(TaskBoardState state) {
    final Set<String> imagePaths = <String>{};
    void addTaskImages(Iterable<TaskItem> tasks) {
      for (final TaskItem task in tasks) {
        imagePaths.addAll(
          task.imagePaths
              .map((String path) => path.trim())
              .where((String path) => path.isNotEmpty),
        );
      }
    }

    addTaskImages(state.incomingTasks);
    for (final ProjectItem project in state.projects) {
      addTaskImages(project.tasks);
      for (final ProjectEntryItem entry in project.entries) {
        addTaskImages(entry.tasks);
      }
    }
    return imagePaths;
  }
}
