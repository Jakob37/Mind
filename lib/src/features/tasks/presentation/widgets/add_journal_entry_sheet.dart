import 'package:flutter/material.dart';

class AddJournalEntryResult {
  const AddJournalEntryResult({
    required this.body,
    required this.createdAtMicros,
  });

  final String body;
  final int createdAtMicros;
}

class AddJournalEntrySheet extends StatefulWidget {
  const AddJournalEntrySheet({
    super.key,
    this.title = 'New Journal Entry',
    this.hintText = 'Write what happened, what you noticed, or what matters.',
    this.saveLabel = 'Save Entry',
  });

  final String title;
  final String hintText;
  final String saveLabel;

  @override
  State<AddJournalEntrySheet> createState() => _AddJournalEntrySheetState();
}

class _AddJournalEntrySheetState extends State<AddJournalEntrySheet> {
  final TextEditingController _bodyController = TextEditingController();
  final FocusNode _bodyFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _bodyFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _bodyController.dispose();
    _bodyFocusNode.dispose();
    super.dispose();
  }

  void _save() {
    final String body = _bodyController.text.trim();
    if (body.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      AddJournalEntryResult(
        body: body,
        createdAtMicros: DateTime.now().microsecondsSinceEpoch,
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
            widget.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            focusNode: _bodyFocusNode,
            autofocus: true,
            minLines: 5,
            maxLines: 10,
            decoration: InputDecoration(
              labelText: 'Entry',
              alignLabelWithHint: true,
              hintText: widget.hintText,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _save,
            child: Text(widget.saveLabel),
          ),
        ],
      ),
    );
  }
}
