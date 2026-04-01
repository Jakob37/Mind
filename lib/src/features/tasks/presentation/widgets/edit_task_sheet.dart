import 'package:flutter/material.dart';

import 'task_image_field.dart';

class TaskEditResult {
  const TaskEditResult({
    required this.title,
    required this.body,
    required this.prompt,
    required this.flashcardPrompt,
    required this.imagePaths,
  });

  final String title;
  final String body;
  final String prompt;
  final String flashcardPrompt;
  final List<String> imagePaths;
}

class EditTaskSheet extends StatefulWidget {
  const EditTaskSheet({
    super.key,
    required this.initialTitle,
    required this.initialBody,
    this.initialPrompt = '',
    this.initialFlashcardPrompt = '',
    this.initialImagePaths = const <String>[],
    this.showPromptField = false,
    this.showFlashcardField = false,
  });

  final String initialTitle;
  final String initialBody;
  final String initialPrompt;
  final String initialFlashcardPrompt;
  final List<String> initialImagePaths;
  final bool showPromptField;
  final bool showFlashcardField;

  @override
  State<EditTaskSheet> createState() => _EditTaskSheetState();
}

class _EditTaskSheetState extends State<EditTaskSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _promptController;
  late final TextEditingController _flashcardPromptController;
  late final List<String> _imagePaths;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _bodyController = TextEditingController(text: widget.initialBody);
    _promptController = TextEditingController(text: widget.initialPrompt);
    _flashcardPromptController = TextEditingController(
      text: widget.initialFlashcardPrompt,
    );
    _imagePaths = List<String>.from(widget.initialImagePaths);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _promptController.dispose();
    _flashcardPromptController.dispose();
    super.dispose();
  }

  void _save() {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      TaskEditResult(
        title: title,
        body: _bodyController.text.trim(),
        prompt: _promptController.text.trim(),
        flashcardPrompt: _flashcardPromptController.text.trim(),
        imagePaths: List<String>.from(_imagePaths),
      ),
    );
  }

  Future<void> _addImages() async {
    final List<String> importedPaths = await pickAndImportTaskImages();
    if (!mounted || importedPaths.isEmpty) {
      return;
    }
    setState(() {
      _imagePaths.addAll(importedPaths);
    });
  }

  void _removeImage(String imagePath) {
    setState(() {
      _imagePaths.remove(imagePath);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Edit Task', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            textInputAction: TextInputAction.newline,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Title',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Body',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TaskImageField(
            imagePaths: _imagePaths,
            onAddImages: _addImages,
            onRemoveImage: _removeImage,
          ),
          if (widget.showPromptField) ...<Widget>[
            const SizedBox(height: 12),
            TextField(
              controller: _promptController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Prompt',
                alignLabelWithHint: true,
              ),
            ),
          ],
          if (widget.showFlashcardField) ...<Widget>[
            const SizedBox(height: 12),
            TextField(
              controller: _flashcardPromptController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Flashcard prompt',
                alignLabelWithHint: true,
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(onPressed: _save, child: const Text('Save Task')),
        ],
      ),
    );
  }
}
