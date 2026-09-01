# N — Final Release Checklist

## Completed in repository
- Release CI runs `flutter analyze` and `flutter test`.
- Release APK build uses Dart obfuscation and split debug symbols.
- APK SHA-256 is generated as a CI artifact.
- Release keystore is supplied through CI secrets, not stored in the repository.
- Supabase credentials are supplied through CI secrets.
- Development/test coin-grant paths are removed.
- Android cleartext traffic is disabled.

## Required before public launch
1. Apply `supabase/schema.sql` to the production Supabase project.
2. Verify RLS and database triggers with two or more test accounts.
3. Configure real payment processing before enabling coin purchases.
4. Configure a real live-stream provider before enabling live rooms.
5. Configure Android push notifications and verify delivery.
6. Configure the release keystore secrets in CI.
7. Run the CI release build and install the generated APK on physical devices.
8. Complete end-to-end tests for authentication, feed, video upload/playback, social actions, messaging, notifications, wallet/gifts, security and admin controls.

## Important
The repository is not declared publicly production-ready until the external services and physical-device checks above pass.
