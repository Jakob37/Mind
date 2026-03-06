import 'package:flutter/material.dart';

import '../../domain/task_models.dart';

class MoveProjectTaskSheet extends StatelessWidget {
  const MoveProjectTaskSheet({
    super.key,
    required this.projects,
    required this.currentProjectIndex,
  });

  final List<ProjectItem> projects;
  final int currentProjectIndex;

  @override
  Widget build(BuildContext context) {
    final List<int> targetIndexes = <int>[
      for (int i = 0; i < projects.length; i++)
        if (i != currentProjectIndex) i,
    ];

    if (targetIndexes.isEmpty) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No other projects available.'),
        ),
      );
    }

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          const ListTile(
            title: Text(
              'Move task to project',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 1),
          for (final int targetIndex in targetIndexes)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(projects[targetIndex].name),
              subtitle: Text(
                '${projects[targetIndex].tasks.length} task${projects[targetIndex].tasks.length == 1 ? '' : 's'}',
              ),
              onTap: () => Navigator.of(context).pop(targetIndex),
            ),
        ],
      ),
    );
  }
}
