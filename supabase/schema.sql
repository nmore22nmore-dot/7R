-- =========================================================
-- N — FINAL DATABASE SCHEMA
-- =========================================================
-- N social platform
-- TikTok-like experience with N branding
-- =========================================================

create extension if not exists "pgcrypto";

-- =========================================================
-- PROFILES
-- =========================================================

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,

  name text not null default 'مستخدم N',
  username text not null unique,
  email text,

  age integer not null default 25,
  avatar_url text,

  verified boolean not null default false,

  private_account boolean not null default false,
  activity_status boolean not null default true,
  allow_messages boolean not null default true,
  notifications boolean not null default true,
  sounds boolean not null default true,

  supporter_level integer not null default 0,
  coins bigint not null default 0,

  followers_count bigint not null default 0,
  following_count bigint not null default 0,
  posts_count bigint not null default 0,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint profiles_age_check
    check (age between 13 and 120),

  constraint profiles_username_length_check
    check (char_length(username) >= 4),

  constraint profiles_username_no_at_check
    check (position('@' in username) = 0),

  constraint profiles_username_no_space_check
    check (position(' ' in username) = 0)
);

create index if not exists profiles_username_idx
on public.profiles(username);

-- =========================================================
-- POSTS
-- =========================================================

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  text text not null default '',

  adult boolean not null default false,

  visibility text not null default 'عام',

  video boolean not null default false,
  video_url text,
  image_url text,

  likes_count bigint not null default 0,
  comments_count bigint not null default 0,
  saves_count bigint not null default 0,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint posts_visibility_check
    check (visibility in ('عام', 'المتابعون', 'خاص'))
);

create index if not exists posts_created_at_idx
on public.posts(created_at desc);

create index if not exists posts_user_id_idx
on public.posts(user_id);

-- =========================================================
-- LIKES
-- =========================================================

create table if not exists public.post_likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),

  primary key (post_id, user_id)
);

-- =========================================================
-- COMMENTS
-- =========================================================

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),

  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,

  text text not null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists comments_post_id_idx
on public.comments(post_id);

create index if not exists comments_created_at_idx
on public.comments(created_at desc);

-- =========================================================
-- SAVED POSTS
-- =========================================================

create table if not exists public.saved_posts (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),

  primary key (post_id, user_id)
);

-- =========================================================
-- FOLLOWS
-- =========================================================

create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,

  created_at timestamptz not null default now(),

  primary key (follower_id, following_id),

  constraint follows_no_self
    check (follower_id <> following_id)
);

create index if not exists follows_follower_idx
on public.follows(follower_id);

create index if not exists follows_following_idx
on public.follows(following_id);

-- =========================================================
-- STORIES
-- =========================================================

create table if not exists public.stories (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null references public.profiles(id) on delete cascade,

  media_url text not null,
  media_type text not null default 'image',

  adult boolean not null default false,

  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours'),

  constraint stories_media_type_check
    check (media_type in ('image', 'video'))
);

create index if not exists stories_user_id_idx
on public.stories(user_id);

create index if not exists stories_expires_at_idx
on public.stories(expires_at);

-- =========================================================
-- STORY VIEWS
-- =========================================================

create table if not exists public.story_views (
  story_id uuid not null references public.stories(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,

  viewed_at timestamptz not null default now(),

  primary key (story_id, user_id)
);

-- =========================================================
-- CONVERSATIONS
-- =========================================================

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================================================
-- CONVERSATION MEMBERS
-- =========================================================

create table if not exists public.conversation_members (
  conversation_id uuid not null
    references public.conversations(id)
    on delete cascade,

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  joined_at timestamptz not null default now(),

  primary key (conversation_id, user_id)
);

create index if not exists conversation_members_user_idx
on public.conversation_members(user_id);

-- =========================================================
-- MESSAGES
-- =========================================================

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),

  conversation_id uuid not null
    references public.conversations(id)
    on delete cascade,

  sender_id uuid not null
    references public.profiles(id)
    on delete cascade,

  text text not null,

  read_at timestamptz,

  created_at timestamptz not null default now()
);

create index if not exists messages_conversation_idx
on public.messages(conversation_id, created_at);

create index if not exists messages_sender_idx
on public.messages(sender_id);

-- =========================================================
-- NOTIFICATIONS
-- =========================================================

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  actor_id uuid
    references public.profiles(id)
    on delete cascade,

  type text not null,

  post_id uuid
    references public.posts(id)
    on delete cascade,

  comment_id uuid
    references public.comments(id)
    on delete cascade,

  message text not null default '',

  read boolean not null default false,

  created_at timestamptz not null default now()
);

create index if not exists notifications_user_idx
on public.notifications(user_id, created_at desc);

-- =========================================================
-- LIVE STREAMS
-- =========================================================

create table if not exists public.live_streams (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  title text not null default 'بث مباشر',

  thumbnail_url text,

  stream_url text,

  status text not null default 'live',

  adult boolean not null default false,

  viewers_count bigint not null default 0,

  likes_count bigint not null default 0,

  gifts_count bigint not null default 0,

  started_at timestamptz not null default now(),

  ended_at timestamptz,

  created_at timestamptz not null default now(),

  constraint live_stream_status_check
    check (status in ('scheduled', 'live', 'ended'))
);

create index if not exists live_streams_status_idx
on public.live_streams(status);

create index if not exists live_streams_user_idx
on public.live_streams(user_id);

-- =========================================================
-- LIVE VIEWERS
-- =========================================================

create table if not exists public.live_viewers (
  live_id uuid not null
    references public.live_streams(id)
    on delete cascade,

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  joined_at timestamptz not null default now(),
  left_at timestamptz,

  primary key (live_id, user_id)
);

-- =========================================================
-- LIVE COMMENTS
-- =========================================================

create table if not exists public.live_comments (
  id uuid primary key default gen_random_uuid(),

  live_id uuid not null
    references public.live_streams(id)
    on delete cascade,

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  text text not null,

  created_at timestamptz not null default now()
);

create index if not exists live_comments_live_idx
on public.live_comments(live_id, created_at);

-- =========================================================
-- GIFTS
-- =========================================================

create table if not exists public.gifts (
  id uuid primary key default gen_random_uuid(),

  name text not null unique,

  icon text,

  price_coins bigint not null,

  active boolean not null default true,

  created_at timestamptz not null default now(),

  constraint gifts_price_check
    check (price_coins > 0)
);

-- =========================================================
-- LIVE GIFTS
-- =========================================================

create table if not exists public.live_gifts (
  id uuid primary key default gen_random_uuid(),

  live_id uuid not null
    references public.live_streams(id)
    on delete cascade,

  sender_id uuid not null
    references public.profiles(id)
    on delete cascade,

  receiver_id uuid not null
    references public.profiles(id)
    on delete cascade,

  gift_id uuid not null
    references public.gifts(id)
    on delete restrict,

  quantity integer not null default 1,

  total_coins bigint not null,

  created_at timestamptz not null default now(),

  constraint live_gifts_quantity_check
    check (quantity > 0)
);

create index if not exists live_gifts_live_idx
on public.live_gifts(live_id);

-- =========================================================
-- COIN TRANSACTIONS
-- =========================================================

create table if not exists public.coin_transactions (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  amount bigint not null,

  type text not null,

  reference_id uuid,

  description text not null default '',

  created_at timestamptz not null default now(),

  constraint coin_transaction_type_check
    check (
      type in (
        'purchase',
        'gift_sent',
        'gift_received',
        'admin',
        'refund'
      )
    )
);

create index if not exists coin_transactions_user_idx
on public.coin_transactions(user_id, created_at desc);

-- =========================================================
-- SEARCH / TRENDING
-- =========================================================

create table if not exists public.trending_topics (
  id uuid primary key default gen_random_uuid(),

  topic text not null unique,

  posts_count bigint not null default 0,

  score double precision not null default 0,

  updated_at timestamptz not null default now()
);

-- =========================================================
-- REPORTS
-- =========================================================

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),

  reporter_id uuid not null
    references public.profiles(id)
    on delete cascade,

  post_id uuid
    references public.posts(id)
    on delete cascade,

  reported_user_id uuid
    references public.profiles(id)
    on delete cascade,

  reason text not null,

  details text,

  status text not null default 'pending',

  created_at timestamptz not null default now(),

  constraint reports_status_check
    check (status in ('pending', 'reviewed', 'resolved', 'rejected'))
);

-- =========================================================
-- BLOCKS
-- =========================================================

create table if not exists public.blocks (
  blocker_id uuid not null
    references public.profiles(id)
    on delete cascade,

  blocked_id uuid not null
    references public.profiles(id)
    on delete cascade,

  created_at timestamptz not null default now(),

  primary key (blocker_id, blocked_id),

  constraint blocks_no_self
    check (blocker_id <> blocked_id)
);

-- =========================================================
-- UPDATED AT
-- =========================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_updated_at
on public.profiles;

create trigger profiles_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

drop trigger if exists posts_updated_at
on public.posts;

create trigger posts_updated_at
before update on public.posts
for each row
execute function public.set_updated_at();

drop trigger if exists comments_updated_at
on public.comments;

create trigger comments_updated_at
before update on public.comments
for each row
execute function public.set_updated_at();

drop trigger if exists conversations_updated_at
on public.conversations;

create trigger conversations_updated_at
before update on public.conversations
for each row
execute function public.set_updated_at();

-- =========================================================
-- AUTH → PROFILE
-- =========================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  generated_username text;
  supplied_username text;
  supplied_name text;
  supplied_age integer;
begin

  supplied_username :=
    lower(
      regexp_replace(
        coalesce(new.raw_user_meta_data->>'username', ''),
        '[^a-zA-Z0-9_.]',
        '',
        'g'
      )
    );

  supplied_name :=
    nullif(
      trim(new.raw_user_meta_data->>'name'),
      ''
    );

  supplied_age :=
    case
      when (new.raw_user_meta_data->>'age') ~ '^[0-9]+$'
      then (new.raw_user_meta_data->>'age')::integer
      else 25
    end;

  if char_length(supplied_username) >= 4 then
    generated_username := supplied_username;
  else
    generated_username :=
      'user_' ||
      substr(replace(new.id::text, '-', ''), 1, 12);
  end if;

  if exists (
    select 1
    from public.profiles
    where username = generated_username
  ) then
    generated_username :=
      'user_' ||
      substr(replace(new.id::text, '-', ''), 1, 16);
  end if;

  insert into public.profiles (
    id,
    name,
    username,
    email,
    age
  )
  values (
    new.id,
    coalesce(supplied_name, 'مستخدم N'),
    generated_username,
    new.email,
    greatest(13, least(120, supplied_age))
  );

  return new;
end;
$$;

drop trigger if exists on_auth_user_created
on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();

-- =========================================================
-- POST COUNTERS
-- =========================================================

create or replace function public.refresh_post_counters()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_post uuid;
begin

  target_post := coalesce(new.post_id, old.post_id);

  update public.posts
  set
    likes_count = (
      select count(*)
      from public.post_likes
      where post_id = target_post
    ),
    comments_count = (
      select count(*)
      from public.comments
      where post_id = target_post
    ),
    saves_count = (
      select count(*)
      from public.saved_posts
      where post_id = target_post
    )
  where id = target_post;

  return coalesce(new, old);
end;
$$;

drop trigger if exists post_likes_counter
on public.post_likes;

create trigger post_likes_counter
after insert or delete on public.post_likes
for each row
execute function public.refresh_post_counters();

drop trigger if exists comments_counter
on public.comments;

create trigger comments_counter
after insert or delete on public.comments
for each row
execute function public.refresh_post_counters();

drop trigger if exists saved_posts_counter
on public.saved_posts;

create trigger saved_posts_counter
after insert or delete on public.saved_posts
for each row
execute function public.refresh_post_counters();

-- =========================================================
-- PROFILE COUNTERS
-- =========================================================

create or replace function public.refresh_profile_follow_counters()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_follower uuid;
  target_following uuid;
begin

  target_follower := coalesce(new.follower_id, old.follower_id);
  target_following := coalesce(new.following_id, old.following_id);

  update public.profiles
  set following_count = (
    select count(*)
    from public.follows
    where follower_id = target_follower
  )
  where id = target_follower;

  update public.profiles
  set followers_count = (
    select count(*)
    from public.follows
    where following_id = target_following
  )
  where id = target_following;

  return coalesce(new, old);
end;
$$;

drop trigger if exists follows_counter
on public.follows;

create trigger follows_counter
after insert or delete on public.follows
for each row
execute function public.refresh_profile_follow_counters();

-- =========================================================
-- POST COUNT ON PROFILE
-- =========================================================

create or replace function public.refresh_profile_post_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_user uuid;
begin

  target_user := coalesce(new.user_id, old.user_id);

  update public.profiles
  set posts_count = (
    select count(*)
    from public.posts
    where user_id = target_user
  )
  where id = target_user;

  return coalesce(new, old);
end;
$$;

drop trigger if exists posts_profile_counter
on public.posts;

create trigger posts_profile_counter
after insert or delete on public.posts
for each row
execute function public.refresh_profile_post_count();

-- =========================================================
-- RLS
-- =========================================================

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.comments enable row level security;
alter table public.saved_posts enable row level security;
alter table public.follows enable row level security;
alter table public.stories enable row level security;
alter table public.story_views enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.notifications enable row level security;
alter table public.live_streams enable row level security;
alter table public.live_viewers enable row level security;
alter table public.live_comments enable row level security;
alter table public.gifts enable row level security;
alter table public.live_gifts enable row level security;
alter table public.coin_transactions enable row level security;
alter table public.trending_topics enable row level security;
alter table public.reports enable row level security;
alter table public.blocks enable row level security;

-- =========================================================
-- PROFILES
-- =========================================================

drop policy if exists profiles_select_authenticated
on public.profiles;

create policy profiles_select_authenticated
on public.profiles
for select
to authenticated
using (true);

drop policy if exists profiles_update_own
on public.profiles;

create policy profiles_update_own
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- =========================================================
-- POSTS
-- =========================================================

drop policy if exists posts_select_authenticated
on public.posts;

create policy posts_select_authenticated
on public.posts
for select
to authenticated
using (
  user_id = auth.uid()
  or visibility = 'عام'
  or (
    visibility = 'المتابعون'
    and exists (
      select 1
      from public.follows f
      where f.follower_id = auth.uid()
        and f.following_id = posts.user_id
    )
  )
);

drop policy if exists posts_insert_own
on public.posts;

create policy posts_insert_own
on public.posts
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists posts_update_own
on public.posts;

create policy posts_update_own
on public.posts
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists posts_delete_own
on public.posts;

create policy posts_delete_own
on public.posts
for delete
to authenticated
using (user_id = auth.uid());

-- =========================================================
-- LIKES
-- =========================================================

drop policy if exists likes_select_authenticated
on public.post_likes;

create policy likes_select_authenticated
on public.post_likes
for select
to authenticated
using (true);

drop policy if exists likes_insert_own
on public.post_likes;

create policy likes_insert_own
on public.post_likes
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists likes_delete_own
on public.post_likes;

create policy likes_delete_own
on public.post_likes
for delete
to authenticated
using (user_id = auth.uid());

-- =========================================================
-- COMMENTS
-- =========================================================

drop policy if exists comments_select_authenticated
on public.comments;

create policy comments_select_authenticated
on public.comments
for select
to authenticated
using (true);

drop policy if exists comments_insert_own
on public.comments;

create policy comments_insert_own
on public.comments
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists comments_update_own
on public.comments;

create policy comments_update_own
on public.comments
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists comments_delete_own
on public.comments;

create policy comments_delete_own
on public.comments
for delete
to authenticated
using (user_id = auth.uid());

-- =========================================================
-- SAVED POSTS
-- =========================================================

drop policy if exists saved_select_own
on public.saved_posts;

create policy saved_select_own
on public.saved_posts
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists saved_insert_own
on public.saved_posts;

create policy saved_insert_own
on public.saved_posts
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists saved_delete_own
on public.saved_posts;

create policy saved_delete_own
on public.saved_posts
for delete
to authenticated
using (user_id = auth.uid());

-- =========================================================
-- FOLLOWS
-- =========================================================

drop policy if exists follows_select_authenticated
on public.follows;

create policy follows_select_authenticated
on public.follows
for select
to authenticated
using (true);

drop policy if exists follows_insert_own
on public.follows;

create policy follows_insert_own
on public.follows
for insert
to authenticated
with check (
  follower_id = auth.uid()
  and follower_id <> following_id
);

drop policy if exists follows_delete_own
on public.follows;

create policy follows_delete_own
on public.follows
for delete
to authenticated
using (follower_id = auth.uid());

-- =========================================================
-- STORIES
-- =========================================================

drop policy if exists stories_select_authenticated
on public.stories;

create policy stories_select_authenticated
on public.stories
for select
to authenticated
using (
  user_id = auth.uid()
  or (
    expires_at > now()
    and (
      adult = false
      or exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and p.age >= 21
      )
    )
  )
);

drop policy if exists stories_insert_own
on public.stories;

create policy stories_insert_own
on public.stories
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists stories_delete_own
on public.stories;

create policy stories_delete_own
on public.stories
for delete
to authenticated
using (user_id = auth.uid());

-- =========================================================
-- STORY VIEWS
-- =========================================================

drop policy if exists story_views_select_authenticated
on public.story_views;

create policy story_views_select_authenticated
on public.story_views
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists story_views_insert_own
on public.story_views;

create policy story_views_insert_own
on public.story_views
for insert
to authenticated
with check (user_id = auth.uid());

-- =========================================================
-- CONVERSATIONS
-- =========================================================

drop policy if exists conversations_select_member
on public.conversations;

create policy conversations_select_member
on public.conversations
for select
to authenticated
using (
  exists (
    select 1
    from public.conversation_members cm
    where cm.conversation_id = conversations.id
      and cm.user_id = auth.uid()
  )
);

drop policy if exists conversations_insert_authenticated
on public.conversations;

create policy conversations_insert_authenticated
on public.conversations
for insert
to authenticated
with check (true);

-- =========================================================
-- CONVERSATION MEMBERS
-- =========================================================

drop policy if exists members_select_member
on public.conversation_members;

create policy members_select_member
on public.conversation_members
for select
to authenticated
using (
  exists (
    select 1
    from public.conversation_members mine
    where mine.conversation_id = conversation_members.conversation_id
      and mine.user_id = auth.uid()
  )
);

drop policy if exists members_insert_own
on public.conversation_members;

create policy members_insert_own
on public.conversation_members
for insert
to authenticated
with check (user_id = auth.uid());

-- =========================================================
-- MESSAGES
-- =========================================================

drop policy if exists messages_select_member
on public.messages;

create policy messages_select_member
on public.messages
for select
to authenticated
using (
  exists (
    select 1
    from public.conversation_members cm
    where cm.conversation_id = messages.conversation_id
      and cm.user_id = auth.uid()
  )
);

drop policy if exists messages_insert_member
on public.messages;

create policy messages_insert_member
on public.messages
for insert
to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1
    from public.conversation_members cm
    where cm.conversation_id = messages.conversation_id
      and cm.user_id = auth.uid()
  )
);

-- =========================================================
-- NOTIFICATIONS
-- =========================================================

drop policy if exists notifications_select_own
on public.notifications;

create policy notifications_select_own
on public.notifications
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists notifications_update_own
on public.notifications;

create policy notifications_update_own
on public.notifications
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- =========================================================
-- LIVE STREAMS
-- =========================================================

drop policy if exists live_select_authenticated
on public.live_streams;

create policy live_select_authenticated
on public.live_streams
for select
to authenticated
using (
  status = 'live'
  and (
    adult = false
    or exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.age >= 21
    )
  )
  or user_id = auth.uid()
);

drop policy if exists live_insert_own
on public.live_streams;

create policy live_insert_own
on public.live_streams
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists live_update_own
on public.live_streams;

create policy live_update_own
on public.live_streams
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- =========================================================
-- LIVE VIEWERS
-- =========================================================

drop policy if exists live_viewers_select_authenticated
on public.live_viewers;

create policy live_viewers_select_authenticated
on public.live_viewers
for select
to authenticated
using (true);

drop policy if exists live_viewers_insert_own
on public.live_viewers;

create policy live_viewers_insert_own
on public.live_viewers
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists live_viewers_delete_own
on public.live_viewers;

create policy live_viewers_delete_own
on public.live_viewers
for delete
to authenticated
using (user_id = auth.uid());

-- =========================================================
-- LIVE COMMENTS
-- =========================================================

drop policy if exists live_comments_select_authenticated
on public.live_comments;

create policy live_comments_select_authenticated
on public.live_comments
for select
to authenticated
using (true);

drop policy if exists live_comments_insert_own
on public.live_comments;

create policy live_comments_insert_own
on public.live_comments
for insert
to authenticated
with check (user_id = auth.uid());

-- =========================================================
-- GIFTS
-- =========================================================

drop policy if exists gifts_select_authenticated
on public.gifts;

create policy gifts_select_authenticated
on public.gifts
for select
to authenticated
using (active = true);

-- =========================================================
-- LIVE GIFTS
-- =========================================================

drop policy if exists live_gifts_select_authenticated
on public.live_gifts;

create policy live_gifts_select_authenticated
on public.live_gifts
for select
to authenticated
using (
  sender_id = auth.uid()
  or receiver_id = auth.uid()
);

drop policy if exists live_gifts_insert_sender
on public.live_gifts;

create policy live_gifts_insert_sender
on public.live_gifts
for insert
to authenticated
with check (sender_id = auth.uid());

-- =========================================================
-- COINS
-- =========================================================

drop policy if exists coins_select_own
on public.coin_transactions;

create policy coins_select_own
on public.coin_transactions
for select
to authenticated
using (user_id = auth.uid());

-- =========================================================
-- TRENDING
-- =========================================================

drop policy if exists trending_select_authenticated
on public.trending_topics;

create policy trending_select_authenticated
on public.trending_topics
for select
to authenticated
using (true);

-- =========================================================
-- REPORTS
-- =========================================================

drop policy if exists reports_insert_own
on public.reports;

create policy reports_insert_own
on public.reports
for insert
to authenticated
with check (reporter_id = auth.uid());

drop policy if exists reports_select_own
on public.reports;

create policy reports_select_own
on public.reports
for select
to authenticated
using (reporter_id = auth.uid());

-- =========================================================
-- BLOCKS
-- =========================================================

drop policy if exists blocks_select_own
on public.blocks;

create policy blocks_select_own
on public.blocks
for select
to authenticated
using (blocker_id = auth.uid());

drop policy if exists blocks_insert_own
on public.blocks;

create policy blocks_insert_own
on public.blocks
for insert
to authenticated
with check (
  blocker_id = auth.uid()
  and blocker_id <> blocked_id
);

drop policy if exists blocks_delete_own
on public.blocks;

create policy blocks_delete_own
on public.blocks
for delete
to authenticated
using (blocker_id = auth.uid());

-- =========================================================
-- REALTIME
-- =========================================================

do $$
begin

  begin
    alter publication supabase_realtime add table public.posts;
  exception when duplicate_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.comments;
  exception when duplicate_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.post_likes;
  exception when duplicate_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.messages;
  exception when duplicate_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.notifications;
  exception when duplicate_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.live_streams;
  exception when duplicate_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.live_comments;
  exception when duplicate_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.live_gifts;
  exception when duplicate_object then null;
  end;

end;
$$;

-- =========================================================
-- INITIAL GIFTS
-- =========================================================

insert into public.gifts (name, icon, price_coins)
values
  ('قلب', '❤️', 10),
  ('وردة', '🌹', 50),
  ('نجمة', '⭐', 100),
  ('تاج', '👑', 500),
  ('ألماسة', '💎', 1000)
on conflict (name) do nothing;

-- =========================================================
-- END
-- =========================================================
