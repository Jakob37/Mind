import 'package:flutter/material.dart';
import '../../domain/list_reorder.dart';
import '../../domain/task_models.dart';
import '../task_text_clipboard.dart';
import '../widgets/add_journal_entry_sheet.dart';
import '../widgets/add_task_sheet.dart';
import '../widgets/card_layout.dart';
import '../widgets/edit_person_sheet.dart';
import '../widgets/edit_task_sheet.dart';
import '../widgets/item_color_picker_sheet.dart';
import '../widgets/item_icon_picker_sheet.dart';
import 'task_detail_page.dart';

enum _PersonEntryKind { journal, idea }

enum _PersonMenuAction { edit, setIcon, setColor, remove }

enum _PersonTaskMenuAction {
  open,
  edit,
  setIcon,
  setColor,
  moveToTop,
  moveToBottom,
  remove,
}

class PersonDetailPage extends StatefulWidget {
  const PersonDetailPage({
    super.key,
    required this.personId,
    required this.initialPeople,
    required this.projectType,
    required this.colorLabels,
    required this.hideCompletedProjectItems,
    required this.cardLayoutPreset,
    required this.onPeopleChanged,
  });

  final String personId;
  final List<PersonItem> initialPeople;
  final ProjectTypeConfig projectType;
  final Map<int, String> colorLabels;
  final bool hideCompletedProjectItems;
  final CardLayoutPreset cardLayoutPreset;
  final ValueChanged<List<PersonItem>> onPeopleChanged;

  @override
  State<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends State<PersonDetailPage> {
  late final List<PersonItem> _people;

  @override
  void initState() {
    super.initState();
    _people = widget.initialPeople
        .map((PersonItem person) => person.clone())
        .toList(growable: true);
  }

  CardLayoutSpec get _layout =>
      cardLayoutSpecForPreset(widget.cardLayoutPreset);

  String get _itemLabel => widget.projectType.childItemLabel;
  String get _itemsLabel => widget.projectType.childItemsLabel;
  String get _journalEntryLabel => widget.projectType.childJournalEntryLabel;
  String get _journalEntriesLabel =>
      widget.projectType.childJournalEntriesLabel;

  void _notifyPeopleChanged() {
    widget.onPeopleChanged(
      _people.map((PersonItem person) => person.clone()).toList(),
    );
  }

  PersonItem? _findPerson() {
    for (final PersonItem person in _people) {
      if (person.id == widget.personId) {
        return person;
      }
    }
    return null;
  }

  int _personIndex() {
    return _people.indexWhere(
      (PersonItem person) => person.id == widget.personId,
    );
  }

  int _findTaskIndex(PersonItem person, String taskId) {
    return person.tasks.indexWhere((TaskItem task) => task.id == taskId);
  }

  List<TaskItem> _journalEntries(PersonItem person) {
    return person.tasks
        .where((TaskItem task) => task.entryType == TaskEntryType.journal)
        .toList(growable: false);
  }

  List<TaskItem> _ideaTasks(PersonItem person) {
    return person.tasks
        .where((TaskItem task) => task.entryType != TaskEntryType.journal)
        .toList(growable: false);
  }

  Future<_PersonEntryKind?> _chooseEntryKind() {
    return showModalBottomSheet<_PersonEntryKind>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              const ListTile(
                title: Text(
                  'Create entry',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(_journalEntryLabel),
                onTap: () =>
                    Navigator.of(context).pop(_PersonEntryKind.journal),
              ),
              ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: const Text('Ideas'),
                onTap: () => Navigator.of(context).pop(_PersonEntryKind.idea),
              ),
            ],
          ),
        );
      },
    );
  }

  String _journalTimestampLabel(TaskItem task) {
    final DateTime? createdAt = task.createdAt;
    if (createdAt == null) {
      return task.title;
    }

    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    final String dateLabel = localizations.formatFullDate(createdAt);
    final String timeLabel = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(createdAt),
    );
    return '$dateLabel at $timeLabel';
  }

  String _createJournalEntryTitle(int createdAtMicros) {
    final DateTime createdAt = DateTime.fromMicrosecondsSinceEpoch(
      createdAtMicros,
    );
    final String month = createdAt.month.toString().padLeft(2, '0');
    final String day = createdAt.day.toString().padLeft(2, '0');
    final String hour = createdAt.hour.toString().padLeft(2, '0');
    final String minute = createdAt.minute.toString().padLeft(2, '0');
    return '$_journalEntryLabel ${createdAt.year}-$month-$day $hour:$minute';
  }

  Future<_PersonMenuAction?> _showPersonMenu(PersonItem person) {
    return showModalBottomSheet<_PersonMenuAction>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              ListTile(
                title: Text(
                  person.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('$_itemLabel settings'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text('Edit ${_itemLabel.toLowerCase()}'),
                onTap: () => Navigator.of(context).pop(_PersonMenuAction.edit),
              ),
              ListTile(
                leading: const Icon(Icons.add_reaction_outlined),
                title: const Text('Set icon'),
                onTap: () =>
                    Navigator.of(context).pop(_PersonMenuAction.setIcon),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Set color'),
                onTap: () =>
                    Navigator.of(context).pop(_PersonMenuAction.setColor),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text('Remove ${_itemLabel.toLowerCase()}'),
                onTap: () =>
                    Navigator.of(context).pop(_PersonMenuAction.remove),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_PersonTaskMenuAction?> _showTaskMenu(TaskItem task) {
    return showModalBottomSheet<_PersonTaskMenuAction>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              ListTile(
                title: Text(
                  task.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Task options'),
                trailing: IconButton(
                  tooltip: 'Copy task text',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () {
                    Navigator.of(context).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      copyTaskTextToClipboard(this.context, task);
                    });
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.open_in_new_outlined),
                title: const Text('Open task'),
                onTap: () =>
                    Navigator.of(context).pop(_PersonTaskMenuAction.open),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit task'),
                onTap: () =>
                    Navigator.of(context).pop(_PersonTaskMenuAction.edit),
              ),
              ListTile(
                leading: const Icon(Icons.add_reaction_outlined),
                title: const Text('Set icon'),
                onTap: () =>
                    Navigator.of(context).pop(_PersonTaskMenuAction.setIcon),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Set color'),
                onTap: () =>
                    Navigator.of(context).pop(_PersonTaskMenuAction.setColor),
              ),
              ListTile(
                leading: const Icon(Icons.vertical_align_top_outlined),
                title: const Text('Move to top'),
                onTap: () =>
                    Navigator.of(context).pop(_PersonTaskMenuAction.moveToTop),
              ),
              ListTile(
                leading: const Icon(Icons.vertical_align_bottom_outlined),
                title: const Text('Move to bottom'),
                onTap: () => Navigator.of(
                  context,
                ).pop(_PersonTaskMenuAction.moveToBottom),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove task'),
                onTap: () =>
                    Navigator.of(context).pop(_PersonTaskMenuAction.remove),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openPersonSettings() async {
    final PersonItem? person = _findPerson();
    if (person == null) {
      return;
    }

    final _PersonMenuAction? action = await _showPersonMenu(person);
    if (action == null || !mounted) {
      return;
    }

    if (action == _PersonMenuAction.edit) {
      await _editPerson();
      return;
    }
    if (action == _PersonMenuAction.setIcon) {
      await _setPersonIcon();
      return;
    }
    if (action == _PersonMenuAction.setColor) {
      await _setPersonColor();
      return;
    }
    if (action == _PersonMenuAction.remove) {
      _removePerson();
    }
  }

  Future<void> _editPerson() async {
    final int personIndex = _personIndex();
    if (personIndex < 0) {
      return;
    }

    final PersonItem person = _people[personIndex];
    final PersonEditResult? result =
        await showModalBottomSheet<PersonEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditPersonSheet(
        initialName: person.name,
        initialBody: person.body,
        itemLabel: _itemLabel,
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _people[personIndex] = person.copyWith(
        name: result.name,
        body: result.body,
      );
    });
    _notifyPeopleChanged();
  }

  Future<void> _setPersonIcon() async {
    final int personIndex = _personIndex();
    if (personIndex < 0) {
      return;
    }
    final PersonItem person = _people[personIndex];

    final String? iconKey = await showModalBottomSheet<String?>(
      context: context,
      builder: (_) => ItemIconPickerSheet(currentIconKey: person.iconKey),
    );
    if (!mounted || iconKey == person.iconKey) {
      return;
    }

    setState(() {
      _people[personIndex] = person.copyWith(
        iconKey: iconKey,
        clearIcon: iconKey == null,
      );
    });
    _notifyPeopleChanged();
  }

  Future<void> _setPersonColor() async {
    final int personIndex = _personIndex();
    if (personIndex < 0) {
      return;
    }
    final PersonItem person = _people[personIndex];

    final ColorSelection? selection =
        await showModalBottomSheet<ColorSelection>(
      context: context,
      builder: (_) => ItemColorPickerSheet(
        currentColorValue: person.colorValue,
        customLabels: widget.colorLabels,
      ),
    );
    if (selection == null) {
      return;
    }

    setState(() {
      _people[personIndex] = person.copyWith(
        colorValue: selection.colorValue,
        clearColor: selection.colorValue == null,
      );
    });
    _notifyPeopleChanged();
  }

  void _removePerson() {
    final int personIndex = _personIndex();
    if (personIndex < 0) {
      return;
    }

    setState(() {
      _people.removeAt(personIndex);
    });
    _notifyPeopleChanged();
    Navigator.of(context).pop();
  }

  Future<void> _addEntry() async {
    final _PersonEntryKind? kind = await _chooseEntryKind();
    if (kind == null || !mounted) {
      return;
    }

    if (kind == _PersonEntryKind.journal) {
      final AddJournalEntryResult? result =
          await showModalBottomSheet<AddJournalEntryResult>(
        context: context,
        isScrollControlled: true,
        builder: (_) => AddJournalEntrySheet(
          title: 'New $_journalEntryLabel',
          hintText:
              'Capture what happened, what mattered, and what to remember.',
          saveLabel: 'Save $_journalEntryLabel',
        ),
      );
      if (result == null) {
        return;
      }

      final PersonItem? person = _findPerson();
      if (person == null) {
        return;
      }
      final int taskInsertIndex = _personIndex();
      if (taskInsertIndex < 0) {
        return;
      }

      setState(() {
        _people[taskInsertIndex] = person.copyWith(
          tasks: <TaskItem>[
            ...person.tasks.map((TaskItem task) => task.clone()),
            TaskItem(
              title: _createJournalEntryTitle(result.createdAtMicros),
              body: result.body,
              type: TaskItemType.thinking,
              entryType: TaskEntryType.journal,
              createdAtMicros: result.createdAtMicros,
            ),
          ],
        );
      });
      _notifyPeopleChanged();
      return;
    }

    final AddTaskResult? createdTask =
        await showModalBottomSheet<AddTaskResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddTaskSheet(),
    );
    if (createdTask == null) {
      return;
    }

    final int personIndex = _personIndex();
    if (personIndex < 0) {
      return;
    }
    final PersonItem person = _people[personIndex];
    final List<TaskItem> updatedTasks = person.tasks
        .map((TaskItem task) => task.clone())
        .toList(growable: true);
    final TaskItem ideaTask = createdTask.task.copyWith(
      type: TaskItemType.thinking,
      entryType: TaskEntryType.note,
    );
    if (createdTask.insertAtTop) {
      updatedTasks.insert(0, ideaTask);
    } else {
      updatedTasks.add(ideaTask);
    }
    setState(() {
      _people[personIndex] = person.copyWith(tasks: updatedTasks);
    });
    _notifyPeopleChanged();
  }

  Future<void> _openTaskView(String taskId) async {
    final PersonItem? person = _findPerson();
    if (person == null) {
      return;
    }

    final int taskIndex = _findTaskIndex(person, taskId);
    if (taskIndex < 0) {
      return;
    }

    final TaskItem task = person.tasks[taskIndex];
    final TaskDetailAction? action =
        await Navigator.of(context).push<TaskDetailAction>(
      MaterialPageRoute<TaskDetailAction>(
        builder: (_) => TaskDetailPage(
          task: task,
          cardLayoutPreset: widget.cardLayoutPreset,
          colorLabels: widget.colorLabels,
          hideCompletedProjectItems: widget.hideCompletedProjectItems,
          onTaskChanged: (TaskItem updatedTask) {
            final int activePersonIndex = _personIndex();
            if (activePersonIndex < 0) {
              return;
            }
            final PersonItem activePerson = _people[activePersonIndex];
            final int sourceTaskIndex = _findTaskIndex(activePerson, taskId);
            if (sourceTaskIndex < 0) {
              return;
            }
            final List<TaskItem> tasks = activePerson.tasks
                .map((TaskItem item) => item.clone())
                .toList(growable: true);
            tasks[sourceTaskIndex] = updatedTask.clone();
            setState(() {
              _people[activePersonIndex] = activePerson.copyWith(tasks: tasks);
            });
            _notifyPeopleChanged();
          },
          menuItems: const <TaskDetailMenuItem>[
            TaskDetailMenuItem(
              action: TaskDetailAction.edit,
              icon: Icons.edit_outlined,
              label: 'Edit task',
            ),
            TaskDetailMenuItem(
              action: TaskDetailAction.setIcon,
              icon: Icons.add_reaction_outlined,
              label: 'Set icon',
            ),
            TaskDetailMenuItem(
              action: TaskDetailAction.setColor,
              icon: Icons.palette_outlined,
              label: 'Set color',
            ),
            TaskDetailMenuItem(
              action: TaskDetailAction.remove,
              icon: Icons.delete_outline,
              label: 'Remove task',
            ),
          ],
        ),
      ),
    );

    if (action == null || !mounted) {
      return;
    }

    if (action == TaskDetailAction.edit) {
      await _editTask(taskId);
      return;
    }
    if (action == TaskDetailAction.setIcon) {
      await _setTaskIcon(taskId);
      return;
    }
    if (action == TaskDetailAction.setColor) {
      await _setTaskColor(taskId);
      return;
    }
    if (action == TaskDetailAction.remove) {
      _removeTask(taskId);
    }
  }

  Future<void> _openTaskMenu(String taskId) async {
    final PersonItem? person = _findPerson();
    if (person == null) {
      return;
    }

    final int taskIndex = _findTaskIndex(person, taskId);
    if (taskIndex < 0) {
      return;
    }

    final _PersonTaskMenuAction? action = await _showTaskMenu(
      person.tasks[taskIndex],
    );
    if (action == null || !mounted) {
      return;
    }

    if (action == _PersonTaskMenuAction.open) {
      await _openTaskView(taskId);
      return;
    }
    if (action == _PersonTaskMenuAction.edit) {
      await _editTask(taskId);
      return;
    }
    if (action == _PersonTaskMenuAction.setIcon) {
      await _setTaskIcon(taskId);
      return;
    }
    if (action == _PersonTaskMenuAction.setColor) {
      await _setTaskColor(taskId);
      return;
    }
    if (action == _PersonTaskMenuAction.moveToTop) {
      _moveTaskToBoundary(taskId, toTop: true);
      return;
    }
    if (action == _PersonTaskMenuAction.moveToBottom) {
      _moveTaskToBoundary(taskId, toTop: false);
      return;
    }
    if (action == _PersonTaskMenuAction.remove) {
      _removeTask(taskId);
    }
  }

  Future<void> _editTask(String taskId) async {
    final int personIndex = _personIndex();
    if (personIndex < 0) {
      return;
    }
    final PersonItem person = _people[personIndex];
    final int taskIndex = _findTaskIndex(person, taskId);
    if (taskIndex < 0) {
      return;
    }

    final TaskItem task = person.tasks[taskIndex];
    final TaskEditResult? result = await showModalBottomSheet<TaskEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditTaskSheet(
        initialTitle: task.title,
        initialBody: task.body,
        initialFlashcardPrompt: task.flashcardPrompt,
        showFlashcardField: true,
      ),
    );
    if (result == null) {
      return;
    }

    final List<TaskItem> tasks = person.tasks
        .map((TaskItem item) => item.clone())
        .toList(growable: true);
    tasks[taskIndex] = task.copyWith(
      title: result.title,
      body: result.body,
      flashcardPrompt: result.flashcardPrompt,
    );
    setState(() {
      _people[personIndex] = person.copyWith(tasks: tasks);
    });
    _notifyPeopleChanged();
  }

  Future<void> _setTaskIcon(String taskId) async {
    final int personIndex = _personIndex();
    if (personIndex < 0) {
      return;
    }
    final PersonItem person = _people[personIndex];
    final int taskIndex = _findTaskIndex(person, taskId);
    if (taskIndex < 0) {
      return;
    }
    final TaskItem task = person.tasks[taskIndex];

    final String? iconKey = await showModalBottomSheet<String?>(
      context: context,
      builder: (_) => ItemIconPickerSheet(currentIconKey: task.iconKey),
    );
    if (!mounted || iconKey == task.iconKey) {
      return;
    }

    final List<TaskItem> tasks = person.tasks
        .map((TaskItem item) => item.clone())
        .toList(growable: true);
    tasks[taskIndex] = task.copyWith(
      iconKey: iconKey,
      clearIcon: iconKey == null,
    );
    setState(() {
      _people[personIndex] = person.copyWith(tasks: tasks);
    });
    _notifyPeopleChanged();
  }

  Future<void> _setTaskColor(String taskId) async {
    final int personIndex = _personIndex();
    if (personIndex < 0) {
      return;
    }
    final PersonItem person = _people[personIndex];
    final int taskIndex = _findTaskIndex(person, taskId);
    if (taskIndex < 0) {
      return;
    }
    final TaskItem task = person.tasks[taskIndex];

    final ColorSelection? selection =
        await showModalBottomSheet<ColorSelection>(
      context: context,
      builder: (_) => ItemColorPickerSheet(
        currentColorValue: task.colorValue,
        customLabels: widget.colorLabels,
      ),
    );
    if (selection == null) {
      return;
    }

    final List<TaskItem> tasks = person.tasks
        .map((TaskItem item) => item.clone())
        .toList(growable: true);
    tasks[taskIndex] = task.copyWith(
      colorValue: selection.colorValue,
      clearColor: selection.colorValue == null,
    );
    setState(() {
      _people[personIndex] = person.copyWith(tasks: tasks);
    });
    _notifyPeopleChanged();
  }

  void _removeTask(String taskId) {
    final int personIndex = _personIndex();
    if (personIndex < 0) {
      return;
    }
    final PersonItem person = _people[personIndex];
    final List<TaskItem> tasks = person.tasks
        .map((TaskItem item) => item.clone())
        .toList(growable: true);
    tasks.removeWhere((TaskItem task) => task.id == taskId);
    setState(() {
      _people[personIndex] = person.copyWith(tasks: tasks);
    });
    _notifyPeopleChanged();
  }

  void _moveTaskToBoundary(String taskId, {required bool toTop}) {
    final int personIndex = _personIndex();
    if (personIndex < 0) {
      return;
    }
    final PersonItem person = _people[personIndex];
    final int taskIndex = _findTaskIndex(person, taskId);
    if (taskIndex < 0) {
      return;
    }

    final TaskItem task = person.tasks[taskIndex];
    final List<TaskItem> journalEntries = _journalEntries(
      person,
    ).toList(growable: true);
    final List<TaskItem> ideaTasks = _ideaTasks(person).toList(growable: true);
    final List<TaskItem> targetList =
        task.entryType == TaskEntryType.journal ? journalEntries : ideaTasks;
    final int sourceIndex = targetList.indexWhere(
      (TaskItem entry) => entry.id == taskId,
    );
    if (sourceIndex < 0) {
      return;
    }

    if (!moveItemToBoundary(
      targetList,
      sourceIndex: sourceIndex,
      toTop: toTop,
    )) {
      return;
    }

    setState(() {
      _people[personIndex] = person.copyWith(
        tasks: <TaskItem>[...journalEntries, ...ideaTasks],
      );
    });
    _notifyPeopleChanged();
  }

  Widget _buildJournalCard(TaskItem task) {
    return Card(
      margin: EdgeInsets.only(bottom: _layout.listBottomSpacing),
      color: task.colorValue == null ? null : Color(task.colorValue!),
      child: ListTile(
        contentPadding: _layout.contentPadding,
        leading: Icon(iconDataForKey(task.iconKey) ?? Icons.menu_book_outlined),
        title: Text(_journalTimestampLabel(task), maxLines: null),
        subtitle: Text(task.body.trim().isEmpty ? task.title : task.body),
        trailing: IconButton(
          onPressed: () => _openTaskMenu(task.id),
          tooltip: 'Task options',
          icon: const Icon(Icons.more_vert),
        ),
        onTap: () => _openTaskView(task.id),
      ),
    );
  }

  Widget _buildIdeaCard(TaskItem task) {
    return Card(
      margin: EdgeInsets.only(bottom: _layout.listBottomSpacing),
      color: task.colorValue == null ? null : Color(task.colorValue!),
      child: ListTile(
        contentPadding: _layout.contentPadding,
        leading: Icon(iconDataForKey(task.iconKey) ?? Icons.lightbulb_outline),
        title: Text(task.title, maxLines: null),
        subtitle: task.body.trim().isEmpty ? null : Text(task.body),
        trailing: IconButton(
          onPressed: () => _openTaskMenu(task.id),
          tooltip: 'Task options',
          icon: const Icon(Icons.more_vert),
        ),
        onTap: () => _openTaskView(task.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PersonItem? person = _findPerson();
    if (person == null) {
      return Scaffold(
        body: Center(child: Text('$_itemLabel not found.')),
      );
    }

    final List<TaskItem> journalEntries = _journalEntries(person);
    final List<TaskItem> ideaTasks = _ideaTasks(person);
    final IconData? personIcon = iconDataForKey(person.iconKey);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            if (personIcon != null) ...<Widget>[
              Icon(personIcon),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(person.name)),
          ],
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _openPersonSettings,
            tooltip: '$_itemLabel settings',
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          12,
          12,
          12,
          104 + MediaQuery.paddingOf(context).bottom,
        ),
        children: <Widget>[
          if (person.body.trim().isNotEmpty)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  person.body,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          Text(
            _journalEntriesLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final TaskItem task in journalEntries) _buildJournalCard(task),
          const SizedBox(height: 8),
          Text('Ideas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final TaskItem task in ideaTasks) _buildIdeaCard(task),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        tooltip: 'Add ${_journalEntryLabel.toLowerCase()} or idea',
        child: const Icon(Icons.add),
      ),
    );
  }
}
