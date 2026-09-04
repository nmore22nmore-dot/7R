# N Final E2E Release Gate

## Automated gates
- `flutter analyze`
- `flutter test`
- `flutter build apk --release`
- APK existence check
- SHA-256 checksum artifact

## Manual device gates
- Sign in / sign out
- Feed video playback and swipe
- Like, comment, follow, save, share
- Publish video and cover upload
- Profile and public profile visibility
- Messages and notifications
- Wallet balance and gift sending
- Security, block and report
- Admin controls with an admin account

## Production prerequisites
- Apply and verify `supabase/schema.sql` against the production Supabase project.
- Configure production Supabase secrets in Codemagic.
- Configure Android signing secrets in Codemagic.
- Configure real payment provider before selling coins.
- Configure real live-stream provider before enabling production live streaming.

This gate intentionally does not claim device/E2E completion until the Release APK has been installed and tested on a physical Android device.
