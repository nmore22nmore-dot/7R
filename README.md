# N — 5.4.0 Final Hardened

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

## Production integration checklist (after code completion)

The application code now contains the client/server wiring for offline media, voice messages, persistent live comments/viewers, message read receipts, Google Play coin purchases, push notifications, and N AI.

Required external configuration before production:
1. Deploy `supabase/functions/verify-purchase`.
2. Add Supabase Edge Function secrets `GOOGLE_SERVICE_ACCOUNT_JSON` and `GOOGLE_PLAY_PACKAGE_NAME=com.n.n_app`.
3. Create Google Play one-time consumable products with IDs `n_coins_100`, `n_coins_550`, `n_coins_1200`, `n_coins_2600`, `n_coins_7000`.
4. Set `OPENAI_API_KEY` for the `ai-chat` Edge Function.
5. Connect a real live-stream provider/ingest URL for broadcasters; `live_rooms` and live chat are fully persisted, but Supabase itself is not an RTMP/WebRTC broadcaster.
