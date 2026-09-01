# N — Release Preflight

This repository is prepared for a real Flutter release build, but a release APK is not considered production-ready until the external environment is validated.

## CI checks
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build apk --release --obfuscate --split-debug-info=build/symbols`

## Required production configuration
- Supabase URL and publishable key supplied through CI secrets.
- Production Supabase schema applied and RLS verified.
- Android release keystore supplied through CI secrets.
- Real payment provider configured before enabling coin purchases.
- Production live-stream provider configured before enabling live-room creation.
- Push notification credentials configured and delivery tested.

## Security baseline
- Do not ship service-role or other server secrets in the Flutter client.
- Keep `usesCleartextTraffic=false`.
- Keep admin authorization server-side through database/RPC checks.
- Keep development/test coin grants unavailable to ordinary authenticated clients.
- Preserve obfuscation symbols as a private CI artifact for crash analysis.

## Device validation
Before publishing, test on physical Android devices for:
- Login, signup, logout, session refresh.
- Video playback, scrolling, upload and cover upload.
- Likes, comments, follows, saves and sharing.
- Messaging and notifications.
- Wallet/gifts and payment flow after provider integration.
- Live streaming after provider integration.
- Blocking, reporting and suspension behavior.
- Slow network, offline/reconnect and app restart.
