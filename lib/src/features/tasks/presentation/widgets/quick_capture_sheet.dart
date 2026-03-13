import 'package:flutter/material.dart';

class QuickCaptureResult {
  const QuickCaptureResult({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

class QuickCaptureSheet extends StatefulWidget {
  const QuickCaptureSheet({
    super.key,
    required this.sessionTitle,
  });

  final String sessionTitle;

  @override
  State<QuickCaptureSheet> createState() => _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends State<QuickCaptureSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _titleFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _saveCapture() {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      QuickCaptureResult(
        title: title,
        body: _bodyController.text.trim(),
      ),
    );
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
          Text(
            'Quick Capture',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Capturing into ${widget.sessionTitle}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            autofocus: true,
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Capture',
              alignLabelWithHint: true,
              hintText: 'Key idea, quote, question, or connection',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'Details',
              hintText: 'Optional context while it is still fresh',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saveCapture,
            child: const Text('Save Capture'),
          ),
        ],
      ),
    );
  }
}
