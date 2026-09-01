# N Notification Automation

The notification table is now populated by server-side triggers for follows, likes, comments, gifts, and messages.

The triggers run on the database side so clients do not need permission to impersonate another user when creating notifications.

Before production rollout, apply `supabase/schema.sql` to the same database schema that already contains the base N tables (`profiles`, `posts`, `follows`, `post_likes`, `comments`, `messages`, `conversation_members`, and the N wallet tables), then test each event with two test accounts.
