# Changelog

All notable user-facing changes to this project should be recorded here.

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
