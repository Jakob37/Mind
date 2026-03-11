import 'package:flutter/material.dart';

class AddSessionResult {
  const AddSessionResult({
    required this.title,
    required this.body,
    required this.insertAtTop,
  });

  final String title;
  final String body;
  final bool insertAtTop;
}

class AddSessionSheet extends StatefulWidget {
  const AddSessionSheet({super.key});

  @override
  State<AddSessionSheet> createState() => _AddSessionSheetState();
}

class _AddSessionSheetState extends State<AddSessionSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  bool _insertAtTop = true;

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

  void _saveSession() {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      AddSessionResult(
        title: title,
        body: _bodyController.text.trim(),
        insertAtTop: _insertAtTop,
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
            'New Session',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Session title',
              hintText: 'Podcast, chapter, article, or lesson',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            minLines: 2,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'Context',
              hintText: 'Optional source details or focus for this session',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const <ButtonSegment<bool>>[
              ButtonSegment<bool>(
                value: true,
                label: Text('Add at top'),
                icon: Icon(Icons.vertical_align_top_outlined),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text('Add at bottom'),
                icon: Icon(Icons.vertical_align_bottom_outlined),
              ),
            ],
            selected: <bool>{_insertAtTop},
            onSelectionChanged: (Set<bool> selection) {
              setState(() {
                _insertAtTop = selection.first;
              });
            },
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saveSession,
            child: const Text('Create Session'),
          ),
        ],
      ),
    );
  }
}
