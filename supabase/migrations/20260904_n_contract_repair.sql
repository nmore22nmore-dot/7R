-- N contract repair / compatibility migration
-- Safe to run against either the original schema or the newer N feature migration.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------
-- POSTS: pin/share metadata
-- ---------------------------------------------------------
alter table public.posts add column if not exists is_pinned boolean not null default false;
alter table public.posts add column if not exists share_count bigint not null default 0;
alter table public.posts add column if not exists updated_at timestamptz not null default now();

create index if not exists posts_user_created_idx on public.posts(user_id, created_at desc);
create unique index if not exists posts_one_pinned_per_user_idx
  on public.posts(user_id) where is_pinned = true;

create or replace function public.n_pin_post(post_id uuid)
returns boolean
language plpgsql security definer set search_path=public
as $$
declare me uuid := auth.uid(); target_owner uuid; already boolean;
begin
  if me is null then raise exception 'Not authenticated'; end if;
  select user_id, is_pinned into target_owner, already from public.posts where id=post_id for update;
  if target_owner is null then raise exception 'المنشور غير موجود'; end if;
  if target_owner <> me then raise exception 'غير مصرح'; end if;

  if already then
    update public.posts set is_pinned=false, updated_at=now() where id=post_id;
    return false;
  end if;

  update public.posts set is_pinned=false, updated_at=now() where user_id=me and is_pinned=true;
  update public.posts set is_pinned=true, updated_at=now() where id=post_id;
  return true;
end;
$$;
revoke all on function public.n_pin_post(uuid) from public;
grant execute on function public.n_pin_post(uuid) to authenticated;

create or replace function public.n_register_share(post_id uuid)
returns bigint
language plpgsql security definer set search_path=public
as $$
declare new_count bigint;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  update public.posts set share_count=coalesce(share_count,0)+1, updated_at=now()
  where id=post_id returning share_count into new_count;
  if new_count is null then raise exception 'المنشور غير موجود'; end if;
  return new_count;
end;
$$;
revoke all on function public.n_register_share(uuid) from public;
grant execute on function public.n_register_share(uuid) to authenticated;

-- ---------------------------------------------------------
-- PROFILE VISITS
-- ---------------------------------------------------------
create table if not exists public.profile_visits (
  visitor_id uuid not null references public.profiles(id) on delete cascade,
  target_profile_id uuid not null references public.profiles(id) on delete cascade,
  visited_at timestamptz not null default now(),
  primary key(visitor_id, target_profile_id)
);

alter table public.profile_visits add column if not exists visited_at timestamptz not null default now();
create index if not exists profile_visits_target_idx on public.profile_visits(target_profile_id, visited_at desc);

create or replace function public.register_profile_visit(target_profile_id uuid)
returns boolean
language plpgsql security definer set search_path=public
as $$
declare me uuid := auth.uid(); last_visit timestamptz;
begin
  if me is null or target_profile_id is null or me=target_profile_id then return false; end if;
  if not exists (select 1 from public.profiles where id=target_profile_id) then return false; end if;
  select visited_at into last_visit from public.profile_visits where visitor_id=me and profile_visits.target_profile_id=register_profile_visit.target_profile_id;
  if last_visit is not null and last_visit > now() - interval '30 minutes' then return false; end if;
  insert into public.profile_visits(visitor_id,target_profile_id,visited_at)
  values(me,target_profile_id,now())
  on conflict(visitor_id,target_profile_id) do update set visited_at=excluded.visited_at;
  return true;
end;
$$;
revoke all on function public.register_profile_visit(uuid) from public;
grant execute on function public.register_profile_visit(uuid) to authenticated;

-- ---------------------------------------------------------
-- COMMENT MANAGEMENT
-- ---------------------------------------------------------
create or replace function public.n_delete_comment(comment_id uuid)
returns boolean
language plpgsql security definer set search_path=public
as $$
declare me uuid := auth.uid(); owner_id uuid; post_owner uuid;
begin
  if me is null then raise exception 'Not authenticated'; end if;
  select c.user_id, p.user_id into owner_id, post_owner
  from public.comments c join public.posts p on p.id=c.post_id
  where c.id=comment_id;
  if owner_id is null then return false; end if;
  if me <> owner_id and me <> post_owner and not public.n_is_admin() then raise exception 'غير مصرح'; end if;
  delete from public.comments where id=comment_id;
  return found;
end;
$$;
revoke all on function public.n_delete_comment(uuid) from public;
grant execute on function public.n_delete_comment(uuid) to authenticated;

-- ---------------------------------------------------------
-- REPORT COMPATIBILITY: support both old target_user_id and new reported_user_id.
-- ---------------------------------------------------------
alter table public.content_reports add column if not exists reported_user_id uuid;
do $$ begin
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='content_reports' and column_name='target_user_id') then
    execute 'update public.content_reports set reported_user_id=target_user_id where reported_user_id is null and target_user_id is not null';
  end if;
end $$;
create index if not exists content_reports_reported_user_idx on public.content_reports(reported_user_id, created_at desc);

-- ---------------------------------------------------------
-- NOTIFICATION COMPATIBILITY: keep old columns while exposing the new contract.
-- ---------------------------------------------------------
alter table public.notifications add column if not exists title text not null default '';
alter table public.notifications add column if not exists body text;
alter table public.notifications add column if not exists read boolean not null default false;
do $$ begin
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='notifications' and column_name='message') then
    execute 'update public.notifications set title=coalesce(nullif(title,''), type), body=coalesce(body, message)';
  end if;
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='notifications' and column_name='is_read') then
    execute 'update public.notifications set read=coalesce(read,is_read,false)';
  end if;
end $$;
create index if not exists notifications_user_created_idx on public.notifications(user_id, created_at desc);

create or replace function public.n_mark_notification_read(notification_id uuid)
returns boolean language plpgsql security definer set search_path=public
as $$
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  update public.notifications set read=true where id=notification_id and user_id=auth.uid();
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='notifications' and column_name='is_read') then
    update public.notifications set is_read=true where id=notification_id and user_id=auth.uid();
  end if;
  return found;
end;
$$;
revoke all on function public.n_mark_notification_read(uuid) from public;
grant execute on function public.n_mark_notification_read(uuid) to authenticated;

-- ---------------------------------------------------------
-- GIFTS / COINS compatibility and recipient credit.
-- ---------------------------------------------------------
alter table public.n_gift_catalog add column if not exists id text;
do $$ begin
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='n_gift_catalog' and column_name='gift_id') then
    execute 'update public.n_gift_catalog set id=gift_id where id is null';
  end if;
end $$;
create unique index if not exists n_gift_catalog_id_uidx on public.n_gift_catalog(id);

alter table public.n_gift_sends add column if not exists total_cost integer;
alter table public.n_coin_transactions add column if not exists type text;
alter table public.n_coin_transactions add column if not exists reason text;
alter table public.n_coin_transactions add column if not exists metadata jsonb;

create or replace function public.n_send_gift(recipient_username text, gift_id text)
returns integer language plpgsql security definer set search_path=public
as $$
declare
  sender uuid := auth.uid(); recipient uuid; gift_price integer; current_balance integer; new_balance integer;
begin
  if sender is null then raise exception 'غير مسجل الدخول'; end if;
  select id into recipient from public.profiles where lower(username)=lower(trim(both '@' from recipient_username)) limit 1;
  if recipient is null then raise exception 'المستخدم غير موجود'; end if;
  if recipient=sender then raise exception 'لا يمكنك إرسال هدية لنفسك'; end if;
  select price into gift_price from public.n_gift_catalog where id=n_send_gift.gift_id and active=true;
  if gift_price is null then raise exception 'الهدية غير متاحة'; end if;
  select coalesce(coins,0) into current_balance from public.profiles where id=sender for update;
  if current_balance < gift_price then raise exception 'رصيد العملات غير كافٍ'; end if;

  update public.profiles set coins=current_balance-gift_price where id=sender returning coins into new_balance;
  update public.profiles set coins=coalesce(coins,0)+gift_price where id=recipient;

  insert into public.n_coin_transactions(user_id, amount, type, reason, metadata)
  values(sender, gift_price, 'debit', 'gift_sent', jsonb_build_object('gift_id',gift_id,'recipient_id',recipient));
  insert into public.n_coin_transactions(user_id, amount, type, reason, metadata)
  values(recipient, gift_price, 'credit', 'gift_received', jsonb_build_object('gift_id',gift_id,'sender_id',sender));

  insert into public.n_gift_sends(sender_id, recipient_id, gift_id, total_cost)
  values(sender, recipient, gift_id, gift_price);
  return new_balance;
end;
$$;
revoke all on function public.n_send_gift(text,text) from public;
grant execute on function public.n_send_gift(text,text) to authenticated;

-- ---------------------------------------------------------
-- Updated-at helper for profiles/posts when supported.
-- ---------------------------------------------------------
create or replace function public.n_set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at=now(); return new; end; $$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.n_set_updated_at();

drop trigger if exists posts_set_updated_at on public.posts;
create trigger posts_set_updated_at before update on public.posts
for each row execute function public.n_set_updated_at();
