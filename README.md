# Mind

Minimal Flutter task-management boilerplate with:

- Material 3 app setup
- Feature-oriented folder structure (`lib/src/features/...`)
- Task screen (add, complete, delete)
- Basic widget test for core task flow
- Linux desktop window configured to phone-like portrait size for quick Android-style layout preview

## Getting started

1. Install Flutter SDK and Android Studio (for Android emulator/device).
2. From this project root, install dependencies:
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
   The Linux window opens at `412x915` and is non-resizable to mimic an Android phone layout.
5. Run tests:
   ```bash
   flutter test
   ```
