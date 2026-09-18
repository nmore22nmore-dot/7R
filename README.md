# N

تطبيق اجتماعي عربي مستقل للفيديو القصير.

## قبل البناء
1. أنشئ مشروع Supabase.
2. نفّذ `supabase/schema.sql` في SQL Editor.
3. أنشئ Storage bucket باسم `post-media` واجعله Public للنسخة التجريبية، أو أضف سياسات Storage المناسبة للإنتاج.
4. في Codemagic أضف:
   - `SUPABASE_URL`
   - `SUPABASE_PUBLISHABLE_KEY`
5. شغّل Workflow `n_android_release`.

## ملاحظة
النسخة تحتوي على البنية الأساسية العاملة: Auth، فيديوهات، نشر، إعجاب، تعليق، حفظ، متابعة، رسائل، ملف شخصي، إشعارات/قصص/عملات في قاعدة البيانات.
البث المباشر والمدفوعات والهدايا الحقيقية تحتاج مزود خدمات خارجي وإعدادات حسابية قبل الإنتاج.


## Wiring stage
The current wiring stage includes: authenticated feed/following feed, reaction state loading, search and public user profiles, follow/unfollow, opening conversations, message attachments, realtime message subscription, profile posts, image/video publishing, story upload with 24-hour expiry, and basic account settings.

### Required external configuration before production
- Supabase project URL and publishable key must be supplied as build variables.
- Run `supabase/schema.sql` in the Supabase SQL editor.
- `post-media` and `message-media` storage buckets/policies are created by the schema.
- N AI requires a protected server/Edge Function and an AI provider key; never put a secret provider key in the Flutter app.
- Real live video requires a live-streaming provider (or a self-hosted media server), Android camera/microphone permissions, and provider credentials. The current Flutter dependencies do not contain a live-streaming SDK, so a production live implementation cannot be truthfully claimed without choosing and configuring that provider.
- Payments/gifts require a payment provider and server-side transaction verification.
