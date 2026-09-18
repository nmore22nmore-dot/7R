create extension if not exists pgcrypto;

create table if not exists public.profiles(
 id uuid primary key references auth.users(id) on delete cascade,
 username text unique not null,
 display_name text default '',
 avatar_url text,bio text default '',
 is_admin boolean default false,is_verified boolean default false,
 created_at timestamptz default now()
);
create table if not exists public.premium_usernames(
 username text primary key,
 price numeric(12,2) default 0,
 status text not null default 'available' check(status in('available','reserved','sold','blocked')),
 assigned_to uuid references public.profiles(id) on delete set null,
 created_at timestamptz default now()
);
create table if not exists public.posts(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 video_url text,caption text default '',
 visibility text not null default 'public' check(visibility in('public','followers','private')),
 likes_count int default 0,comments_count int default 0,views_count int default 0,
 created_at timestamptz default now()
);
create table if not exists public.post_likes(post_id uuid references public.posts(id) on delete cascade,user_id uuid references public.profiles(id) on delete cascade,primary key(post_id,user_id));
create table if not exists public.saved_posts(post_id uuid references public.posts(id) on delete cascade,user_id uuid references public.profiles(id) on delete cascade,primary key(post_id,user_id));
create table if not exists public.follows(follower_id uuid references public.profiles(id) on delete cascade,following_id uuid references public.profiles(id) on delete cascade,created_at timestamptz default now(),primary key(follower_id,following_id),check(follower_id<>following_id));
create table if not exists public.comments(id uuid primary key default gen_random_uuid(),post_id uuid references public.posts(id) on delete cascade,user_id uuid references public.profiles(id) on delete cascade,body text not null,created_at timestamptz default now());
create table if not exists public.conversations(id uuid primary key default gen_random_uuid(),title text default 'محادثة',last_message text default '',updated_at timestamptz default now());
create table if not exists public.notifications(id uuid primary key default gen_random_uuid(),user_id uuid references public.profiles(id) on delete cascade,actor_id uuid references public.profiles(id) on delete set null,type text not null,body text default '',read_at timestamptz,created_at timestamptz default now());

create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.profiles where id=auth.uid() and is_admin=true); $$;

create or replace function public.validate_username() returns trigger language plpgsql security definer set search_path=public
as $$
begin
 new.username:=lower(trim(new.username));
 if length(new.username)<4 and not public.is_admin() then raise exception 'USERNAMES_3_OR_LESS_ARE_PREMIUM'; end if;
 if new.username !~ '^[a-zA-Z0-9_]+$' then raise exception 'INVALID_USERNAME'; end if;
 return new;
end $$;

drop trigger if exists trg_validate_username on public.profiles;
create trigger trg_validate_username before insert or update of username on public.profiles
for each row execute function public.validate_username();

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.saved_posts enable row level security;
alter table public.follows enable row level security;
alter table public.comments enable row level security;
alter table public.notifications enable row level security;
alter table public.premium_usernames enable row level security;

create policy "profiles readable" on public.profiles for select using(true);
create policy "own profile insert" on public.profiles for insert with check(id=auth.uid() or public.is_admin());
create policy "own profile update" on public.profiles for update using(id=auth.uid() or public.is_admin());
create policy "posts readable" on public.posts for select using(visibility='public' or user_id=auth.uid());
create policy "own posts insert" on public.posts for insert with check(user_id=auth.uid());
create policy "own posts update" on public.posts for update using(user_id=auth.uid() or public.is_admin());
create policy "own posts delete" on public.posts for delete using(user_id=auth.uid() or public.is_admin());
create policy "likes read" on public.post_likes for select using(true);
create policy "likes own" on public.post_likes for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "saved own" on public.saved_posts for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "follows read" on public.follows for select using(true);
create policy "follows own" on public.follows for all using(follower_id=auth.uid()) with check(follower_id=auth.uid());
create policy "comments read" on public.comments for select using(true);
create policy "comments own" on public.comments for insert with check(user_id=auth.uid());
create policy "comments delete" on public.comments for delete using(user_id=auth.uid() or public.is_admin());
create policy "notifications own" on public.notifications for select using(user_id=auth.uid());
create policy "premium public" on public.premium_usernames for select using(true);
create policy "premium admin" on public.premium_usernames for all using(public.is_admin()) with check(public.is_admin());

insert into storage.buckets(id,name,public) values('post-media','post-media',true) on conflict(id) do nothing;
create policy "post media read" on storage.objects for select using(bucket_id='post-media');
create policy "post media upload" on storage.objects for insert with check(bucket_id='post-media' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "post media update" on storage.objects for update using(bucket_id='post-media' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "post media delete" on storage.objects for delete using(bucket_id='post-media' and ((storage.foldername(name))[1]=auth.uid()::text or public.is_admin()));

-- بعد إنشاء حسابك، اجعل حسابك Admin:
-- update public.profiles set is_admin=true where id='AUTH-USER-UUID';
