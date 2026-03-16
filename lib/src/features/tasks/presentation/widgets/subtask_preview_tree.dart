import 'package:flutter/material.dart';

import '../../domain/task_models.dart';
import 'item_icon_picker_sheet.dart';

class SubtaskPreviewTree extends StatefulWidget {
  const SubtaskPreviewTree({
    super.key,
    required this.items,
  });

  final List<SubTaskItem> items;

  @override
  State<SubtaskPreviewTree> createState() => _SubtaskPreviewTreeState();
}

class _SubtaskPreviewTreeState extends State<SubtaskPreviewTree> {
  final Set<String> _expandedSubtaskIds = <String>{};

  @override
  void didUpdateWidget(covariant SubtaskPreviewTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Set<String> validIds = <String>{};
    _collectSubtaskIds(widget.items, validIds);
    _expandedSubtaskIds.removeWhere((String id) => !validIds.contains(id));
  }

  void _collectSubtaskIds(List<SubTaskItem> items, Set<String> ids) {
    for (final SubTaskItem item in items) {
      ids.add(item.id);
      _collectSubtaskIds(item.children, ids);
    }
  }

  void _toggleExpanded(String subTaskId) {
    setState(() {
      if (_expandedSubtaskIds.contains(subTaskId)) {
        _expandedSubtaskIds.remove(subTaskId);
      } else {
        _expandedSubtaskIds.add(subTaskId);
      }
    });
  }

  Widget _buildNode(SubTaskItem subTask, int depth) {
    final bool hasChildren = subTask.children.isNotEmpty;
    final bool isExpanded = _expandedSubtaskIds.contains(subTask.id);
    final IconData? iconData = iconDataForKey(subTask.iconKey);
    final List<Widget> trailingParts = <Widget>[
      if (subTask.body.isNotEmpty)
        const Tooltip(
          message: 'Has text content',
          child: Icon(
            Icons.notes_outlined,
            size: 18,
          ),
        ),
      if (iconData != null)
        Icon(
          iconData,
          size: 18,
        ),
    ];

    return Padding(
      padding: EdgeInsets.only(left: depth * 18.0, top: 4),
      child: Column(
        children: <Widget>[
          Card(
            margin: EdgeInsets.zero,
            color:
                subTask.colorValue == null ? null : Color(subTask.colorValue!),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              leading: hasChildren
                  ? IconButton(
                      onPressed: () => _toggleExpanded(subTask.id),
                      tooltip: isExpanded
                          ? 'Collapse nested ideas'
                          : 'Expand nested ideas',
                      icon: Icon(
                        isExpanded
                            ? Icons.expand_more_outlined
                            : Icons.chevron_right_outlined,
                      ),
                    )
                  : Icon(
                      iconData ?? Icons.subdirectory_arrow_right_outlined,
                      size: 20,
                    ),
              title: Text(
                subTask.title,
                maxLines: null,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              subtitle: subTask.body.isEmpty
                  ? null
                  : Text(
                      subTask.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              trailing: trailingParts.isEmpty
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (int i = 0;
                            i < trailingParts.length;
                            i++) ...<Widget>[
                          if (i > 0) const SizedBox(width: 8),
                          trailingParts[i],
                        ],
                      ],
                    ),
            ),
          ),
          if (hasChildren && isExpanded)
            _buildList(subTask.children, depth + 1),
        ],
      ),
    );
  }

  Widget _buildList(List<SubTaskItem> items, int depth) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: items
          .map((SubTaskItem item) => _buildNode(item, depth))
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildList(widget.items, 0);
  }
}
