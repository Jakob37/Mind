# Changelog

All notable user-facing changes to this project should be recorded here.

## v0.3.11

- Added flashcard review outcomes for `Failed`, `Hard`, and `Correct` with persisted rescheduling between reviews.
- Flashcards now track due dates and review intervals so correct answers extend the interval, hard answers keep it, and failed answers reset it.

## v0.3.10

- Added selectable image import sizes so Android attachments can be downsized before being stored locally.
- Added automatic cleanup for unused copied attachment files after saves and imports.

## v0.3.9

- Added image attachments for task entries, including Android file selection, persistent local copies, and attachment display in task detail and journal/idea views.

## v0.3.8

- Removed the obsolete people-specific entry sheet files after the generic project-entry form rename.

## v0.3.7

- Renamed the remaining nested-entry add/edit sheets to generic project-entry names so the reusable entry-container flow no longer carries people-specific form naming.

## v0.3.6

- Added a reusable `Exercise` entry-container type with exercise-level descriptions, idea capture, and workout log journal entries.

## v0.3.5

- Switched nested container projects to a generic `entries` data model while keeping backward compatibility for older saved `people` payloads.

## v0.3.4

- Renamed the special People layout into a generic entry-container project layout so the app can support more reusable nested-entry project types without another hard-coded branch.

## v0.3.3

- Moved People-project labels into project type configuration so item and journal wording can be driven by the type instead of hard-coded UI text.

## v0.3.2

- Split the task page shell and flashcard presentation into dedicated view files so future Mind work can add features without growing one giant UI file.

## v0.3.1

- Restored a dedicated pinned projects section on the `Projects` tab so pinned items are grouped separately instead of only being reordered.

## v0.3.0

- Moved the app version entry into Settings so the shell pattern matches the other apps.

## v0.2.3

- Standardized the in-app changelog version pill styling.
- Cleared the existing analyzer warnings in the repository.

## v0.2.2

- Documented the versioning workflow so each committed change keeps `pubspec.yaml`, the in-app version badge, and the GitHub changelog in sync.

## v0.2.1

- Made the app version badge open the GitHub changelog.

## v0.2.0

- Added optional flashcard prompts on idea entries and a `Flashcards` tab for studying saved cards.
- Moved project pinning behavior to the `Projects` tab instead of surfacing pinned projects in `Incoming`.
- Added manual Supabase cloud board upload and restore actions in Settings for signed-in users.
- Fixed Android JSON import to decode UTF-8 correctly, preserving Swedish characters such as `Å`, `Ä`, and `Ö`.

## v0.1.1

- Added automatic local JSON backups.
- Added initial Supabase account scaffolding and sign-in setup.
