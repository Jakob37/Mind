# Mind

A Flutter task board app focused on quickly moving ideas into projects.

## Current capabilities

- Two-tab board:
  - `Incoming` for unassigned tasks
  - `Projects` for named project containers
- Task and project creation via bottom sheets.
- Context menus for task/project actions:
  - edit title/body
  - set card color
  - move tasks to a project
  - open/remove projects
- Stack header settings:
  - rename stack
  - set stack color
- Project detail view with two task lanes:
  - `Thinking (ideas)`
  - `Planning (action items)`
  - tasks can be switched between lanes
- Specialized project types:
  - `Knowledge` projects support sessions and quick capture
  - `Diary` projects support timestamped journal entries
  - `People` projects combine interaction journals with ideas
- Reorder mode (long press + drag handles) for incoming tasks, projects, and project tasks.
- Swipe-left delete for tasks/projects with confirmation dialog.
- Settings screen:
  - export board data as JSON
  - copy JSON to clipboard
  - Android-only file export/share
  - custom labels for predefined card colors
- Android home-screen widget action for quickly opening the add-task flow.

## Persistence and data schema

- Local persistence uses `shared_preferences`.
- Current schema version is `20`.
- Migration pipeline supports legacy payloads:
  - unversioned legacy key: `task_board_state_v1`
  - versioned payloads: v1 -> v20
- If persisted data is corrupted, autosave is paused to avoid overwriting potentially recoverable data.

## Project structure

- App entry: `lib/main.dart`
- App shell/theme: `lib/src/app.dart`
- Feature code: `lib/src/features/tasks`
  - Domain models: `domain/task_models.dart`
  - Persistence/migrations: `data/task_storage.dart`
  - Screens: `presentation/task_page.dart`, `presentation/pages/*`
  - Reusable UI sheets/lists: `presentation/widgets/*`
- Tests:
  - End-to-end style widget flow tests: `test/widget_test.dart`
  - Targeted persistence/migration tests: `test/features/tasks/data/task_storage_test.dart`

## Getting started

1. Install Flutter SDK and Android Studio.
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run on Android:
   ```bash
   flutter run -d android
   ```
4. Run on Linux with phone-like viewport:
   ```bash
   flutter run -d linux
   ```
   The Linux window opens at `412x915` and is non-resizable for phone-like layout testing.

## Quality checks

Run these from project root:

```bash
flutter analyze
flutter test
```

To run only persistence/migration tests:

```bash
flutter test test/features/tasks/data/task_storage_test.dart
```
