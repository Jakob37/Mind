import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sorted_out/src/features/tasks/data/task_image_attachment_service.dart';
import 'package:sorted_out/src/features/tasks/domain/task_models.dart';

void main() {
  group('TaskImageAttachmentService', () {
    late Directory tempDirectory;
    late TaskImageAttachmentService service;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'task-image-attachment-test-',
      );
      service = TaskImageAttachmentService(
        directoryProvider: () async => tempDirectory,
      );
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('resizes imported images when requested', () async {
      final File sourceFile = File('${tempDirectory.path}/source.png');
      final img.Image sourceImage = img.Image(width: 2400, height: 1200);
      await sourceFile.writeAsBytes(img.encodePng(sourceImage), flush: true);

      final List<String> paths = await service.importSelectedImages(
        <XFile>[XFile(sourceFile.path)],
        resizeOption: TaskImageResizeOption.small,
      );

      expect(paths, hasLength(1));

      final List<int> storedBytes = await File(paths.single).readAsBytes();
      final img.Image? storedImage = img.decodeImage(
        Uint8List.fromList(storedBytes),
      );
      expect(storedImage, isNotNull);
      expect(storedImage!.width, 800);
      expect(storedImage.height, 400);
    });

    test('prunes copied images that are no longer referenced', () async {
      final File keptImage = File('${tempDirectory.path}/keep.png');
      final File removedImage = File('${tempDirectory.path}/remove.png');
      await keptImage.writeAsBytes(<int>[1, 2, 3], flush: true);
      await removedImage.writeAsBytes(<int>[4, 5, 6], flush: true);

      final TaskBoardState state = TaskBoardState(
        incomingTasks: <TaskItem>[
          TaskItem(title: 'Incoming', imagePaths: <String>[keptImage.path]),
        ],
        projects: <ProjectItem>[
          ProjectItem(
            name: 'Project',
            tasks: <TaskItem>[
              TaskItem(
                title: 'Project task',
                imagePaths: <String>[keptImage.path],
              ),
            ],
            entries: <ProjectEntryItem>[
              ProjectEntryItem(
                name: 'Entry',
                tasks: <TaskItem>[
                  TaskItem(
                    title: 'Entry task',
                    imagePaths: <String>[keptImage.path],
                  ),
                ],
              ),
            ],
          ),
        ],
        projectStacks: const <ProjectStack>[],
        projectTypes: ProjectTypeConfig.defaults(),
        colorLabels: const <int, String>{},
        hideCompletedProjectItems: false,
        cardLayoutPreset: CardLayoutPreset.standard,
      );

      await service.pruneUnusedImages(state);

      expect(await keptImage.exists(), isTrue);
      expect(await removedImage.exists(), isFalse);
    });
  });
}
