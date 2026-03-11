import 'package:flutter/material.dart';

import '../../domain/task_models.dart';
import 'item_icon_picker_sheet.dart';

class EditProjectTypeSheet extends StatefulWidget {
  const EditProjectTypeSheet({
    super.key,
    required this.projectType,
  });

  final ProjectTypeConfig projectType;

  @override
  State<EditProjectTypeSheet> createState() => _EditProjectTypeSheetState();
}

class _EditProjectTypeSheetState extends State<EditProjectTypeSheet> {
  late bool _showsIdeas;
  late bool _showsPlanningTasks;
  late String? _iconKey;

  @override
  void initState() {
    super.initState();
    _showsIdeas = widget.projectType.showsIdeas;
    _showsPlanningTasks = widget.projectType.showsPlanningTasks;
    _iconKey = widget.projectType.iconKey;
  }

  Future<void> _pickIcon() async {
    final String? iconKey = await showModalBottomSheet<String?>(
      context: context,
      builder: (_) => ItemIconPickerSheet(
        currentIconKey: _iconKey,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _iconKey = iconKey;
    });
  }

  void _save() {
    Navigator.of(context).pop(
      widget.projectType.copyWith(
        iconKey: _iconKey,
        clearIcon: _iconKey == null,
        showsIdeas: _showsIdeas,
        showsPlanningTasks: _showsPlanningTasks,
      ),
    );
  }

  String _iconLabel() {
    final String? label = iconLabelForKey(_iconKey);
    if (label == null || label.isEmpty) {
      return 'No icon';
    }
    return label;
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
            widget.projectType.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickIcon,
            icon: Icon(iconDataForKey(_iconKey) ?? Icons.label_outline),
            label: Text('Icon: ${_iconLabel()}'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show ideas section'),
            value: _showsIdeas,
            onChanged: (bool value) {
              setState(() {
                _showsIdeas = value;
              });
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show tasks section'),
            value: _showsPlanningTasks,
            onChanged: (bool value) {
              setState(() {
                _showsPlanningTasks = value;
              });
            },
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _save,
            child: const Text('Save Project Type'),
          ),
        ],
      ),
    );
  }
}
