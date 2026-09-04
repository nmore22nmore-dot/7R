# N — Full Build Package

This package is based on the current 7R project and is intended to be uploaded as one complete project.

## Included
- N dark/cyan/pink visual identity.
- Short-video feed with For You / Following.
- Video playback, preload, likes, comments, saves and sharing.
- Image publishing and video publishing from the Create screen.
- Profile, discovery/search, follow/unfollow.
- Messaging and notifications infrastructure.
- Wallet, coins and gifts infrastructure.
- Stories database infrastructure.
- Live section with live-room records, live studio camera UI and live viewer UI.
- N AI assistant client and Supabase Edge Function integration.
- Security, blocking, reporting and admin infrastructure.
- Android and Codemagic release configuration.

## Required deployment setup
- Supabase URL and publishable key are supplied to Codemagic as build-time variables.
- `OPENAI_API_KEY` must remain server-side in the Supabase Edge Function environment.
- The live UI is wired to `live_streams` and the device camera. A production-grade multi-user live video transport/CDN/WebRTC provider is still required to transmit the camera feed to remote viewers; this package does not embed private provider credentials.

## Verification
The ZIP archive itself should be checked with `unzip -t`. Flutter analysis/build must be run in Codemagic because the local environment used to assemble this package does not contain the Flutter SDK.
