# N — Production Final Package

This package is the complete N application source assembled as one project.

## Included and wired
- N branding and agreed dark/cyan/pink visual system.
- Supabase authentication/session handling.
- Profiles and profile discovery.
- Feed with For You / Following.
- Video playback, preload, views and sharing.
- Image/video post upload.
- Likes, comments, saves, follows.
- Messaging/conversations and notifications infrastructure.
- Security, blocking, reporting and admin infrastructure.
- Wallet/coins/gifts database and RPC path.
- Stories and live-stream database infrastructure.
- Profile editing UI and settings/security.
- N AI Assistant client + Supabase Edge Function.
- Android/Codemagic release configuration.

## Production services
The APK must be built with the project's existing Supabase URL/publishable key secrets. The AI function requires the server-side `OPENAI_API_KEY` secret. Never place provider secrets in Flutter source code.

## Important
A production live-video system and AI provider necessarily depend on server/provider credentials and deployment. The source package includes the application and backend integration points; it does not contain private provider keys.
