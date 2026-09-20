# N final repair pass

This pass converts several previously demonstrative areas into real Supabase-backed flows:
- Feed visibility is delegated to the database RLS policy instead of client-side public filtering.
- Added real Stories UI, upload, signed viewing URLs, expiry filtering, and private/block-aware storage policies.
- Replaced the custom non-standard QR drawing with QR.Flutter.
- Profile visitors and blocked users now resolve usernames/avatars instead of showing UUIDs.
- N AI now calls the protected `ai-chat` Supabase Edge Function. Configure `OPENAI_API_KEY` (and optionally `OPENAI_MODEL`) as Supabase Edge Function secrets.
- Post-media storage access now reuses `can_read_post`, including private/+21/block rules.

Still provider-dependent: real live video streaming and real-money coin purchases require credentials/configuration for a live-stream/payment provider; the app must not pretend those are active without those credentials.

## 5.3.0+57 Integration pass
- Added real voice-message recording/upload/playback in chats using `record`, `path_provider`, and `audioplayers`.
- Extended `messages.media_type` to support `voice`.
- Added Supabase `live_rooms` metadata table and RLS.
- Replaced hard-coded live-room list with live-room records from Supabase and profile data.
- Live room can render a supplied external stream URL through `video_player`; an actual broadcaster/provider is still required to publish a stream.
- Codemagic remains the authoritative Flutter analyze/test/build environment because this workspace does not contain the Flutter SDK.

## 5.4.0+58 hardening pass
- Secured message read receipts behind `mark_conversation_read()` instead of allowing general message updates.
- Added automatic in-app notification creation for new messages.
- Added `message` push-notification text handling.
- Secured N AI Edge Function with Supabase JWT validation before forwarding requests to the AI provider.
- Removed duplicate `live_rooms` read-policy creation from the middle of the schema; the final block owns the block-aware policy.
- Kept Google Play purchase verification server-side; the client never credits coins directly.

External production configuration still required by the platform owner: Supabase Edge Function secrets, database webhook for `send-push`, Google Play products/service account, and a real live-stream provider/stream URL.

## 5.4.0 release-build reliability pass
- Fixed the Codemagic Firebase Gradle plugin injection regex (the previous expression was over-escaped).
- Added explicit Supabase environment validation before build.
- Added release APK and AAB builds as separate gates.
- Added release signing configuration using Codemagic CM_KEYSTORE/CM_KEYSTORE_PATH and CM_* password variables.
- Standardized the Android application/package identity to `com.n.n_app`, matching `firebase/google-services.json`.
- Updated the Google Play verification function default package to `com.n.n_app`.
- Added a GitHub Flutter CI workflow for `flutter analyze`, tests, APK and AAB builds.
- Added repository ignores for generated Android signing files and Flutter build output.

Important: external provider credentials and store configuration remain required. No source-code change can manufacture valid Supabase, Firebase, Google Play, OpenAI, or live-stream credentials.
