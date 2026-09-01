# N Release QA — Phase 17

## Automated checks available
- Flutter smoke test for the N design system.
- CI runs `flutter analyze` and `flutter test` before Android release builds.
- Release build uses obfuscation and split debug info.

## Static-data cleanup completed in this phase
- Removed hard-coded sample story names from the legacy HomePage and derive visible author names from loaded posts.
- Home header coin balance now reads the authenticated NData balance instead of displaying a hard-coded zero.

## Release blockers still requiring a real device/backend environment
- `flutter analyze` / `flutter test` must be executed with Flutter SDK installed.
- Supabase production URL/keys, Storage policies and Realtime settings must be verified against the deployed project.
- A real payment provider must be connected before selling coins.
- Live streaming requires a production streaming provider/service; the current UI is not a production streaming server.
- Android release signing credentials must be supplied in the build environment.

## Security note
No software can be guaranteed impossible to crack. The release path should combine server-side authorization, RLS, secret isolation, rate limiting, monitoring, secure signing and client hardening.
