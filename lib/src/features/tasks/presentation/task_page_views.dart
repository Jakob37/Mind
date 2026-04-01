part of 'task_page.dart';

class _FlashcardsTabView extends StatelessWidget {
  const _FlashcardsTabView({
    required this.flashcards,
    required this.dueCount,
    required this.activeIndex,
    required this.isAnswerVisible,
    required this.onRevealAnswer,
    required this.onShowPrevious,
    required this.onShowNext,
    required this.onReviewFailed,
    required this.onReviewHard,
    required this.onReviewCorrect,
  });

  final List<_FlashcardEntry> flashcards;
  final int dueCount;
  final int activeIndex;
  final bool isAnswerVisible;
  final VoidCallback onRevealAnswer;
  final VoidCallback onShowPrevious;
  final VoidCallback onShowNext;
  final VoidCallback onReviewFailed;
  final VoidCallback onReviewHard;
  final VoidCallback onReviewCorrect;

  @override
  Widget build(BuildContext context) {
    if (flashcards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Add a flashcard prompt to any idea entry to study it here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    final _FlashcardEntry flashcard = flashcards[activeIndex];
    final IconData? iconData = iconDataForKey(flashcard.iconKey);
    final DateTime? dueAt = flashcard.dueAt;
    final bool isDue = dueAt == null || !dueAt.isAfter(DateTime.now());
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    final String scheduleLabel = dueAt == null
        ? 'Due now'
        : isDue
            ? 'Due now'
            : 'Next review ${localizations.formatShortDate(dueAt)}';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text('Flashcards', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Card ${activeIndex + 1} of ${flashcards.length}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          dueCount <= 0 ? 'No cards due right now' : '$dueCount cards due',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Card(
          color: flashcard.colorValue == null
              ? null
              : Color(flashcard.colorValue!),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Prompt', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  flashcard.prompt,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Interval: ${flashcard.intervalDays} day${flashcard.intervalDays == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  scheduleLabel,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                if (isAnswerVisible) ...<Widget>[
                  Text(
                    'Answer',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (iconData != null) ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(iconData),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              flashcard.answerTitle,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (flashcard.answerBody
                                .trim()
                                .isNotEmpty) ...<Widget>[
                              const SizedBox(height: 8),
                              Text(
                                flashcard.answerBody,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton(
                        onPressed: onReviewFailed,
                        child: const Text('Failed'),
                      ),
                      OutlinedButton(
                        onPressed: onReviewHard,
                        child: const Text('Hard'),
                      ),
                      FilledButton(
                        onPressed: onReviewCorrect,
                        child: const Text('Correct'),
                      ),
                    ],
                  ),
                ] else
                  FilledButton(
                    onPressed: onRevealAnswer,
                    child: const Text('Reveal answer'),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Source: ${flashcard.sourceLabel}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onShowPrevious,
                icon: const Icon(Icons.arrow_back_outlined),
                label: const Text('Previous'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: onShowNext,
                icon: const Icon(Icons.arrow_forward_outlined),
                label: const Text('Next'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TaskPageScaffoldView extends StatelessWidget {
  const _TaskPageScaffoldView({
    required this.tabController,
    required this.selectedTabIndex,
    required this.onOpenSettings,
    required this.incomingTasks,
    required this.projects,
    required this.projectStacks,
    required this.projectTypes,
    required this.cardLayoutPreset,
    required this.onIncomingTaskTap,
    required this.onIncomingTaskOptionsTap,
    required this.onMoveIncomingTaskToProject,
    required this.onRemoveIncomingTask,
    required this.onMoveIncomingTask,
    required this.onNestIncomingTask,
    required this.onProjectOrderChanged,
    required this.onProjectTap,
    required this.onProjectArchive,
    required this.onProjectRestore,
    required this.onProjectRemove,
    required this.onProjectOptionsTap,
    required this.onProjectStackOptionsTap,
    required this.onProjectStackDrop,
    required this.onMoveProjectToStackPosition,
    required this.flashcardsTab,
    required this.onAddTask,
    required this.onAddProject,
  });

  final TabController tabController;
  final int selectedTabIndex;
  final VoidCallback onOpenSettings;
  final List<TaskItem> incomingTasks;
  final List<ProjectItem> projects;
  final List<ProjectStack> projectStacks;
  final List<ProjectTypeConfig> projectTypes;
  final CardLayoutPreset cardLayoutPreset;
  final Future<void> Function(String taskId) onIncomingTaskTap;
  final Future<void> Function(String taskId) onIncomingTaskOptionsTap;
  final Future<void> Function(String taskId) onMoveIncomingTaskToProject;
  final void Function(String taskId) onRemoveIncomingTask;
  final void Function({required String taskId, required int targetIndex})
      onMoveIncomingTask;
  final void Function({
    required String sourceTaskId,
    required String targetTaskId,
  }) onNestIncomingTask;
  final void Function(List<String> reorderedProjectIds) onProjectOrderChanged;
  final Future<void> Function(String projectId) onProjectTap;
  final void Function(String projectId) onProjectArchive;
  final void Function(String projectId) onProjectRestore;
  final void Function(String projectId) onProjectRemove;
  final Future<void> Function(String projectId) onProjectOptionsTap;
  final Future<void> Function(String stackId) onProjectStackOptionsTap;
  final Future<void> Function(
    List<String> sourceProjectIds,
    List<String> targetProjectIds,
  ) onProjectStackDrop;
  final void Function({
    required String sourceProjectId,
    required String targetStackId,
    required int targetIndex,
  }) onMoveProjectToStackPosition;
  final Widget flashcardsTab;
  final VoidCallback onAddTask;
  final VoidCallback onAddProject;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            Icon(
              iconDataForKey(kMindAppIconKey) ?? Icons.psychology_alt_outlined,
            ),
            const SizedBox(width: 10),
            const Text('Mind'),
          ],
        ),
        actions: <Widget>[
          IconButton(
            onPressed: onOpenSettings,
            tooltip: 'Open settings',
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
        bottom: TabBar(
          controller: tabController,
          tabs: const <Widget>[
            Tab(text: 'Incoming'),
            Tab(text: 'Projects'),
            Tab(text: 'Flashcards'),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: <Widget>[
          TaskListView(
            tasks: incomingTasks,
            emptyLabel: '',
            cardLayoutPreset: cardLayoutPreset,
            onTaskTap: onIncomingTaskTap,
            onTaskOptionsTap: onIncomingTaskOptionsTap,
            onMoveTaskToProject: onMoveIncomingTaskToProject,
            onRemoveTask: onRemoveIncomingTask,
            onMoveTask: onMoveIncomingTask,
            onNestTask: onNestIncomingTask,
          ),
          ProjectListView(
            projects: projects,
            projectStacks: projectStacks,
            projectTypes: projectTypes,
            cardLayoutPreset: cardLayoutPreset,
            onVisibleProjectOrderChanged: onProjectOrderChanged,
            onProjectTap: onProjectTap,
            onProjectArchive: onProjectArchive,
            onProjectRestore: onProjectRestore,
            onProjectRemove: onProjectRemove,
            onProjectOptionsTap: onProjectOptionsTap,
            onProjectStackOptionsTap: onProjectStackOptionsTap,
            onProjectStackDrop: (
              List<String> sourceProjectIds,
              List<String> targetProjectIds,
            ) =>
                onProjectStackDrop(sourceProjectIds, targetProjectIds),
            onProjectMoveToStackPosition: onMoveProjectToStackPosition,
          ),
          flashcardsTab,
        ],
      ),
      floatingActionButton: selectedTabIndex == 0
          ? FloatingActionButton(
              onPressed: onAddTask,
              tooltip: 'Add task',
              child: const Icon(Icons.add),
            )
          : selectedTabIndex == 1
              ? FloatingActionButton(
                  onPressed: onAddProject,
                  tooltip: 'Add project',
                  child: const Icon(Icons.add),
                )
              : null,
    );
  }
}
