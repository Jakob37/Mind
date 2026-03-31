import 'package:flutter/material.dart';

class AddProjectEntryResult {
  const AddProjectEntryResult({
    required this.name,
    required this.body,
  });

  final String name;
  final String body;
}

class AddProjectEntrySheet extends StatefulWidget {
  const AddProjectEntrySheet({
    super.key,
    this.itemLabel = 'Person',
    this.notesLabel = 'Notes',
    this.nameFieldLabel = 'Name',
    this.nameHint = 'Name this entry',
    this.notesHint = 'Description or anything useful to remember',
  });

  final String itemLabel;
  final String notesLabel;
  final String nameFieldLabel;
  final String nameHint;
  final String notesHint;

  @override
  State<AddProjectEntrySheet> createState() => _AddProjectEntrySheetState();
}

class _AddProjectEntrySheetState extends State<AddProjectEntrySheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _nameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bodyController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _save() {
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      AddProjectEntryResult(
        name: name,
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
            'New ${widget.itemLabel}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            focusNode: _nameFocusNode,
            autofocus: true,
            minLines: 1,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: widget.nameFieldLabel,
              hintText: widget.nameHint,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: widget.notesLabel,
              hintText: widget.notesHint,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _save,
            child: Text('Create ${widget.itemLabel}'),
          ),
        ],
      ),
    );
  }
}
