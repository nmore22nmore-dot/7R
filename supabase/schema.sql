-- =========================================================
-- N — FINAL SUPABASE DATABASE SCHEMA
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
  coins integer not null default 0,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint profiles_age_check
    check (age >= 13 and age <= 120),

  constraint profiles_username_length_check
    check (char_length(username) >= 4),

  constraint profiles_username_no_at_check
    check (position('@' in username) = 0),

  constraint profiles_username_no_space_check
    check (position(' ' in username) = 0)
);

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

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint posts_visibility_check
    check (
      visibility in ('عام', 'المتابعون', 'خاص')
    )
);

-- =========================================================
-- POST LIKES
-- =========================================================

create table if not exists public.post_likes (
  post_id uuid not null
    references public.posts(id)
    on delete cascade,

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  created_at timestamptz not null default now(),

  primary key (post_id, user_id)
);

-- =========================================================
-- COMMENTS
-- =========================================================

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),

  post_id uuid not null
    references public.posts(id)
    on delete cascade,

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  text text not null default '',

  created_at timestamptz not null default now()
);

-- =========================================================
-- SAVED POSTS
-- =========================================================

create table if not exists public.saved_posts (
  post_id uuid not null
    references public.posts(id)
    on delete cascade,

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  created_at timestamptz not null default now(),

  primary key (post_id, user_id)
);

-- =========================================================
-- FOLLOWS
-- =========================================================

create table if not exists public.follows (
  follower_id uuid not null
    references public.profiles(id)
    on delete cascade,

  following_id uuid not null
    references public.profiles(id)
    on delete cascade,

  created_at timestamptz not null default now(),

  primary key (follower_id, following_id),

  constraint follows_no_self_check
    check (follower_id <> following_id)
);

-- =========================================================
-- CONVERSATIONS
-- =========================================================

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now()
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

  created_at timestamptz not null default now()
);

-- =========================================================
-- INDEXES
-- =========================================================

create index if not exists posts_created_at_idx
on public.posts(created_at desc);

create index if not exists posts_user_id
