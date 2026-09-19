# N — 5.0.3 Final

Arabic-first short-video social app built with Flutter and Supabase.

## Included
- Vertical short-video feed with For You / Following.
- Auth, password recovery and profile management.
- Likes, saves, follows and comments.
- Search and public profiles.
- Messaging with Realtime refresh and private file attachments.
- Media publishing with private Supabase Storage and signed URLs.
- RTL dark UI and N branding.
- Settings, privacy controls, activity-oriented navigation and creator tools.

## Supabase
Run `supabase/schema.sql` in the target Supabase SQL editor before testing the app. It creates/updates the required tables, RLS policies, Storage buckets and Realtime publication entries.

## Build
Codemagic is configured to create the Android host project if it is not present, inject Supabase variables, run `flutter pub get`, `flutter analyze`, `flutter test`, and build the release APK.

Required environment variables:
- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

The app uses the auth callback `n://auth-callback`; configure the same redirect URL in Supabase Auth.

## Release note
The packaging environment did not include the Flutter SDK, so the final archive could not be locally compiled here. The Codemagic workflow is the authoritative build/test gate.
