class ModelIds {
  static int _counter = 0;

  static String newTaskId() => _newId('task');

  static String newSubTaskId() => _newId('subtask');

  static String newProjectId() => _newId('project');

  static String newPersonId() => _newId('person');

  static String newProjectEntryId() => _newId('entry');

  static String newProjectStackId() => _newId('stack');

  static String newProjectTypeId() => _newId('project-type');

  static String _newId(String prefix) {
    final int micros = DateTime.now().microsecondsSinceEpoch;
    _counter += 1;
    return '$prefix-${micros.toRadixString(36)}-${_counter.toRadixString(36)}';
  }
}

enum TaskItemType {
  thinking,
  planning;

  static TaskItemType fromJsonValue(Object? rawValue) {
    if (rawValue is! String) {
      return TaskItemType.planning;
    }

    return switch (rawValue.trim().toLowerCase()) {
      'thinking' || 'idea' || 'ideas' => TaskItemType.thinking,
      _ => TaskItemType.planning,
    };
  }
}

enum TaskEntryType {
  note,
  session,
  journal;

  static TaskEntryType fromJsonValue(Object? rawValue) {
    if (rawValue is! String) {
      return TaskEntryType.note;
    }

    return switch (rawValue.trim().toLowerCase()) {
      'session' => TaskEntryType.session,
      'journal' || 'diary' => TaskEntryType.journal,
      _ => TaskEntryType.note,
    };
  }
}

enum CardLayoutPreset {
  compact,
  standard,
  comfortable;

  static CardLayoutPreset fromJsonValue(Object? rawValue) {
    if (rawValue is! String) {
      return CardLayoutPreset.standard;
    }

    return switch (rawValue.trim().toLowerCase()) {
      'compact' => CardLayoutPreset.compact,
      'comfortable' => CardLayoutPreset.comfortable,
      _ => CardLayoutPreset.standard,
    };
  }
}

class SubTaskItem {
  SubTaskItem({
    String? id,
    required this.title,
    String? body,
    this.colorValue,
    this.isCompleted = false,
    this.iconKey,
    List<SubTaskItem>? children,
  })  : id = id ?? ModelIds.newSubTaskId(),
        body = body ?? '',
        children = children ?? <SubTaskItem>[];

  final String id;
  final String title;
  final String body;
  final int? colorValue;
  final bool isCompleted;
  final String? iconKey;
  final List<SubTaskItem> children;

  SubTaskItem clone() {
    return SubTaskItem(
      id: id,
      title: title,
      body: body,
      colorValue: colorValue,
      isCompleted: isCompleted,
      iconKey: iconKey,
      children: children.map((SubTaskItem item) => item.clone()).toList(),
    );
  }

  SubTaskItem copyWith({
    String? id,
    String? title,
    String? body,
    int? colorValue,
    bool clearColor = false,
    bool? isCompleted,
    String? iconKey,
    bool clearIcon = false,
    List<SubTaskItem>? children,
  }) {
    return SubTaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
      isCompleted: isCompleted ?? this.isCompleted,
      iconKey: clearIcon ? null : (iconKey ?? this.iconKey),
      children: children ??
          this.children.map((SubTaskItem item) => item.clone()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'color': colorValue,
      'completed': isCompleted,
      'icon': iconKey,
      'children': children.map((SubTaskItem item) => item.toJson()).toList(),
    };
  }

  factory SubTaskItem.fromJson(Map<String, dynamic> json) {
    final String title = _readRequiredString(json, 'title');
    final String? id = _readOptionalTrimmedString(json, 'id');
    final String? body = _readOptionalTrimmedString(json, 'body');
    final int? colorValue = _readOptionalInt(json, 'color');
    final bool isCompleted = _readOptionalBool(json, 'completed');
    final String? iconKey = _readOptionalTrimmedString(json, 'icon');
    final List<dynamic> childJson = _readOptionalList(json, 'children');

    return SubTaskItem(
      id: id == null || id.isEmpty ? null : id,
      title: title,
      body: body ?? '',
      colorValue: colorValue,
      isCompleted: isCompleted,
      iconKey: iconKey == null || iconKey.isEmpty ? null : iconKey,
      children: childJson
          .map(
            (dynamic item) => SubTaskItem.fromJson(
              _mapFromDynamic(
                item: item,
                fieldPath: 'tasks.subtasks.children[]',
              ),
            ),
          )
          .toList(),
    );
  }
}

class TaskItem {
  TaskItem({
    String? id,
    required this.title,
    String? body,
    String? prompt,
    String? flashcardPrompt,
    this.createdAtMicros,
    this.colorValue,
    TaskItemType? type,
    TaskEntryType? entryType,
    this.isArchived = false,
    this.isPinned = false,
    this.iconKey,
    List<SubTaskItem>? subtasks,
  })  : id = id ?? ModelIds.newTaskId(),
        body = body ?? '',
        prompt = prompt ?? '',
        flashcardPrompt = flashcardPrompt ?? '',
        type = type ?? TaskItemType.planning,
        entryType = entryType ?? TaskEntryType.note,
        subtasks = subtasks ?? <SubTaskItem>[];

  final String id;
  final String title;
  final String body;
  final String prompt;
  final String flashcardPrompt;
  final int? createdAtMicros;
  final int? colorValue;
  final TaskItemType type;
  final TaskEntryType entryType;
  final bool isArchived;
  final bool isPinned;
  final String? iconKey;
  final List<SubTaskItem> subtasks;

  DateTime? get createdAt => createdAtMicros == null
      ? null
      : DateTime.fromMicrosecondsSinceEpoch(createdAtMicros!);

  TaskItem clone() {
    return TaskItem(
      id: id,
      title: title,
      body: body,
      prompt: prompt,
      flashcardPrompt: flashcardPrompt,
      createdAtMicros: createdAtMicros,
      colorValue: colorValue,
      type: type,
      entryType: entryType,
      isArchived: isArchived,
      isPinned: isPinned,
      iconKey: iconKey,
      subtasks: subtasks.map((SubTaskItem item) => item.clone()).toList(),
    );
  }

  TaskItem copyWith({
    String? id,
    String? title,
    String? body,
    String? prompt,
    String? flashcardPrompt,
    int? createdAtMicros,
    bool clearCreatedAt = false,
    int? colorValue,
    bool clearColor = false,
    TaskItemType? type,
    TaskEntryType? entryType,
    bool? isArchived,
    bool? isPinned,
    String? iconKey,
    bool clearIcon = false,
    List<SubTaskItem>? subtasks,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      prompt: prompt ?? this.prompt,
      flashcardPrompt: flashcardPrompt ?? this.flashcardPrompt,
      createdAtMicros:
          clearCreatedAt ? null : (createdAtMicros ?? this.createdAtMicros),
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
      type: type ?? this.type,
      entryType: entryType ?? this.entryType,
      isArchived: isArchived ?? this.isArchived,
      isPinned: isPinned ?? this.isPinned,
      iconKey: clearIcon ? null : (iconKey ?? this.iconKey),
      subtasks: subtasks ??
          this.subtasks.map((SubTaskItem item) => item.clone()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'prompt': prompt,
      'flashcardPrompt': flashcardPrompt,
      'createdAtMicros': createdAtMicros,
      'color': colorValue,
      'type': type.name,
      'entryType': entryType.name,
      'archived': isArchived,
      'pinned': isPinned,
      'icon': iconKey,
      'subtasks': subtasks.map((SubTaskItem item) => item.toJson()).toList(),
    };
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final String title = _readRequiredString(json, 'title');
    final String? id = _readOptionalTrimmedString(json, 'id');
    final String? body = _readOptionalTrimmedString(json, 'body');
    final String? prompt = _readOptionalTrimmedString(json, 'prompt');
    final String? flashcardPrompt = _readOptionalTrimmedString(
      json,
      'flashcardPrompt',
    );
    final int? createdAtMicros = _readOptionalInt(json, 'createdAtMicros');
    final int? colorValue = _readOptionalInt(json, 'color');
    final TaskItemType type = TaskItemType.fromJsonValue(json['type']);
    final TaskEntryType entryType = TaskEntryType.fromJsonValue(
      json['entryType'],
    );
    final bool isArchived = _readOptionalBool(json, 'archived');
    final bool isPinned = _readOptionalBool(json, 'pinned');
    final String? iconKey = _readOptionalTrimmedString(json, 'icon');
    final List<dynamic> subtaskJson = _readOptionalList(json, 'subtasks');

    return TaskItem(
      id: id == null || id.isEmpty ? null : id,
      title: title,
      body: body ?? '',
      prompt: prompt ?? '',
      flashcardPrompt: flashcardPrompt ?? '',
      createdAtMicros: createdAtMicros,
      colorValue: colorValue,
      type: type,
      entryType: entryType,
      isArchived: isArchived,
      isPinned: isPinned,
      iconKey: iconKey == null || iconKey.isEmpty ? null : iconKey,
      subtasks: subtaskJson
          .map(
            (dynamic item) => SubTaskItem.fromJson(
              _mapFromDynamic(item: item, fieldPath: 'tasks.subtasks[]'),
            ),
          )
          .toList(),
    );
  }
}

class ProjectItem {
  ProjectItem({
    String? id,
    required this.name,
    String? body,
    String? prompt,
    this.colorValue,
    this.iconKey,
    this.isArchived = false,
    this.isPinned = false,
    this.stackId,
    this.projectTypeId,
    List<TaskItem>? tasks,
    List<PersonItem>? people,
  })  : id = id ?? ModelIds.newProjectId(),
        body = body ?? '',
        prompt = prompt ?? '',
        tasks = tasks ?? <TaskItem>[],
        people = people ?? <PersonItem>[];

  final String id;
  final String name;
  final String body;
  final String prompt;
  final int? colorValue;
  final String? iconKey;
  final bool isArchived;
  final bool isPinned;
  final String? stackId;
  final String? projectTypeId;
  final List<TaskItem> tasks;
  final List<PersonItem> people;

  ProjectItem clone() {
    return ProjectItem(
      id: id,
      name: name,
      body: body,
      prompt: prompt,
      colorValue: colorValue,
      iconKey: iconKey,
      isArchived: isArchived,
      isPinned: isPinned,
      stackId: stackId,
      projectTypeId: projectTypeId,
      tasks: tasks.map((TaskItem item) => item.clone()).toList(),
      people: people.map((PersonItem person) => person.clone()).toList(),
    );
  }

  ProjectItem copyWith({
    String? id,
    String? name,
    String? body,
    String? prompt,
    int? colorValue,
    bool clearColor = false,
    String? iconKey,
    bool clearIcon = false,
    bool? isArchived,
    bool? isPinned,
    String? stackId,
    bool clearStack = false,
    String? projectTypeId,
    bool clearProjectType = false,
    List<TaskItem>? tasks,
    List<PersonItem>? people,
  }) {
    return ProjectItem(
      id: id ?? this.id,
      name: name ?? this.name,
      body: body ?? this.body,
      prompt: prompt ?? this.prompt,
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
      iconKey: clearIcon ? null : (iconKey ?? this.iconKey),
      isArchived: isArchived ?? this.isArchived,
      isPinned: isPinned ?? this.isPinned,
      stackId: clearStack ? null : (stackId ?? this.stackId),
      projectTypeId:
          clearProjectType ? null : (projectTypeId ?? this.projectTypeId),
      tasks: tasks ?? this.tasks.map((TaskItem item) => item.clone()).toList(),
      people: people ??
          this.people.map((PersonItem person) => person.clone()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'body': body,
      'prompt': prompt,
      'color': colorValue,
      'icon': iconKey,
      'archived': isArchived,
      'pinned': isPinned,
      'stackId': stackId,
      'projectTypeId': projectTypeId,
      'tasks': tasks.map((TaskItem item) => item.toJson()).toList(),
      'people': people.map((PersonItem person) => person.toJson()).toList(),
    };
  }

  factory ProjectItem.fromJson(Map<String, dynamic> json) {
    final String name = _readRequiredString(json, 'name');
    final String? id = _readOptionalTrimmedString(json, 'id');
    final String? body = _readOptionalTrimmedString(json, 'body');
    final String? prompt = _readOptionalTrimmedString(json, 'prompt');
    final int? colorValue = _readOptionalInt(json, 'color');
    final String? iconKey = _readOptionalTrimmedString(json, 'icon');
    final bool isArchived = _readOptionalBool(json, 'archived');
    final bool isPinned = _readOptionalBool(json, 'pinned');
    final String? stackId = _readOptionalTrimmedString(json, 'stackId');
    final String? projectTypeId = _readOptionalTrimmedString(
      json,
      'projectTypeId',
    );
    final List<dynamic> taskJson = _readOptionalList(json, 'tasks');
    final List<dynamic> personJson = _readOptionalList(json, 'people');

    return ProjectItem(
      id: id == null || id.isEmpty ? null : id,
      name: name,
      body: body ?? '',
      prompt: prompt ?? '',
      colorValue: colorValue,
      iconKey: iconKey == null || iconKey.isEmpty ? null : iconKey,
      isArchived: isArchived,
      isPinned: isPinned,
      stackId: stackId == null || stackId.isEmpty ? null : stackId,
      projectTypeId:
          projectTypeId == null || projectTypeId.isEmpty ? null : projectTypeId,
      tasks: taskJson
          .map(
            (dynamic item) => TaskItem.fromJson(
              _mapFromDynamic(item: item, fieldPath: 'projects.tasks[]'),
            ),
          )
          .toList(),
      people: personJson
          .map(
            (dynamic item) => PersonItem.fromJson(
              _mapFromDynamic(item: item, fieldPath: 'projects.people[]'),
            ),
          )
          .toList(),
    );
  }
}

class PersonItem {
  PersonItem({
    String? id,
    required this.name,
    String? body,
    this.colorValue,
    this.iconKey,
    this.isArchived = false,
    List<TaskItem>? tasks,
  })  : id = id ?? ModelIds.newPersonId(),
        body = body ?? '',
        tasks = tasks ?? <TaskItem>[];

  final String id;
  final String name;
  final String body;
  final int? colorValue;
  final String? iconKey;
  final bool isArchived;
  final List<TaskItem> tasks;

  PersonItem clone() {
    return PersonItem(
      id: id,
      name: name,
      body: body,
      colorValue: colorValue,
      iconKey: iconKey,
      isArchived: isArchived,
      tasks: tasks.map((TaskItem item) => item.clone()).toList(),
    );
  }

  PersonItem copyWith({
    String? id,
    String? name,
    String? body,
    int? colorValue,
    bool clearColor = false,
    String? iconKey,
    bool clearIcon = false,
    bool? isArchived,
    List<TaskItem>? tasks,
  }) {
    return PersonItem(
      id: id ?? this.id,
      name: name ?? this.name,
      body: body ?? this.body,
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
      iconKey: clearIcon ? null : (iconKey ?? this.iconKey),
      isArchived: isArchived ?? this.isArchived,
      tasks: tasks ?? this.tasks.map((TaskItem item) => item.clone()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'body': body,
      'color': colorValue,
      'icon': iconKey,
      'archived': isArchived,
      'tasks': tasks.map((TaskItem item) => item.toJson()).toList(),
    };
  }

  factory PersonItem.fromJson(Map<String, dynamic> json) {
    final String name = _readRequiredString(json, 'name');
    final String? id = _readOptionalTrimmedString(json, 'id');
    final String? body = _readOptionalTrimmedString(json, 'body');
    final int? colorValue = _readOptionalInt(json, 'color');
    final String? iconKey = _readOptionalTrimmedString(json, 'icon');
    final bool isArchived = _readOptionalBool(json, 'archived');
    final List<dynamic> taskJson = _readOptionalList(json, 'tasks');

    return PersonItem(
      id: id == null || id.isEmpty ? null : id,
      name: name,
      body: body ?? '',
      colorValue: colorValue,
      iconKey: iconKey == null || iconKey.isEmpty ? null : iconKey,
      isArchived: isArchived,
      tasks: taskJson
          .map(
            (dynamic item) => TaskItem.fromJson(
              _mapFromDynamic(item: item, fieldPath: 'projects.people.tasks[]'),
            ),
          )
          .toList(),
    );
  }
}

class ProjectStack {
  ProjectStack({String? id, required this.name, this.colorValue})
      : id = id ?? ModelIds.newProjectStackId();

  final String id;
  final String name;
  final int? colorValue;

  ProjectStack clone() {
    return ProjectStack(id: id, name: name, colorValue: colorValue);
  }

  ProjectStack copyWith({
    String? id,
    String? name,
    int? colorValue,
    bool clearColor = false,
  }) {
    return ProjectStack(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'id': id, 'name': name, 'color': colorValue};
  }

  factory ProjectStack.fromJson(Map<String, dynamic> json) {
    final String name = _readRequiredString(json, 'name');
    final String? id = _readOptionalTrimmedString(json, 'id');
    final int? colorValue = _readOptionalInt(json, 'color');

    return ProjectStack(
      id: id == null || id.isEmpty ? null : id,
      name: name,
      colorValue: colorValue,
    );
  }
}

class ProjectTypeDefaults {
  static const String blankId = 'project-type-blank';
  static const String projectId = 'project-type-project';
  static const String ideasId = 'project-type-ideas';
  static const String knowledgeId = 'project-type-knowledge';
  static const String llmId = 'project-type-llm';
  static const String diaryId = 'project-type-diary';
  static const String peopleId = 'project-type-people';
}

enum ProjectLayoutKind {
  standard,
  journalOnly,
  entryContainer;

  static ProjectLayoutKind fromJsonValue(Object? rawValue) {
    if (rawValue is! String) {
      return ProjectLayoutKind.standard;
    }

    return switch (rawValue.trim().toLowerCase()) {
      'journalonly' ||
      'journal_only' ||
      'journal-only' =>
        ProjectLayoutKind.journalOnly,
      'entrycontainer' ||
      'entry_container' ||
      'entry-container' =>
        ProjectLayoutKind.entryContainer,
      'peoplecontainer' ||
      'people_container' ||
      'people-container' =>
        ProjectLayoutKind.entryContainer,
      _ => ProjectLayoutKind.standard,
    };
  }
}

class ProjectTypeConfig {
  const ProjectTypeConfig({
    required this.id,
    required this.name,
    this.iconKey,
    this.layoutKind = ProjectLayoutKind.standard,
    required this.showsJournalEntries,
    required this.showsPlanningTasks,
    required this.showsIdeas,
    this.childItemLabel = 'Item',
    this.childItemsLabel = 'Items',
    this.childJournalEntryLabel = 'Journal entry',
    this.childJournalEntriesLabel = 'Journal entries',
  });

  final String id;
  final String name;
  final String? iconKey;
  final ProjectLayoutKind layoutKind;
  final bool showsJournalEntries;
  final bool showsPlanningTasks;
  final bool showsIdeas;
  final String childItemLabel;
  final String childItemsLabel;
  final String childJournalEntryLabel;
  final String childJournalEntriesLabel;

  ProjectTypeConfig clone() {
    return ProjectTypeConfig(
      id: id,
      name: name,
      iconKey: iconKey,
      layoutKind: layoutKind,
      showsJournalEntries: showsJournalEntries,
      showsPlanningTasks: showsPlanningTasks,
      showsIdeas: showsIdeas,
      childItemLabel: childItemLabel,
      childItemsLabel: childItemsLabel,
      childJournalEntryLabel: childJournalEntryLabel,
      childJournalEntriesLabel: childJournalEntriesLabel,
    );
  }

  ProjectTypeConfig copyWith({
    String? id,
    String? name,
    String? iconKey,
    bool clearIcon = false,
    ProjectLayoutKind? layoutKind,
    bool? showsJournalEntries,
    bool? showsPlanningTasks,
    bool? showsIdeas,
    String? childItemLabel,
    String? childItemsLabel,
    String? childJournalEntryLabel,
    String? childJournalEntriesLabel,
  }) {
    return ProjectTypeConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      iconKey: clearIcon ? null : (iconKey ?? this.iconKey),
      layoutKind: layoutKind ?? this.layoutKind,
      showsJournalEntries: showsJournalEntries ?? this.showsJournalEntries,
      showsPlanningTasks: showsPlanningTasks ?? this.showsPlanningTasks,
      showsIdeas: showsIdeas ?? this.showsIdeas,
      childItemLabel: childItemLabel ?? this.childItemLabel,
      childItemsLabel: childItemsLabel ?? this.childItemsLabel,
      childJournalEntryLabel:
          childJournalEntryLabel ?? this.childJournalEntryLabel,
      childJournalEntriesLabel:
          childJournalEntriesLabel ?? this.childJournalEntriesLabel,
    );
  }

  bool get supportsAnyTasks => showsPlanningTasks || showsIdeas;
  bool get supportsAnyEntries =>
      showsJournalEntries || showsPlanningTasks || showsIdeas;
  bool get showsOnlyJournalEntries =>
      showsJournalEntries && !showsPlanningTasks && !showsIdeas;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'icon': iconKey,
      'layoutKind': layoutKind.name,
      'showsJournalEntries': showsJournalEntries,
      'showsPlanningTasks': showsPlanningTasks,
      'showsIdeas': showsIdeas,
      'childItemLabel': childItemLabel,
      'childItemsLabel': childItemsLabel,
      'childJournalEntryLabel': childJournalEntryLabel,
      'childJournalEntriesLabel': childJournalEntriesLabel,
    };
  }

  factory ProjectTypeConfig.fromJson(Map<String, dynamic> json) {
    final String id = _readRequiredString(json, 'id');
    final String name = _readRequiredString(json, 'name');
    final String? iconKey = _readOptionalTrimmedString(json, 'icon');

    return ProjectTypeConfig(
      id: id,
      name: name,
      iconKey: iconKey == null || iconKey.isEmpty ? null : iconKey,
      layoutKind: json.containsKey('layoutKind')
          ? ProjectLayoutKind.fromJsonValue(json['layoutKind'])
          : defaultLayoutKindForId(id),
      showsJournalEntries: _readOptionalBool(json, 'showsJournalEntries'),
      showsPlanningTasks: _readOptionalBool(json, 'showsPlanningTasks'),
      showsIdeas: _readOptionalBool(json, 'showsIdeas'),
      childItemLabel: _readOptionalTrimmedString(json, 'childItemLabel') ??
          defaultForId(id).childItemLabel,
      childItemsLabel: _readOptionalTrimmedString(json, 'childItemsLabel') ??
          defaultForId(id).childItemsLabel,
      childJournalEntryLabel:
          _readOptionalTrimmedString(json, 'childJournalEntryLabel') ??
              defaultForId(id).childJournalEntryLabel,
      childJournalEntriesLabel:
          _readOptionalTrimmedString(json, 'childJournalEntriesLabel') ??
              defaultForId(id).childJournalEntriesLabel,
    );
  }

  static ProjectLayoutKind defaultLayoutKindForId(String? id) {
    return switch (id) {
      ProjectTypeDefaults.diaryId => ProjectLayoutKind.journalOnly,
      ProjectTypeDefaults.peopleId => ProjectLayoutKind.entryContainer,
      _ => ProjectLayoutKind.standard,
    };
  }

  static ProjectTypeConfig defaultForId(String? id) {
    final String normalizedId =
        (id == null || id.isEmpty) ? ProjectTypeDefaults.blankId : id;
    for (final ProjectTypeConfig type in defaults()) {
      if (type.id == normalizedId) {
        return type;
      }
    }
    return defaults().first;
  }

  static List<ProjectTypeConfig> defaults() {
    return const <ProjectTypeConfig>[
      ProjectTypeConfig(
        id: ProjectTypeDefaults.blankId,
        name: 'Blank',
        layoutKind: ProjectLayoutKind.standard,
        showsJournalEntries: false,
        showsPlanningTasks: false,
        showsIdeas: false,
      ),
      ProjectTypeConfig(
        id: ProjectTypeDefaults.projectId,
        name: 'Project',
        iconKey: 'folder-open',
        layoutKind: ProjectLayoutKind.standard,
        showsJournalEntries: false,
        showsPlanningTasks: true,
        showsIdeas: true,
      ),
      ProjectTypeConfig(
        id: ProjectTypeDefaults.ideasId,
        name: 'Ideas',
        iconKey: 'lightbulb',
        layoutKind: ProjectLayoutKind.standard,
        showsJournalEntries: false,
        showsPlanningTasks: false,
        showsIdeas: true,
      ),
      ProjectTypeConfig(
        id: ProjectTypeDefaults.knowledgeId,
        name: 'Knowledge',
        iconKey: 'book-open',
        layoutKind: ProjectLayoutKind.standard,
        showsJournalEntries: false,
        showsPlanningTasks: false,
        showsIdeas: true,
      ),
      ProjectTypeConfig(
        id: ProjectTypeDefaults.llmId,
        name: 'LLM Project',
        iconKey: 'brain',
        layoutKind: ProjectLayoutKind.standard,
        showsJournalEntries: false,
        showsPlanningTasks: true,
        showsIdeas: true,
      ),
      ProjectTypeConfig(
        id: ProjectTypeDefaults.diaryId,
        name: 'Diary',
        iconKey: 'book-open',
        layoutKind: ProjectLayoutKind.journalOnly,
        showsJournalEntries: true,
        showsPlanningTasks: false,
        showsIdeas: false,
      ),
      ProjectTypeConfig(
        id: ProjectTypeDefaults.peopleId,
        name: 'People',
        iconKey: 'heart',
        layoutKind: ProjectLayoutKind.entryContainer,
        showsJournalEntries: true,
        showsPlanningTasks: false,
        showsIdeas: true,
        childItemLabel: 'Person',
        childItemsLabel: 'People',
        childJournalEntryLabel: 'Interaction',
        childJournalEntriesLabel: 'Interactions',
      ),
    ];
  }
}

class ProjectRules {
  const ProjectRules({required this.projectType});

  final ProjectTypeConfig projectType;

  static ProjectTypeConfig resolveProjectType(
    String? projectTypeId,
    List<ProjectTypeConfig> projectTypes,
  ) {
    final String targetId = (projectTypeId == null || projectTypeId.isEmpty)
        ? ProjectTypeDefaults.blankId
        : projectTypeId;
    for (final ProjectTypeConfig type in projectTypes) {
      if (type.id == targetId) {
        return type;
      }
    }
    return ProjectTypeConfig.defaults().first;
  }

  factory ProjectRules.forProject({
    required ProjectItem project,
    required List<ProjectTypeConfig> projectTypes,
  }) {
    return ProjectRules(
      projectType: resolveProjectType(project.projectTypeId, projectTypes),
    );
  }

  factory ProjectRules.forProjectTypeId({
    required String? projectTypeId,
    required List<ProjectTypeConfig> projectTypes,
  }) {
    return ProjectRules(
      projectType: resolveProjectType(projectTypeId, projectTypes),
    );
  }

  bool get isEntryContainer =>
      projectType.layoutKind == ProjectLayoutKind.entryContainer;

  bool get isPeopleContainer => isEntryContainer;

  bool get isJournalOnly =>
      projectType.layoutKind == ProjectLayoutKind.journalOnly;

  bool get acceptsRootTasks =>
      !isEntryContainer && projectType.supportsAnyEntries;

  bool get canMoveBetweenTaskSections =>
      !isEntryContainer &&
      projectType.showsIdeas &&
      projectType.showsPlanningTasks;

  bool get defaultsToJournalEntry => projectType.showsOnlyJournalEntries;

  bool get defaultsToThinkingEntry =>
      projectType.showsIdeas &&
      !projectType.showsPlanningTasks &&
      !projectType.showsJournalEntries;

  bool get defaultsToPlanningEntry =>
      !projectType.showsIdeas &&
      projectType.showsPlanningTasks &&
      !projectType.showsJournalEntries;

  TaskItem normalizeTask(TaskItem task) {
    TaskItem adjustedTask = task;

    if (adjustedTask.entryType == TaskEntryType.journal &&
        !projectType.showsJournalEntries) {
      adjustedTask = adjustedTask.copyWith(entryType: TaskEntryType.note);
    }

    if (projectType.showsOnlyJournalEntries &&
        adjustedTask.entryType != TaskEntryType.journal) {
      return adjustedTask.copyWith(
        entryType: TaskEntryType.journal,
        type: TaskItemType.thinking,
        createdAtMicros: adjustedTask.createdAtMicros ??
            DateTime.now().microsecondsSinceEpoch,
      );
    }

    if (adjustedTask.entryType == TaskEntryType.session) {
      adjustedTask = adjustedTask.copyWith(type: TaskItemType.thinking);
    }

    if (adjustedTask.entryType == TaskEntryType.journal &&
        adjustedTask.type != TaskItemType.thinking) {
      adjustedTask = adjustedTask.copyWith(type: TaskItemType.thinking);
    }

    if (projectType.showsIdeas && !projectType.showsPlanningTasks) {
      return adjustedTask.type == TaskItemType.thinking
          ? adjustedTask
          : adjustedTask.copyWith(type: TaskItemType.thinking);
    }
    if (!projectType.showsIdeas && projectType.showsPlanningTasks) {
      return adjustedTask.type == TaskItemType.planning
          ? adjustedTask
          : adjustedTask.copyWith(type: TaskItemType.planning);
    }
    return adjustedTask;
  }
}

class TaskBoardState {
  const TaskBoardState({
    required this.incomingTasks,
    required this.projects,
    required this.projectStacks,
    required this.projectTypes,
    required this.colorLabels,
    required this.hideCompletedProjectItems,
    required this.cardLayoutPreset,
  });

  final List<TaskItem> incomingTasks;
  final List<ProjectItem> projects;
  final List<ProjectStack> projectStacks;
  final List<ProjectTypeConfig> projectTypes;
  final Map<int, String> colorLabels;
  final bool hideCompletedProjectItems;
  final CardLayoutPreset cardLayoutPreset;

  TaskBoardState clone() {
    return TaskBoardState(
      incomingTasks:
          incomingTasks.map((TaskItem task) => task.clone()).toList(),
      projects: projects.map((ProjectItem project) => project.clone()).toList(),
      projectStacks:
          projectStacks.map((ProjectStack stack) => stack.clone()).toList(),
      projectTypes:
          projectTypes.map((ProjectTypeConfig type) => type.clone()).toList(),
      colorLabels: Map<int, String>.from(colorLabels),
      hideCompletedProjectItems: hideCompletedProjectItems,
      cardLayoutPreset: cardLayoutPreset,
    );
  }

  factory TaskBoardState.defaults() {
    return TaskBoardState(
      incomingTasks: <TaskItem>[
        TaskItem(title: 'Sit for 10 minutes in silence'),
        TaskItem(title: 'Do a 3-minute breathing check-in'),
        TaskItem(title: 'Body scan before sleep'),
        TaskItem(title: 'Mindful walk without headphones'),
        TaskItem(title: 'Write down 3 emotions you notice'),
        TaskItem(title: 'Single-task one activity with full attention'),
      ],
      projects: <ProjectItem>[
        ProjectItem(
          name: 'Morning Routine',
          projectTypeId: ProjectTypeDefaults.projectId,
          body:
              'A lightweight weekday reset that gets the day started before messages and meetings take over.',
          iconKey: 'sun',
          tasks: <TaskItem>[
            TaskItem(
              title: 'Shape a calm start sequence',
              body: 'Keep the first 20 minutes deliberate and friction-free.',
              type: TaskItemType.thinking,
              iconKey: 'lightbulb',
              subtasks: <SubTaskItem>[
                SubTaskItem(
                  title: 'Protect the first 10 minutes from the phone',
                  body:
                      'No inbox, no scrolling, no notifications until after water and daylight.',
                  children: <SubTaskItem>[
                    SubTaskItem(title: 'Charge phone outside the bedroom'),
                    SubTaskItem(title: 'Use a simple alarm instead'),
                  ],
                ),
                SubTaskItem(
                  title: 'Make the routine feel easy to begin',
                  children: <SubTaskItem>[
                    SubTaskItem(title: 'Lay out clothes the night before'),
                    SubTaskItem(title: 'Keep water bottle filled on desk'),
                    SubTaskItem(title: 'Choose one default breakfast'),
                  ],
                ),
              ],
            ),
            TaskItem(
              title: 'Morning reset checklist',
              body: 'Short sequence before opening laptop.',
              type: TaskItemType.planning,
              iconKey: 'list-check',
              subtasks: <SubTaskItem>[
                SubTaskItem(title: 'Open curtains and get daylight'),
                SubTaskItem(title: 'Drink water'),
                SubTaskItem(title: 'Two minutes of stretching'),
                SubTaskItem(
                  title: 'Review top priority for the day',
                  children: <SubTaskItem>[
                    SubTaskItem(title: 'Write one sentence goal'),
                    SubTaskItem(title: 'Pick the first work block'),
                  ],
                ),
              ],
            ),
            TaskItem(
              title: 'Build a better breakfast fallback',
              body: 'Prevent decision fatigue on busy days.',
              type: TaskItemType.planning,
              iconKey: 'bolt',
              subtasks: <SubTaskItem>[
                SubTaskItem(title: 'Stock yogurt, fruit, and oats'),
                SubTaskItem(title: 'Choose one 5-minute option'),
              ],
            ),
          ],
        ),
        ProjectItem(
          name: 'Stress Reset',
          projectTypeId: ProjectTypeDefaults.projectId,
          body:
              'A toolkit for catching overload earlier and responding before it spills into the rest of the day.',
          iconKey: 'heart',
          tasks: <TaskItem>[
            TaskItem(
              title: 'Notice early stress signals',
              body:
                  'Define the clues that usually show up before burnout mode.',
              type: TaskItemType.thinking,
              iconKey: 'brain',
              subtasks: <SubTaskItem>[
                SubTaskItem(
                  title: 'Physical signs',
                  children: <SubTaskItem>[
                    SubTaskItem(title: 'Jaw tightness'),
                    SubTaskItem(title: 'Shallow breathing'),
                    SubTaskItem(title: 'Restless switching between tabs'),
                  ],
                ),
                SubTaskItem(
                  title: 'Behavioral signs',
                  children: <SubTaskItem>[
                    SubTaskItem(title: 'Snapping into urgency'),
                    SubTaskItem(title: 'Starting tasks without finishing'),
                    SubTaskItem(title: 'Avoiding simple messages'),
                  ],
                ),
              ],
            ),
            TaskItem(
              title: 'Three-step reset',
              body: 'Use this when the day starts spiraling.',
              type: TaskItemType.planning,
              iconKey: 'seedling',
              subtasks: <SubTaskItem>[
                SubTaskItem(title: 'Step away from screen for 2 minutes'),
                SubTaskItem(title: 'Do one long exhale cycle x5'),
                SubTaskItem(
                  title: 'Reduce scope intentionally',
                  children: <SubTaskItem>[
                    SubTaskItem(title: 'Choose one thing to finish'),
                    SubTaskItem(title: 'Defer one nonessential task'),
                  ],
                ),
              ],
            ),
            TaskItem(
              title: 'Create a rescue playlist of interventions',
              body: 'Small actions that reliably shift energy.',
              type: TaskItemType.thinking,
              iconKey: 'rocket',
              subtasks: <SubTaskItem>[
                SubTaskItem(title: 'Five-minute walk outside'),
                SubTaskItem(title: 'Cold water on wrists'),
                SubTaskItem(
                  title: 'Message one grounding person',
                  children: <SubTaskItem>[
                    SubTaskItem(title: 'Write a one-line template'),
                  ],
                ),
              ],
            ),
          ],
        ),
        ProjectItem(
          name: 'Sleep Wind-Down',
          projectTypeId: ProjectTypeDefaults.projectId,
          body:
              'Reduce late-evening stimulation and make sleep onset more predictable.',
          iconKey: 'moon',
          tasks: <TaskItem>[
            TaskItem(
              title: 'Design a lower-friction evening',
              body: 'Make the last hour of the day quieter by default.',
              type: TaskItemType.thinking,
              iconKey: 'moon',
              subtasks: <SubTaskItem>[
                SubTaskItem(
                  title: 'Lower stimulation after 9:30pm',
                  children: <SubTaskItem>[
                    SubTaskItem(title: 'Warm lights only'),
                    SubTaskItem(title: 'No intense shows'),
                    SubTaskItem(title: 'Keep phone charger away from bed'),
                  ],
                ),
                SubTaskItem(
                  title: 'Capture loose thoughts before bed',
                  children: <SubTaskItem>[
                    SubTaskItem(title: 'Leave notebook on nightstand'),
                    SubTaskItem(title: 'Write tomorrow’s first task'),
                  ],
                ),
              ],
            ),
            TaskItem(
              title: 'Night shutdown checklist',
              body: 'Simple sequence to repeat every evening.',
              type: TaskItemType.planning,
              iconKey: 'star',
              subtasks: <SubTaskItem>[
                SubTaskItem(title: 'Set phone to do not disturb'),
                SubTaskItem(title: 'Brush teeth and wash face'),
                SubTaskItem(title: 'Read 5 pages of a physical book'),
                SubTaskItem(
                  title: 'Prepare for tomorrow',
                  children: <SubTaskItem>[
                    SubTaskItem(title: 'Put out clothes'),
                    SubTaskItem(title: 'Clear desk surface'),
                  ],
                ),
              ],
            ),
            TaskItem(
              title: 'Track what helps sleep most',
              body: 'Run a loose experiment for a week.',
              type: TaskItemType.planning,
              iconKey: 'book-open',
              subtasks: <SubTaskItem>[
                SubTaskItem(title: 'Note bedtime'),
                SubTaskItem(title: 'Note caffeine after lunch'),
                SubTaskItem(title: 'Score next-morning energy 1-5'),
              ],
            ),
          ],
        ),
      ],
      projectStacks: <ProjectStack>[],
      projectTypes: ProjectTypeConfig.defaults(),
      colorLabels: <int, String>{},
      hideCompletedProjectItems: false,
      cardLayoutPreset: CardLayoutPreset.standard,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'incomingTasks':
          incomingTasks.map((TaskItem task) => task.toJson()).toList(),
      'projects':
          projects.map((ProjectItem project) => project.toJson()).toList(),
      'projectStacks':
          projectStacks.map((ProjectStack stack) => stack.toJson()).toList(),
      'projectTypes':
          projectTypes.map((ProjectTypeConfig type) => type.toJson()).toList(),
      'colorLabels': colorLabels.map(
        (int colorValue, String label) =>
            MapEntry<String, String>(colorValue.toString(), label),
      ),
      'hideCompletedProjectItems': hideCompletedProjectItems,
      'cardLayoutPreset': cardLayoutPreset.name,
    };
  }

  factory TaskBoardState.fromJson(Map<String, dynamic> json) {
    final List<dynamic> incomingJson = _readOptionalList(json, 'incomingTasks');
    final List<dynamic> projectJson = _readOptionalList(json, 'projects');
    final List<dynamic> projectStackJson = _readOptionalList(
      json,
      'projectStacks',
    );
    final List<dynamic> projectTypeJson = _readOptionalList(
      json,
      'projectTypes',
    );
    final Map<int, String> colorLabels = _readColorLabelMap(
      json,
      'colorLabels',
    );

    return TaskBoardState(
      incomingTasks: incomingJson
          .map(
            (dynamic item) => TaskItem.fromJson(
              _mapFromDynamic(item: item, fieldPath: 'incomingTasks[]'),
            ),
          )
          .toList(),
      projects: projectJson
          .map(
            (dynamic item) => ProjectItem.fromJson(
              _mapFromDynamic(item: item, fieldPath: 'projects[]'),
            ),
          )
          .toList(),
      projectStacks: projectStackJson
          .map(
            (dynamic item) => ProjectStack.fromJson(
              _mapFromDynamic(item: item, fieldPath: 'projectStacks[]'),
            ),
          )
          .toList(),
      projectTypes: projectTypeJson
          .map(
            (dynamic item) => ProjectTypeConfig.fromJson(
              _mapFromDynamic(item: item, fieldPath: 'projectTypes[]'),
            ),
          )
          .toList(),
      colorLabels: colorLabels,
      hideCompletedProjectItems: _readOptionalBool(
        json,
        'hideCompletedProjectItems',
      ),
      cardLayoutPreset: CardLayoutPreset.fromJsonValue(
        json['cardLayoutPreset'],
      ),
    );
  }
}

String _readRequiredString(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! String) {
    throw FormatException('Expected "$key" to be a string.');
  }
  final String trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw FormatException('Expected "$key" to be a non-empty string.');
  }
  return trimmed;
}

String? _readOptionalTrimmedString(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Expected "$key" to be a string when present.');
  }
  return value.trim();
}

int? _readOptionalInt(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! int) {
    throw FormatException('Expected "$key" to be an int when present.');
  }
  return value;
}

bool _readOptionalBool(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return false;
  }
  if (value is! bool) {
    throw FormatException('Expected "$key" to be a bool when present.');
  }
  return value;
}

List<dynamic> _readOptionalList(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return <dynamic>[];
  }
  if (value is! List<dynamic>) {
    throw FormatException('Expected "$key" to be a JSON array.');
  }
  return value;
}

Map<int, String> _readColorLabelMap(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return <int, String>{};
  }
  if (value is! Map<dynamic, dynamic>) {
    throw FormatException('Expected "$key" to be a JSON map.');
  }

  final Map<int, String> result = <int, String>{};
  for (final MapEntry<dynamic, dynamic> entry in value.entries) {
    final int? colorValue = switch (entry.key) {
      int numericKey => numericKey,
      String stringKey => int.tryParse(stringKey),
      _ => int.tryParse(entry.key.toString()),
    };
    if (colorValue == null) {
      continue;
    }

    if (entry.value is! String) {
      throw FormatException(
        'Expected "$key.${entry.key}" to be a string label.',
      );
    }
    final String label = (entry.value as String).trim();
    if (label.isEmpty) {
      continue;
    }

    result[colorValue] = label;
  }

  return result;
}

Map<String, dynamic> _mapFromDynamic({
  required dynamic item,
  required String fieldPath,
}) {
  if (item is! Map<dynamic, dynamic>) {
    throw FormatException('Expected "$fieldPath" item to be a JSON map.');
  }
  return Map<String, dynamic>.from(item);
}
