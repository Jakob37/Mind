import 'package:flutter/material.dart';

import '../../domain/task_models.dart';
import 'item_icon_picker_sheet.dart';

class SelectProjectTypeSheet extends StatelessWidget {
  const SelectProjectTypeSheet({
    super.key,
    required this.projectTypes,
    required this.currentProjectTypeId,
    this.title = 'Select Project Type',
  });

  final List<ProjectTypeConfig> projectTypes;
  final String? currentProjectTypeId;
  final String title;

  String _behaviorLabel(ProjectTypeConfig type) {
    if (type.showsIdeas && type.showsPlanningTasks) {
      return 'Ideas and tasks';
    }
    if (type.showsIdeas) {
      return 'Ideas only';
    }
    if (type.showsPlanningTasks) {
      return 'Tasks only';
    }
    return 'Blank';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          ListTile(
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 1),
          for (final ProjectTypeConfig type in projectTypes)
            ListTile(
              leading: Icon(
                iconDataForKey(type.iconKey) ??
                    Icons.label_outline,
              ),
              title: Text(type.name),
              subtitle: Text(_behaviorLabel(type)),
              trailing: currentProjectTypeId == type.id
                  ? const Icon(Icons.check_outlined)
                  : null,
              onTap: () => Navigator.of(context).pop<String>(type.id),
            ),
        ],
      ),
    );
  }
}
