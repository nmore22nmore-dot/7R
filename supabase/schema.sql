create extension if not exists pgcrypto;

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
alter table public.profiles add column if not exists is_private boolean not null default false;
alter table public.profiles add column if not exists notifications_enabled boolean not null default true;

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

create or replace function public.sync_post_like_count()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='INSERT' then
    update public.posts set likes_count=likes_count+1 where id=new.post_id;
    return new;
  elsif tg_op='DELETE' then
    update public.posts set likes_count=greatest(likes_count-1,0) where id=old.post_id;
    return old;
  end if;
  return null;
end $$;
drop trigger if exists post_like_count_sync on public.post_likes;
create trigger post_like_count_sync after insert or delete on public.post_likes
for each row execute function public.sync_post_like_count();

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
  media_type text check(media_type in ('image','video','file') or media_type is null),
  media_name text,
  media_size bigint,
  created_at timestamptz default now()
);

-- Upgrade the message attachment schema for existing databases.
alter table public.messages drop constraint if exists messages_media_type_check;
alter table public.messages add constraint messages_media_type_check
  check(media_type in ('image','video','file') or media_type is null);

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

-- Normalize legacy public Storage URLs after all referenced tables exist.
update public.posts
set media_url = regexp_replace(media_url, '^.*/storage/v1/object/public/post-media/', '')
where media_url like '%/storage/v1/object/public/post-media/%';
update public.messages
set media_url = regexp_replace(media_url, '^.*/storage/v1/object/public/message-media/', '')
where media_url like '%/storage/v1/object/public/message-media/%';

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

drop policy if exists "profiles read" on profiles;
create policy "profiles read" on profiles for select using(true);
drop policy if exists "profiles own update" on profiles;
create policy "profiles own update" on profiles for update to authenticated
using (auth.uid() = id)
with check (auth.uid() = id and is_admin = (select p.is_admin from public.profiles p where p.id=auth.uid()) and is_verified = (select p.is_verified from public.profiles p where p.id=auth.uid()));
drop policy if exists "profiles own insert" on profiles;
create policy "profiles own insert" on profiles for insert to authenticated
with check (auth.uid()=id and is_admin=false and is_verified=false);

drop policy if exists "posts public read" on posts;
drop policy if exists "posts visible read" on posts;
create policy "posts visible read" on posts for select to authenticated using (
 auth.uid()=user_id or visibility='public' or (visibility='followers' and exists(select 1 from public.follows f where f.follower_id=auth.uid() and f.following_id=posts.user_id))
);
drop policy if exists "posts own insert" on posts;
create policy "posts own insert" on posts for insert with check(auth.uid()=user_id);
drop policy if exists "posts own update" on posts;
create policy "posts own update" on posts for update using(auth.uid()=user_id);
drop policy if exists "posts own delete" on posts;
create policy "posts own delete" on posts for delete using(auth.uid()=user_id);

drop policy if exists "likes read" on post_likes;
create policy "likes read" on post_likes for select using(true);
drop policy if exists "likes own" on post_likes;
create policy "likes own" on post_likes for insert with check(auth.uid()=user_id);
drop policy if exists "likes delete" on post_likes;
create policy "likes delete" on post_likes for delete using(auth.uid()=user_id);

drop policy if exists "saved own" on saved_posts;
create policy "saved own" on saved_posts for all using(auth.uid()=user_id) with check(auth.uid()=user_id);
drop policy if exists "follows read" on follows;
create policy "follows read" on follows for select using(true);
drop policy if exists "follows own" on follows;
create policy "follows own" on follows for all using(auth.uid()=follower_id) with check(auth.uid()=follower_id);
drop policy if exists "comments read" on comments;
create policy "comments read" on comments for select using(true);
drop policy if exists "comments own" on comments;
create policy "comments own" on comments for insert with check(auth.uid()=user_id);
drop policy if exists "comments delete" on comments;
create policy "comments delete" on comments for delete using(auth.uid()=user_id);

drop policy if exists "conversations member" on conversations;
drop policy if exists "conversations member read" on conversations;
create policy "conversations member read" on conversations for select to authenticated using(auth.uid()=user_a or auth.uid()=user_b);
create or replace function public.create_conversation(p_other_user uuid) returns uuid language plpgsql security definer set search_path=public as $$
declare me uuid:=auth.uid(); a uuid; b uuid; cid uuid;
begin
 if me is null then raise exception 'NOT_AUTHENTICATED'; end if;
 if p_other_user is null or p_other_user=me then raise exception 'INVALID_PARTICIPANT'; end if;
 if not exists(select 1 from auth.users where id=p_other_user) then raise exception 'USER_NOT_FOUND'; end if;
 a:=least(me,p_other_user); b:=greatest(me,p_other_user);
 insert into public.conversations(user_a,user_b) values(a,b) on conflict(user_a,user_b) do update set updated_at=public.conversations.updated_at returning id into cid;
 return cid;
end $$;
revoke all on function public.create_conversation(uuid) from public;
grant execute on function public.create_conversation(uuid) to authenticated;

create or replace function public.touch_conversation_from_message()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  update public.conversations
  set last_message = case when coalesce(new.body,'')='' then '📎 ملف مرفق' else new.body end,
      updated_at = coalesce(new.created_at, now())
  where id = new.conversation_id;
  return new;
end $$;
drop trigger if exists message_conversation_touch on public.messages;
create trigger message_conversation_touch after insert on public.messages
for each row execute function public.touch_conversation_from_message();

drop policy if exists "messages member" on messages;
create policy "messages member" on messages for select using(exists(select 1 from conversations c where c.id=conversation_id and (c.user_a=auth.uid() or c.user_b=auth.uid())));
drop policy if exists "messages sender" on messages;
create policy "messages sender" on messages for insert with check(auth.uid()=sender_id and exists(select 1 from conversations c where c.id=conversation_id and (c.user_a=auth.uid() or c.user_b=auth.uid())));
drop policy if exists "notifications own" on notifications;
create policy "notifications own" on notifications for select using(auth.uid()=user_id);
drop policy if exists "stories read" on stories;
create policy "stories read" on stories for select using(expires_at>now());
drop policy if exists "stories own" on stories;
create policy "stories own" on stories for all using(auth.uid()=user_id) with check(auth.uid()=user_id);
drop policy if exists "coins own" on user_coins;
create policy "coins own" on user_coins for select using(auth.uid()=user_id);
drop policy if exists "premium read" on premium_usernames;
create policy "premium read" on premium_usernames for select using(status='available' or assigned_to=auth.uid() or public.is_admin());



create index if not exists posts_created_at_idx on public.posts(created_at desc);
create index if not exists posts_user_created_at_idx on public.posts(user_id, created_at desc);
create index if not exists follows_following_idx on public.follows(following_id);
create index if not exists comments_post_created_at_idx on public.comments(post_id, created_at desc);
create index if not exists messages_conversation_created_at_idx on public.messages(conversation_id, created_at);
create index if not exists notifications_user_created_at_idx on public.notifications(user_id, created_at desc);

-- N Storage: bucket + policies required for video/image publishing.
insert into storage.buckets (id, name, public, file_size_limit)
values ('post-media', 'post-media', false, 209715200)
on conflict (id) do update set public = false, file_size_limit = 209715200;

drop policy if exists "N post media upload" on storage.objects;
create policy "N post media upload"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'post-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "N post media update" on storage.objects;
create policy "N post media update"
on storage.objects for update
to authenticated
using (
  bucket_id = 'post-media'
  and owner_id = auth.uid()
)
with check (
  bucket_id = 'post-media'
  and owner_id = auth.uid()
);

drop policy if exists "N post media delete" on storage.objects;
create policy "N post media delete"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'post-media'
  and owner_id = auth.uid()
);

create or replace function public.can_read_post_media(object_name text) returns boolean language sql stable security definer set search_path=public as $$
select exists(select 1 from public.posts p where p.media_url=object_name and (p.user_id=auth.uid() or p.visibility='public' or (p.visibility='followers' and exists(select 1 from public.follows f where f.follower_id=auth.uid() and f.following_id=p.user_id))));
$$;
revoke all on function public.can_read_post_media(text) from public;
grant execute on function public.can_read_post_media(text) to authenticated;
drop policy if exists "N post media public read" on storage.objects;
drop policy if exists "N post media access" on storage.objects;
create policy "N post media access" on storage.objects for select to authenticated using(bucket_id='post-media' and public.can_read_post_media(name));


-- N message media: attachments sent inside conversations.
alter table public.messages add column if not exists media_type text;
alter table public.messages add column if not exists media_name text;
alter table public.messages add column if not exists media_size bigint;

insert into storage.buckets (id, name, public, file_size_limit)
values ('message-media', 'message-media', false, 52428800)
on conflict (id) do update set public = false, file_size_limit = 52428800;

drop policy if exists "N message media upload" on storage.objects;
create policy "N message media upload"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'message-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "N message media public read" on storage.objects;
drop policy if exists "N message media access" on storage.objects;
create or replace function public.can_read_message_media(object_name text) returns boolean language sql stable security definer set search_path=public as $$
select exists (
  select 1 from public.conversations c
  where split_part(object_name, '/', 2) = c.id::text
    and (c.user_a=auth.uid() or c.user_b=auth.uid())
);
$$;
revoke all on function public.can_read_message_media(text) from public;
grant execute on function public.can_read_message_media(text) to authenticated;
create policy "N message media access"
on storage.objects for select
to authenticated
using (bucket_id = 'message-media' and public.can_read_message_media(name));

drop policy if exists "N message media update" on storage.objects;
create policy "N message media update"
on storage.objects for update
to authenticated
using (bucket_id = 'message-media' and owner_id = auth.uid())
with check (bucket_id = 'message-media' and owner_id = auth.uid());

drop policy if exists "N message media delete" on storage.objects;
create policy "N message media delete"
on storage.objects for delete
to authenticated
using (bucket_id = 'message-media' and owner_id = auth.uid());


-- Realtime for live message updates. Safe to run repeatedly.
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='messages') then
    alter publication supabase_realtime add table public.messages;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='notifications') then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;
