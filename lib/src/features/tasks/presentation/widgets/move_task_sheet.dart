import 'package:flutter/material.dart';

import '../../domain/task_models.dart';

class MoveTarget {
  const MoveTarget.favorites() : projectIndex = null;

  const MoveTarget.project(this.projectIndex);

  final int? projectIndex;
}

class MoveTaskSheet extends StatelessWidget {
  const MoveTaskSheet({
    super.key,
    required this.projects,
  });

  final List<ProjectItem> projects;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          const ListTile(
            title: Text(
              'Move task to',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Favorites'),
            onTap: () =>
                Navigator.of(context).pop(const MoveTarget.favorites()),
          ),
          const Divider(height: 1),
          for (int i = 0; i < projects.length; i++)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(projects[i].name),
              subtitle: Text(
                '${projects[i].tasks.length} task${projects[i].tasks.length == 1 ? '' : 's'}',
              ),
              onTap: () => Navigator.of(context).pop(MoveTarget.project(i)),
            ),
        ],
      ),
    );
  }
}
