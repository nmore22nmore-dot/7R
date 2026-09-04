# N AI Assistant
Set `OPENAI_API_KEY` and optionally `OPENAI_MODEL` as Supabase Edge Function secrets, then deploy this function.
The mobile app calls the function through the authenticated Supabase session; the API key is never shipped inside the APK.
