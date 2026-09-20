# N 5.2.0 repair notes

This build fixes the verified logic problems found during the app/schema audit:

- Removed the duplicate `_navItem` method and duplicate theme property.
- Bottom navigation is now: الرئيسية / المتابعة / نشر / الرسائل / الملف الشخصي.
- Following feed requests public + followers posts and relies on RLS for privacy/block/age enforcement.
- Private-account visibility is enforced by database policy.
- Blocked users are excluded from post visibility, follows, comments, conversations, messages and gifts.
- Added birth date to signup and server-side 13+ validation.
- Added +21 publishing flag and server-side 21+ read/write enforcement.
- Notification preferences are respected by in-app notification triggers and the FCM Edge Function.
- Message list resolves the other participant's username/avatar.
- Gift RPC now validates the gift name/cost server-side and blocks forged prices.
- Story visibility policy respects account privacy and blocks.

## Still requiring external provider configuration

Some product systems cannot be completed from a source ZIP alone:

- FCM Database Webhook: configure `notifications INSERT -> send-push` in Supabase.
- FCM Edge Function secret: `FIREBASE_SERVICE_ACCOUNT_JSON` and the normal Supabase function secrets must be configured.
- N AI requires a protected AI provider/Edge Function and its server secret.
- Real-money coin purchases require Google Play Billing/product IDs and a verified payment backend.
- Real live streaming requires a streaming provider/server (WebRTC/RTMP infrastructure); the existing Live UI is not a full streaming backend.
