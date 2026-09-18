create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  avatar_url text,
  bio text default '',
  is_verified boolean default false,
  is_admin boolean default false,
  created_at timestamptz default now()
);

create table if not exists public.premium_usernames (
  username text primary key,
  price numeric default 0,
  status text default 'available' check(status in ('available','reserved','sold','blocked')),
  assigned_to uuid references auth.users(id),
  created_at timestamptz default now()
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  media_url text not null,
  media_type text not null default 'video',
  caption text default '',
  visibility text not null default 'public' check(visibility in ('public','followers','private')),
  adult_only boolean default false,
  likes_count integer not null default 0,
  created_at timestamptz default now()
);

create table if not exists public.post_likes (
  post_id uuid references public.posts(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  primary key(post_id,user_id)
);

create table if not exists public.saved_posts (
  post_id uuid references public.posts(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  primary key(post_id,user_id)
);

create table if not exists public.follows (
  follower_id uuid references auth.users(id) on delete cascade,
  following_id uuid references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  primary key(follower_id,following_id),
  check(follower_id <> following_id)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid references public.posts(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  body text not null,
  created_at timestamptz default now()
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_a uuid references auth.users(id) on delete cascade,
  user_b uuid references auth.users(id) on delete cascade,
  title text default 'محادثة',
  last_message text default '',
  updated_at timestamptz default now(),
  unique(user_a,user_b)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid references public.conversations(id) on delete cascade,
  sender_id uuid references auth.users(id) on delete cascade,
  body text default '',
  media_url text,
  created_at timestamptz default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete cascade,
  type text not null,
  post_id uuid references public.posts(id) on delete cascade,
  read boolean default false,
  created_at timestamptz default now()
);

create table if not exists public.stories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  media_url text not null,
  expires_at timestamptz not null,
  created_at timestamptz default now()
);

create table if not exists public.user_coins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  balance bigint not null default 0,
  level integer not null default 1
);

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path=public as $$
  select coalesce((select is_admin from profiles where id=auth.uid()),false);
$$;

create or replace function public.validate_username()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if length(new.username) < 4 and not public.is_admin() then
    if not exists(select 1 from premium_usernames p where lower(p.username)=lower(new.username) and p.status='reserved' and p.assigned_to=auth.uid()) then
      raise exception 'USERNAMES_3_OR_LESS_ARE_PREMIUM';
    end if;
  end if;
  if new.username !~ '^[A-Za-z0-9_]+$' then
    raise exception 'INVALID_USERNAME';
  end if;
  return new;
end $$;

drop trigger if exists validate_profile_username on public.profiles;
create trigger validate_profile_username before insert or update of username on public.profiles
for each row execute function public.validate_username();

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.profiles(id,username) values(new.id,coalesce(new.raw_user_meta_data->>'username','user_'||substr(new.id::text,1,8)));
  insert into public.user_coins(user_id) values(new.id) on conflict do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.saved_posts enable row level security;
alter table public.follows enable row level security;
alter table public.comments enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.notifications enable row level security;
alter table public.stories enable row level security;
alter table public.user_coins enable row level security;
alter table public.premium_usernames enable row level security;

create policy "profiles read" on profiles for select using(true);
create policy "profiles own update" on profiles for update using(auth.uid()=id);
create policy "profiles own insert" on profiles for insert with check(auth.uid()=id);

create policy "posts public read" on posts for select using(visibility='public' or auth.uid()=user_id);
create policy "posts own insert" on posts for insert with check(auth.uid()=user_id);
create policy "posts own update" on posts for update using(auth.uid()=user_id);
create policy "posts own delete" on posts for delete using(auth.uid()=user_id);

create policy "likes read" on post_likes for select using(true);
create policy "likes own" on post_likes for insert with check(auth.uid()=user_id);
create policy "likes delete" on post_likes for delete using(auth.uid()=user_id);

create policy "saved own" on saved_posts for all using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy "follows read" on follows for select using(true);
create policy "follows own" on follows for all using(auth.uid()=follower_id) with check(auth.uid()=follower_id);
create policy "comments read" on comments for select using(true);
create policy "comments own" on comments for insert with check(auth.uid()=user_id);
create policy "comments delete" on comments for delete using(auth.uid()=user_id);

create policy "conversations member" on conversations for all using(auth.uid()=user_a or auth.uid()=user_b) with check(auth.uid()=user_a or auth.uid()=user_b);
create policy "messages member" on messages for select using(exists(select 1 from conversations c where c.id=conversation_id and (c.user_a=auth.uid() or c.user_b=auth.uid())));
create policy "messages sender" on messages for insert with check(auth.uid()=sender_id and exists(select 1 from conversations c where c.id=conversation_id and (c.user_a=auth.uid() or c.user_b=auth.uid())));
create policy "notifications own" on notifications for select using(auth.uid()=user_id);
create policy "stories read" on stories for select using(expires_at>now());
create policy "stories own" on stories for all using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy "coins own" on user_coins for select using(auth.uid()=user_id);
create policy "premium read" on premium_usernames for select using(status='available' or assigned_to=auth.uid() or public.is_admin());
