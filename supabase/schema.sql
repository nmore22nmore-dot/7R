-- ============================================================
-- N / 7R - COMPLETE SUPABASE SCHEMA
-- Safe upgrade for an existing database
-- ============================================================

create extension if not exists pgcrypto;

-- ============================================================
-- 1. PROFILES
-- ============================================================

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  avatar_url text,
  bio text default '',
  is_verified boolean default false,
  is_admin boolean default false,
  is_private boolean not null default false,
  notifications_enabled boolean not null default true,
  created_at timestamptz default now()
);

alter table public.profiles
  add column if not exists username text;

alter table public.profiles
  add column if not exists avatar_url text;

alter table public.profiles
  add column if not exists bio text default '';

alter table public.profiles
  add column if not exists is_verified boolean default false;

alter table public.profiles
  add column if not exists is_admin boolean default false;

alter table public.profiles
  add column if not exists is_private boolean not null default false;

alter table public.profiles
  add column if not exists notifications_enabled boolean not null default true;

alter table public.profiles
  add column if not exists created_at timestamptz default now();


-- ============================================================
-- 2. PREMIUM USERNAMES
-- ============================================================

create table if not exists public.premium_usernames (
  username text primary key,
  price numeric default 0,
  status text default 'available',
  assigned_to uuid references auth.users(id),
  created_at timestamptz default now()
);

alter table public.premium_usernames
  add column if not exists price numeric default 0;

alter table public.premium_usernames
  add column if not exists status text default 'available';

alter table public.premium_usernames
  add column if not exists assigned_to uuid references auth.users(id);

alter table public.premium_usernames
  add column if not exists created_at timestamptz default now();

alter table public.premium_usernames
  drop constraint if exists premium_usernames_status_check;

alter table public.premium_usernames
  add constraint premium_usernames_status_check
  check (status in ('available','reserved','sold','blocked'));


-- ============================================================
-- 3. POSTS
-- ============================================================

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  media_url text,
  media_type text default 'video',
  caption text default '',
  visibility text default 'public',
  adult_only boolean default false,
  likes_count integer not null default 0,
  created_at timestamptz default now()
);

alter table public.posts
  add column if not exists media_url text;

alter table public.posts
  add column if not exists media_type text default 'video';

alter table public.posts
  add column if not exists caption text default '';

alter table public.posts
  add column if not exists visibility text default 'public';

alter table public.posts
  add column if not exists adult_only boolean default false;

alter table public.posts
  add column if not exists likes_count integer not null default 0;

alter table public.posts
  add column if not exists created_at timestamptz default now();

alter table public.posts
  drop constraint if exists posts_visibility_check;

alter table public.posts
  add constraint posts_visibility_check
  check (visibility in ('public','followers','private'));


-- ============================================================
-- 4. POST LIKES
-- ============================================================

create table if not exists public.post_likes (
  post_id uuid references public.posts(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  primary key(post_id,user_id)
);

-- ============================================================
-- 5. SAVED POSTS
-- ============================================================

create table if not exists public.saved_posts (
  post_id uuid references public.posts(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  primary key(post_id,user_id)
);


-- ============================================================
-- 6. POST LIKE COUNTER
-- ============================================================

create or replace function public.sync_post_like_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin

  if tg_op = 'INSERT' then

    update public.posts
    set likes_count = likes_count + 1
    where id = new.post_id;

    return new;

  elsif tg_op = 'DELETE' then

    update public.posts
    set likes_count = greatest(likes_count - 1, 0)
    where id = old.post_id;

    return old;

  end if;

  return null;

end;
$$;

drop trigger if exists post_like_count_sync on public.post_likes;

create trigger post_like_count_sync
after insert or delete on public.post_likes
for each row
execute function public.sync_post_like_count();


-- ============================================================
-- 7. FOLLOWS
-- ============================================================

create table if not exists public.follows (
  follower_id uuid references auth.users(id) on delete cascade,
  following_id uuid references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  primary key(follower_id,following_id),
  check(follower_id <> following_id)
);


-- ============================================================
-- 8. COMMENTS
-- ============================================================

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid references public.posts(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  body text not null,
  created_at timestamptz default now()
);

alter table public.comments
  add column if not exists body text;


-- ============================================================
-- 9. CONVERSATIONS
-- ============================================================

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_a uuid references auth.users(id) on delete cascade,
  user_b uuid references auth.users(id) on delete cascade,
  title text default 'محادثة',
  last_message text default '',
  updated_at timestamptz default now(),
  unique(user_a,user_b)
);

alter table public.conversations
  add column if not exists title text default 'محادثة';

alter table public.conversations
  add column if not exists last_message text default '';

alter table public.conversations
  add column if not exists updated_at timestamptz default now();


-- ============================================================
-- 10. MESSAGES
-- IMPORTANT: ALL MEDIA COLUMNS ARE CREATED BEFORE FUNCTIONS
-- ============================================================

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid references public.conversations(id) on delete cascade,
  sender_id uuid references auth.users(id) on delete cascade,
  body text default '',
  media_url text,
  media_type text,
  media_name text,
  media_size bigint,
  created_at timestamptz default now()
);

alter table public.messages
  add column if not exists body text default '';

alter table public.messages
  add column if not exists media_url text;

alter table public.messages
  add column if not exists media_type text;

alter table public.messages
  add column if not exists media_name text;

alter table public.messages
  add column if not exists media_size bigint;

alter table public.messages
  add column if not exists created_at timestamptz default now();

alter table public.messages
  drop constraint if exists messages_media_type_check;

alter table public.messages
  add constraint messages_media_type_check
  check (
    media_type in ('image','video','file')
    or media_type is null
  );


-- ============================================================
-- 11. NOTIFICATIONS
-- ============================================================

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete cascade,
  type text not null,
  post_id uuid references public.posts(id) on delete cascade,
  read boolean default false,
  created_at timestamptz default now()
);

alter table public.notifications
  add column if not exists read boolean default false;

alter table public.notifications
  add column if not exists created_at timestamptz default now();


-- ============================================================
-- 12. STORIES
-- ============================================================

create table if not exists public.stories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  media_url text not null,
  expires_at timestamptz not null,
  created_at timestamptz default now()
);


-- ============================================================
-- 13. COINS
-- ============================================================

create table if not exists public.user_coins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  balance bigint not null default 0,
  level integer not null default 1
);


-- ============================================================
-- 14. ADMIN FUNCTION
-- ============================================================

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select p.is_admin
      from public.profiles p
      where p.id = auth.uid()
    ),
    false
  );
$$;

re
