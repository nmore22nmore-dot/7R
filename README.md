# N — Build Ready

This edition is intentionally dependency-light: Flutter SDK + Material only. It avoids the experimental Dart dot-shorthand syntax that caused the previous Codemagic failure.

## Included
- Arabic RTL UI
- Sign up / sign in demo flow
- Username validation (4+)
- Birth date and age calculation
- +21 content gate in the local app
- Feed, stories, likes, comments, saves, share UI
- Explore/search, follow UI, trending topics
- Create posts with visibility and +21 flag
- Notifications UI
- Profile and logout
- Android project
- Codemagic workflow with `flutter analyze` before APK build

## Important
This build is a standalone/offline functional prototype. It does not contain a real server account system, cloud database, real-time messaging, media upload service, payments, or production moderation backend. Those require backend credentials/services and cannot honestly be claimed as included without them.

## Build
`flutter pub get`
`flutter analyze`
`flutter build apk --release`
