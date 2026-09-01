# N — Phase 28 Security Hardening

## Change
The client can no longer insert rows directly into `conversation_members`.
Conversation membership creation is restricted to the trusted `create_conversation(uuid)` function.

## Why
The previous policy allowed an authenticated user to add their own membership to an existing conversation when they knew its ID. That did not allow impersonating another user, but it weakened conversation isolation.

## Required deployment
Apply `supabase/schema.sql` to the production Supabase database before relying on this restriction.

## Validation
- ZIP integrity checked.
- No Flutter build is claimed until Codemagic runs `flutter analyze`, `flutter test`, and `flutter build apk --release` successfully.
