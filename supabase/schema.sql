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
  birth_date date,
  created_at timestamptz default now()
);
alter table public.profiles add column if not exists is_private boolean not null default false;
alter table public.profiles add column if not exists notifications_enabled boolean not null default true;
alter table public.profiles add column if not exists birth_date date;

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
  check(media_type in ('image','video','voice','file') or media_type is null);

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
  media_type text not null default 'image' check(media_type in ('image','video')),
  expires_at timestamptz not null,
  created_at timestamptz default now()
);
alter table public.stories add column if not exists media_type text not null default 'image';

create table if not exists public.live_rooms (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references auth.users(id) on delete cascade,
  title text not null default 'بث مباشر N',
  stream_url text,
  status text not null default 'live' check(status in ('live','ended')),
  viewer_count integer not null default 0,
  created_at timestamptz default now(),
  ended_at timestamptz
);
alter table public.live_rooms enable row level security;
drop policy if exists "live rooms host insert" on public.live_rooms;
create policy "live rooms host insert" on public.live_rooms for insert to authenticated with check(host_id=auth.uid());
drop policy if exists "live rooms host update" on public.live_rooms;
create policy "live rooms host update" on public.live_rooms for update to authenticated using(host_id=auth.uid()) with check(host_id=auth.uid());

create index if not exists live_rooms_status_created_idx on public.live_rooms(status,created_at desc);

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
declare bd date;
        age_years integer;
begin
  bd := nullif(new.raw_user_meta_data->>'birth_date','')::date;
  if bd is null then raise exception 'BIRTH_DATE_REQUIRED'; end if;
  age_years := extract(year from age(current_date, bd));
  if age_years < 13 then raise exception 'MINIMUM_AGE_13'; end if;
  insert into public.profiles(id,username,birth_date) values(new.id,coalesce(new.raw_user_meta_data->>'username','user_'||substr(new.id::text,1,8)),bd);
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
create or replace function public.protect_profile_privileged_fields()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if not public.is_admin() then
    new.is_admin := old.is_admin;
    new.is_verified := old.is_verified;
  end if;
  return new;
end $$;
revoke all on function public.protect_profile_privileged_fields() from public;
grant execute on function public.protect_profile_privileged_fields() to authenticated;
drop trigger if exists protect_profile_privileged_fields on public.profiles;
create trigger protect_profile_privileged_fields
before update on public.profiles
for each row execute function public.protect_profile_privileged_fields();

drop policy if exists "profiles own update" on profiles;
create policy "profiles own update" on profiles for update to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);
drop policy if exists "profiles own insert" on profiles;
create policy "profiles own insert" on profiles for insert to authenticated
with check (auth.uid()=id and is_admin=false and is_verified=false);

create table if not exists public.blocked_users (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  primary key(blocker_id, blocked_id),
  check(blocker_id <> blocked_id)
);

create or replace function public.is_blocked_between(a uuid, b uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.blocked_users bu where (bu.blocker_id=a and bu.blocked_id=b) or (bu.blocker_id=b and bu.blocked_id=a));
$$;
revoke all on function public.is_blocked_between(uuid,uuid) from public;
grant execute on function public.is_blocked_between(uuid,uuid) to authenticated;

create or replace function public.can_read_post(p_post_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists (
    select 1
    from public.posts p
    join public.profiles owner on owner.id=p.user_id
    where p.id=p_post_id
      and auth.uid() is not null
      and not public.is_blocked_between(auth.uid(), p.user_id)
      and (not p.adult_only or (select birth_date from public.profiles where id=auth.uid()) <= (current_date - interval '21 years')::date)
      and (
        auth.uid()=p.user_id
        or (p.visibility='public' and (not owner.is_private or exists(select 1 from public.follows f where f.follower_id=auth.uid() and f.following_id=p.user_id)))
        or (p.visibility='followers' and exists(select 1 from public.follows f where f.follower_id=auth.uid() and f.following_id=p.user_id))
      )
  );
$$;
revoke all on function public.can_read_post(uuid) from public;
grant execute on function public.can_read_post(uuid) to authenticated;

drop policy if exists "posts public read" on posts;
drop policy if exists "posts visible read" on posts;
create policy "posts visible read" on posts for select to authenticated using (public.can_read_post(id));
drop policy if exists "posts own insert" on posts;
create policy "posts own insert" on posts for insert with check(auth.uid()=user_id and (not adult_only or (select birth_date from public.profiles where id=auth.uid()) <= (current_date - interval '21 years')::date));
drop policy if exists "posts own update" on posts;
create policy "posts own update" on posts for update to authenticated
using (auth.uid()=user_id)
with check (auth.uid()=user_id and (not adult_only or (select birth_date from public.profiles where id=auth.uid()) <= (current_date - interval '21 years')::date));
drop policy if exists "posts own delete" on posts;
create policy "posts own delete" on posts for delete using(auth.uid()=user_id);

drop policy if exists "likes read" on post_likes;
create policy "likes read" on post_likes for select to authenticated using(public.can_read_post(post_id));
drop policy if exists "likes own" on post_likes;
create policy "likes own" on post_likes for insert with check(auth.uid()=user_id and public.can_read_post(post_id));
drop policy if exists "likes delete" on post_likes;
create policy "likes delete" on post_likes for delete using(auth.uid()=user_id);

drop policy if exists "saved own" on saved_posts;
create policy "saved own" on saved_posts for all using(auth.uid()=user_id) with check(auth.uid()=user_id);
drop policy if exists "follows read" on follows;
create policy "follows read" on follows for select using(true);
drop policy if exists "follows own" on follows;
create policy "follows own" on follows for all using(auth.uid()=follower_id) with check(auth.uid()=follower_id and not public.is_blocked_between(auth.uid(), following_id));
drop policy if exists "comments read" on comments;
create policy "comments read" on comments for select to authenticated using(public.can_read_post(post_id));
drop policy if exists "comments own" on comments;
create policy "comments own" on comments for insert with check(auth.uid()=user_id and public.can_read_post(post_id) and not public.is_blocked_between(auth.uid(), (select user_id from public.posts where id=post_id)));
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
 if public.is_blocked_between(me,p_other_user) then raise exception 'USER_BLOCKED'; end if;
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
create policy "messages sender" on messages for insert with check(auth.uid()=sender_id and exists(select 1 from conversations c where c.id=conversation_id and (c.user_a=auth.uid() or c.user_b=auth.uid())) and not exists(select 1 from conversations c join public.blocked_users b on ((b.blocker_id=auth.uid() and b.blocked_id=case when c.user_a=auth.uid() then c.user_b else c.user_a end) or (b.blocker_id=case when c.user_a=auth.uid() then c.user_b else c.user_a end and b.blocked_id=auth.uid())) where c.id=conversation_id));
drop policy if exists "notifications own" on notifications;
create policy "notifications own" on notifications for select using(auth.uid()=user_id);
drop policy if exists "stories read" on stories;
create or replace function public.can_read_story(p_story_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists (select 1 from public.stories s join public.profiles owner on owner.id=s.user_id where s.id=p_story_id and s.expires_at>now() and not public.is_blocked_between(auth.uid(),s.user_id) and (auth.uid()=s.user_id or not owner.is_private or exists(select 1 from public.follows f where f.follower_id=auth.uid() and f.following_id=s.user_id)));
$$;
revoke all on function public.can_read_story(uuid) from public;
grant execute on function public.can_read_story(uuid) to authenticated;
drop policy if exists "stories read" on stories;
create policy "stories read" on stories for select to authenticated using(public.can_read_story(id));
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
create index if not exists posts_visibility_created_at_idx on public.posts(visibility, created_at desc);
create index if not exists follows_follower_following_idx on public.follows(follower_id, following_id);
create index if not exists blocked_users_blocked_idx on public.blocked_users(blocked_id);
create index if not exists profiles_birth_date_idx on public.profiles(birth_date);

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
select exists(select 1 from public.posts p where p.media_url=object_name and public.can_read_post(p.id));
$$;
revoke all on function public.can_read_post_media(text) from public;
grant execute on function public.can_read_post_media(text) to authenticated;
drop policy if exists "N post media public read" on storage.objects;
drop policy if exists "N post media access" on storage.objects;
create policy "N post media access" on storage.objects for select to authenticated using(bucket_id='post-media' and public.can_read_post_media(name));



-- N stories media: private 24-hour story storage.
insert into storage.buckets (id, name, public, file_size_limit)
values ('story-media', 'story-media', false, 104857600)
on conflict (id) do update set public = false, file_size_limit = 104857600;

drop policy if exists "N story media upload" on storage.objects;
create policy "N story media upload" on storage.objects for insert to authenticated
with check (bucket_id='story-media' and (storage.foldername(name))[1]=auth.uid()::text);

drop policy if exists "N story media delete" on storage.objects;
create policy "N story media delete" on storage.objects for delete to authenticated
using (bucket_id='story-media' and owner_id=auth.uid());

create or replace function public.can_read_story_media(object_name text) returns boolean
language sql stable security definer set search_path=public as $$
select exists (
  select 1 from public.stories s
  where s.media_url=object_name
    and s.expires_at>now()
    and public.can_read_story(s.id)
);
$$;
revoke all on function public.can_read_story_media(text) from public;
grant execute on function public.can_read_story_media(text) to authenticated;

drop policy if exists "N story media access" on storage.objects;
create policy "N story media access" on storage.objects for select to authenticated
using (bucket_id='story-media' and public.can_read_story_media(name));

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

-- N interaction tables used by the fully connected settings/activity screens.
create table if not exists public.profile_views (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references auth.users(id) on delete cascade,
  viewer_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  unique(profile_id, viewer_id)
);

create table if not exists public.blocked_users (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  primary key(blocker_id, blocked_id),
  check(blocker_id <> blocked_id)
);

create table if not exists public.gift_transactions (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  receiver_id uuid not null references auth.users(id) on delete cascade,
  gift_name text not null,
  gift_cost bigint not null check(gift_cost > 0),
  created_at timestamptz default now()
);

alter table public.profile_views enable row level security;
alter table public.blocked_users enable row level security;
alter table public.gift_transactions enable row level security;

drop policy if exists "profile views own" on public.profile_views;
create policy "profile views own" on public.profile_views for select using(auth.uid()=profile_id or auth.uid()=viewer_id);
drop policy if exists "profile views insert" on public.profile_views;
create policy "profile views insert" on public.profile_views for insert with check(auth.uid()=viewer_id);
drop policy if exists "blocked own" on public.blocked_users;
create policy "blocked own" on public.blocked_users for all using(auth.uid()=blocker_id) with check(auth.uid()=blocker_id);
drop policy if exists "gifts own read" on public.gift_transactions;
create policy "gifts own read" on public.gift_transactions for select using(auth.uid()=sender_id or auth.uid()=receiver_id);
drop policy if exists "notifications own update" on public.notifications;
create policy "notifications own update" on public.notifications for update using(auth.uid()=user_id) with check(auth.uid()=user_id);

create or replace function public.send_gift(p_receiver uuid, p_name text, p_cost bigint)
returns void language plpgsql security definer set search_path=public as $$
declare me uuid := auth.uid(); current_balance bigint; expected_cost bigint;
begin
  if me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if p_receiver is null or p_receiver = me then raise exception 'INVALID_RECIPIENT'; end if;
  if public.is_blocked_between(me,p_receiver) then raise exception 'USER_BLOCKED'; end if;
  expected_cost := case p_name
    when 'وردة' then 10 when 'قلب' then 50 when 'أسد' then 500 when 'سيارة' then 1000
    when 'يخت' then 5000 when 'قصر' then 10000 when 'طائر النور' then 20000 when 'نجمة' then 50000 when 'ختمة' then 100000
    else null end;
  if expected_cost is null or p_cost <> expected_cost then raise exception 'INVALID_GIFT'; end if;
  select balance into current_balance from public.user_coins where user_id=me for update;
  if coalesce(current_balance,0) < p_cost then raise exception 'INSUFFICIENT_COINS'; end if;
  update public.user_coins set balance=balance-p_cost where user_id=me;
  insert into public.user_coins(user_id,balance) values(p_receiver,p_cost) on conflict(user_id) do update set balance=public.user_coins.balance+p_cost;
  insert into public.gift_transactions(sender_id,receiver_id,gift_name,gift_cost) values(me,p_receiver,p_name,p_cost);
  if coalesce((select notifications_enabled from public.profiles where id=p_receiver),true) then
    insert into public.notifications(user_id,actor_id,type) values(p_receiver,me,'gift');
  end if;
end $$;
revoke all on function public.send_gift(uuid,text,bigint) from public;
grant execute on function public.send_gift(uuid,text,bigint) to authenticated;

-- Automatic in-app notifications for the main social interactions.
create or replace function public.notify_post_like()
returns trigger language plpgsql security definer set search_path=public as $$
declare owner_id uuid;
begin
  select user_id into owner_id from public.posts where id=new.post_id;
  if owner_id is not null and owner_id <> new.user_id and coalesce((select notifications_enabled from public.profiles where id=owner_id),true) then
    insert into public.notifications(user_id,actor_id,type,post_id) values(owner_id,new.user_id,'like',new.post_id);
  end if;
  return new;
end $$;
drop trigger if exists post_like_notification on public.post_likes;
create trigger post_like_notification after insert on public.post_likes for each row execute function public.notify_post_like();

create or replace function public.notify_follow()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.following_id <> new.follower_id and coalesce((select notifications_enabled from public.profiles where id=new.following_id),true) then
    insert into public.notifications(user_id,actor_id,type) values(new.following_id,new.follower_id,'follow');
  end if;
  return new;
end $$;
drop trigger if exists follow_notification on public.follows;
create trigger follow_notification after insert on public.follows for each row execute function public.notify_follow();

create or replace function public.notify_comment()
returns trigger language plpgsql security definer set search_path=public as $$
declare owner_id uuid;
begin
  select user_id into owner_id from public.posts where id=new.post_id;
  if owner_id is not null and owner_id <> new.user_id and coalesce((select notifications_enabled from public.profiles where id=owner_id),true) then
    insert into public.notifications(user_id,actor_id,type,post_id) values(owner_id,new.user_id,'comment',new.post_id);
  end if;
  return new;
end $$;
drop trigger if exists comment_notification on public.comments;
create trigger comment_notification after insert on public.comments for each row execute function public.notify_comment();

create or replace function public.notify_message()
returns trigger language plpgsql security definer set search_path=public as $$
declare recipient uuid;
begin
  select case when c.user_a=new.sender_id then c.user_b else c.user_a end into recipient
  from public.conversations c where c.id=new.conversation_id;
  if recipient is not null and recipient<>new.sender_id and coalesce((select notifications_enabled from public.profiles where id=recipient),true) then
    insert into public.notifications(user_id,actor_id,type) values(recipient,new.sender_id,'message');
  end if;
  return new;
end $$;
drop trigger if exists message_notification on public.messages;
create trigger message_notification after insert on public.messages for each row execute function public.notify_message();

-- Push notification device tokens used by the FCM Edge Function.
create table if not exists public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null,
  platform text not null default 'android',
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique(user_id, token)
);

alter table public.push_tokens enable row level security;
drop policy if exists "push tokens own" on public.push_tokens;
create policy "push tokens own" on public.push_tokens
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create index if not exists push_tokens_user_idx on public.push_tokens(user_id);


-- N live chat, viewer accounting, message read receipts and coin purchases.
alter table public.messages add column if not exists read_at timestamptz;
create index if not exists messages_unread_idx on public.messages(conversation_id,sender_id,read_at,created_at desc);
drop policy if exists "messages member update read" on public.messages;

create or replace function public.mark_conversation_read(p_conversation uuid)
returns integer language plpgsql security definer set search_path=public as $$
declare changed integer;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  update public.messages m
  set read_at=coalesce(m.read_at, now())
  where m.conversation_id=p_conversation
    and m.sender_id<>auth.uid()
    and m.read_at is null
    and exists (select 1 from public.conversations c where c.id=p_conversation and (c.user_a=auth.uid() or c.user_b=auth.uid()));
  get diagnostics changed = row_count;
  return changed;
end $$;
revoke all on function public.mark_conversation_read(uuid) from public;
grant execute on function public.mark_conversation_read(uuid) to authenticated;

create table if not exists public.live_comments (
  id uuid primary key default gen_random_uuid(), room_id uuid not null references public.live_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null check(length(trim(body)) between 1 and 500), created_at timestamptz not null default now()
);
alter table public.live_comments enable row level security;
drop policy if exists "live comments read" on public.live_comments;
create policy "live comments read" on public.live_comments for select to authenticated
using (exists(select 1 from public.live_rooms r where r.id=room_id and (r.status='live' or r.host_id=auth.uid()) and not public.is_blocked_between(auth.uid(),r.host_id)));
drop policy if exists "live comments insert" on public.live_comments;
create policy "live comments insert" on public.live_comments for insert to authenticated
with check (auth.uid()=user_id and exists(select 1 from public.live_rooms r where r.id=room_id and r.status='live' and not public.is_blocked_between(auth.uid(),r.host_id)));
drop policy if exists "live comments delete own" on public.live_comments;
create policy "live comments delete own" on public.live_comments for delete to authenticated using(auth.uid()=user_id);
create index if not exists live_comments_room_created_idx on public.live_comments(room_id,created_at desc);

create table if not exists public.live_viewers (
  room_id uuid not null references public.live_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key(room_id,user_id)
);
alter table public.live_viewers enable row level security;
drop policy if exists "live viewers own" on public.live_viewers;
create policy "live viewers own" on public.live_viewers for select to authenticated
using (user_id=auth.uid());

create or replace function public.enter_live_room(p_room uuid)
returns integer language plpgsql security definer set search_path=public as $$
declare n integer; host uuid;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  select host_id into host from public.live_rooms where id=p_room and status='live' for update;
  if host is null then raise exception 'LIVE_NOT_FOUND'; end if;
  if public.is_blocked_between(auth.uid(),host) then raise exception 'USER_BLOCKED'; end if;
  insert into public.live_viewers(room_id,user_id) values(p_room,auth.uid()) on conflict do nothing;
  update public.live_rooms r set viewer_count=(select count(*) from public.live_viewers v where v.room_id=r.id) where r.id=p_room returning viewer_count into n;
  return coalesce(n,0);
end $$;
revoke all on function public.enter_live_room(uuid) from public;
grant execute on function public.enter_live_room(uuid) to authenticated;

create or replace function public.leave_live_room(p_room uuid)
returns integer language plpgsql security definer set search_path=public as $$
declare n integer;
begin
  delete from public.live_viewers where room_id=p_room and user_id=auth.uid();
  update public.live_rooms r set viewer_count=(select count(*) from public.live_viewers v where v.room_id=r.id) where r.id=p_room returning viewer_count into n;
  return coalesce(n,0);
end $$;
revoke all on function public.leave_live_room(uuid) from public;
grant execute on function public.leave_live_room(uuid) to authenticated;

do $$ begin
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='live_rooms') then alter publication supabase_realtime add table public.live_rooms; end if;
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='live_comments') then alter publication supabase_realtime add table public.live_comments; end if;
end $$;

create table if not exists public.coin_purchases (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  product_id text not null, purchase_token text not null unique, order_id text, coins bigint not null check(coins>0), created_at timestamptz not null default now()
);
alter table public.coin_purchases enable row level security;
drop policy if exists "coin purchases own" on public.coin_purchases;
create policy "coin purchases own" on public.coin_purchases for select to authenticated using(auth.uid()=user_id);

create or replace function public.credit_coins_from_purchase(p_user uuid,p_product text,p_token text,p_order text,p_coins bigint)
returns jsonb language plpgsql security definer set search_path=public as $$
declare new_balance bigint; expected_coins bigint;
begin
  expected_coins := case p_product
    when 'n_coins_100' then 100
    when 'n_coins_550' then 550
    when 'n_coins_1200' then 1200
    when 'n_coins_2600' then 2600
    when 'n_coins_7000' then 7000
    else null end;
  if p_user is null or p_token is null or p_token='' or expected_coins is null or p_coins<>expected_coins then raise exception 'INVALID_PURCHASE'; end if;
  if exists(select 1 from public.coin_purchases where purchase_token=p_token) then
    select balance into new_balance from public.user_coins where user_id=p_user;
    return jsonb_build_object('ok',true,'already_processed',true,'balance',coalesce(new_balance,0));
  end if;
  insert into public.coin_purchases(user_id,product_id,purchase_token,order_id,coins) values(p_user,p_product,p_token,p_order,p_coins);
  insert into public.user_coins(user_id,balance) values(p_user,p_coins) on conflict(user_id) do update set balance=public.user_coins.balance+p_coins;
  select balance into new_balance from public.user_coins where user_id=p_user;
  return jsonb_build_object('ok',true,'already_processed',false,'balance',new_balance,'coins',p_coins);
end $$;
revoke all on function public.credit_coins_from_purchase(uuid,text,text,text,bigint) from public;
grant execute on function public.credit_coins_from_purchase(uuid,text,text,text,bigint) to service_role;

-- One active live room per host and block-aware discovery.
create unique index if not exists live_rooms_one_active_host_idx on public.live_rooms(host_id) where status='live';
drop policy if exists "live rooms read" on public.live_rooms;
create policy "live rooms read" on public.live_rooms for select to authenticated
using ((status='live' and not public.is_blocked_between(auth.uid(),host_id)) or host_id=auth.uid());
