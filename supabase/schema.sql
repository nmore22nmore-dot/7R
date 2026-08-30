-- =========================================================
-- N — FINAL SUPABASE DATABASE SCHEMA
-- Compatible with current N Flutter code
-- =========================================================

create extension if not exists "pgcrypto";

-- =========================================================
-- PROFILES
-- =========================================================

create table if not exists public.profiles (
  id uuid primary key
    references auth.users(id)
    on delete cascade,

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

  constraint post_likes_pkey
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

  constraint saved_posts_pkey
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

  constraint follows_pkey
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

  constraint conversation_members_pkey
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

create index if not exists posts_user_id_idx
on public.posts(user_id);

create index if not exists post_likes_post_id_idx
on public.post_likes(post_id);

create index if not exists post_likes_user_id_idx
on public.post_likes(user_id);

create index if not exists comments_post_id_idx
on public.comments(post_id);

create index if not exists comments_user_id_idx
on public.comments(user_id);

create index if not exists comments_created_at_idx
on public.comments(created_at desc);

create index if not exists saved_posts_user_id_idx
on public.saved_posts(user_id);

create index if not exists follows_follower_id_idx
on public.follows(follower_id);

create index if not exists follows_following_id_idx
on public.follows(following_id);

create index if not exists conversation_members_user_id_idx
on public.conversation_members(user_id);

create index if not exists messages_conversation_id_idx
on public.messages(conversation_id);

create index if not exists messages_sender_id_idx
on public.messages(sender_id);

create index if not exists messages_created_at_idx
on public.messages(created_at);

-- =========================================================
-- UPDATED_AT FUNCTION
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

-- =========================================================
-- UPDATED_AT TRIGGERS
-- =========================================================

drop trigger if exists profiles_set_updated_at
on public.profiles;

create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

drop trigger if exists posts_set_updated_at
on public.posts;

create trigger posts_set_updated_at
before update on public.posts
for each row
execute function public.set_updated_at();

-- =========================================================
-- CREATE PROFILE AFTER AUTH SIGNUP
-- =========================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  generated_username text;
begin

  generated_username :=
    coalesce(
      nullif(new.raw_user_meta_data->>'username', ''),
      'user_' || substr(replace(new.id::text, '-', ''), 1, 12)
    );

  /*
   * حماية إضافية من التعارض في اسم المستخدم.
   */
  if exists (
    select 1
    from public.profiles
    where username = generated_username
  ) then
    generated_username :=
      'user_' ||
      substr(replace(new.id::text, '-', ''), 1, 16);
  end if;

  /*
   * اسم المستخدم الناتج يجب أن يكون 4 أحرف على الأقل.
   */
  if char_length(generated_username) < 4 then
    generated_username :=
      'user_' ||
      substr(replace(new.id::text, '-', ''), 1, 12);
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

    coalesce(
      nullif(new.raw_user_meta_data->>'name', ''),
      'مستخدم N'
    ),

    generated_username,

    new.email,

    case
      when (new.raw_user_meta_data->>'age') ~ '^[0-9]+$'
      then greatest(
        13,
        least(
          120,
          (new.raw_user_meta_data->>'age')::integer
        )
      )
      else 25
    end
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
-- ROW LEVEL SECURITY
-- =========================================================

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.comments enable row level security;
alter table public.saved_posts enable row level security;
alter table public.follows enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

-- =========================================================
-- PROFILES POLICIES
-- =========================================================

drop policy if exists profiles_select_authenticated
on public.profiles;

create policy profiles_select_authenticated
on public.profiles
for select
to authenticated
using (true);

drop policy if exists profiles_insert_own
on public.profiles;

create policy profiles_insert_own
on public.profiles
for insert
to authenticated
with check (id = auth.uid());

drop policy if exists profiles_update_own
on public.profiles;

create policy profiles_update_own
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- =========================================================
-- POSTS POLICIES
-- =========================================================

drop policy if exists posts_select_authenticated
on public.posts;

create policy posts_select_authenticated
on public.posts
for select
to authenticated
using (
  visibility = 'عام'
  or user_id = auth.uid()
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
with check (
  user_id = auth.uid()
);

drop policy if exists posts_update_own
on public.posts;

create policy posts_update_own
on public.posts
for update
to authenticated
using (
  user_id = auth.uid()
)
with check (
  user_id = auth.uid()
);

drop policy if exists posts_delete_own
on public.posts;

create policy posts_delete_own
on public.posts
for delete
to authenticated
using (
  user_id = auth.uid()
);

-- =========================================================
-- POST LIKES POLICIES
-- =========================================================

drop policy if exists post_likes_select_authenticated
on public.post_likes;

create policy post_likes_select_authenticated
on public.post_likes
for select
to authenticated
using (true);

drop policy if exists post_likes_insert_own
on public.post_likes;

create policy post_likes_insert_own
on public.post_likes
for insert
to authenticated
with check (
  user_id = auth.uid()
);

drop policy if exists post_likes_delete_own
on public.post_likes;

create policy post_likes_delete_own
on public.post_likes
for delete
to authenticated
using (
  user_id = auth.uid()
);

-- =========================================================
-- COMMENTS POLICIES
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
with check (
  user_id = auth.uid()
);

drop policy if exists comments_update_own
on public.comments;

create policy comments_update_own
on public.comments
for update
to authenticated
using (
  user_id = auth.uid()
)
with check (
  user_id = auth.uid()
);

drop policy if exists comments_delete_own
on public.comments;

create policy comments_delete_own
on public.comments
for delete
to authenticated
using (
  user_id = auth.uid()
);

-- =========================================================
-- SAVED POSTS POLICIES
-- =========================================================

drop policy if exists saved_posts_select_own
on public.saved_posts;

create policy saved_posts_select_own
on public.saved_posts
for select
to authenticated
using (
  user_id = auth.uid()
);

drop policy if exists saved_posts_insert_own
on public.saved_posts;

create policy saved_posts_insert_own
on public.saved_posts
for insert
to authenticated
with check (
  user_id = auth.uid()
);

drop policy if exists saved_posts_delete_own
on public.saved_posts;

create policy saved_posts_delete_own
on public.saved_posts
for delete
to authenticated
using (
  user_id = auth.uid()
);

-- =========================================================
-- FOLLOWS POLICIES
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
using (
  follower_id = auth.uid()
);

-- =========================================================
-- CONVERSATIONS POLICIES
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
-- CONVERSATION MEMBERS POLICIES
-- =========================================================

drop policy if exists conversation_members_select_member
on public.conversation_members;

create policy conversation_members_select_member
on public.conversation_members
for select
to authenticated
using (
  exists (
    select 1
    from public.conversation_members mine
    where mine.conversation_id =
      conversation_members.conversation_id
      and mine.user_id = auth.uid()
  )
);

drop policy if exists conversation_members_insert_authenticated
on public.conversation_members;

create policy conversation_members_insert_authenticated
on public.conversation_members
for insert
to authenticated
with check (
  exists (
    select 1
    from public.conversations c
    where c.id = conversation_members.conversation_id
  )
);

-- =========================================================
-- MESSAGES POLICIES
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
-- REALTIME
-- =========================================================

do $$
begin

  begin
    alter publication supabase_realtime
      add table public.messages;
  exception
    when duplicate_object then
      null;
    when undefined_object then
      null;
  end;

  begin
    alter publication supabase_realtime
      add table public.posts;
  exception
    when duplicate_object then
      null;
    when undefined_object then
      null;
  end;

  begin
    alter publication supabase_realtime
      add table public.comments;
  exception
    when duplicate_object then
      null;
    when undefined_object then
      null;
  end;

  begin
    alter publication supabase_realtime
      add table public.post_likes;
  exception
    when duplicate_object then
      null;
    when undefined_object then
      null;
  end;

end;
$$;

-- =========================================================
-- END OF N SCHEMA
-- =========================================================
