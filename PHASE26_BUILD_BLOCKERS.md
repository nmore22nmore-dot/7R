# Phase 26 — Build Blocker Fixes

- Fixed a Dart compile-time constant error in `lib/main.dart` where a `const Row` contained the runtime value `data.coins`.
- The project still requires a real Flutter CI run (`flutter analyze`, `flutter test`, `flutter build apk --release`) before declaring the build verified.
- The Supabase schema in this repository is a security patch/migration and assumes the core application tables already exist; it is not a standalone fresh-database schema.
- The security settings screen still contains placeholder actions for password change and device/session management; these must be implemented before claiming feature completeness.
