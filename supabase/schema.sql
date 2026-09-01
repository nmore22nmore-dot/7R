-- =========================================================
-- N — SECURITY PATCH
-- إصلاحات ScoutMy / Supabase RLS
-- =========================================================

-- =========================================================
-- 1. POSTS — حماية محتوى +21
-- =========================================================

drop policy if exists posts_select_authenticated
on public.posts;

create policy posts_select_authenticated
on public.posts
for select
to authenticated
using (
  (
    adult = false
    or user_id = auth.uid()
    or exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.age >= 21
    )
  )
  and
  (
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
  and (
    adult = false
    or exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.age >= 21
    )
  )
);

-- =========================================================
-- 2. STORIES — منع نشر قصة +21 لمن هم دون 21
-- =========================================================

drop policy if exists stories_insert_own
on public.stories;

create policy stories_insert_own
on public.stories
for insert
to authenticated
with check (
  user_id = auth.uid()
  and (
    adult = false
    or exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.age >= 21
    )
  )
);

-- =========================================================
-- 3. LIVE — منع إنشاء بث +21 لمن هم دون 21
-- =========================================================

drop policy if exists live_insert_own
on public.live_streams;

create policy live_insert_own
on public.live_streams
for insert
to authenticated
with check (
  user_id = auth.uid()
  and (
    adult = false
    or exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.age >= 21
    )
  )
);

-- =========================================================
-- 4. CONVERSATIONS — منع انتحال user_id
-- =========================================================

drop policy if exists conversations_insert_authenticated
on public.conversations;

-- لا يسمح بإنشاء conversation مباشرة.
-- الإنشاء يتم عن طريق الدالة الآمنة بالأسفل.
-- =========================================================


-- =========================================================
-- 5. CREATE CONVERSATION — إنشاء المحادثة بشكل آمن
-- =========================================================

create or replace function public.create_conversation(
  other_user_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  conv_id uuid;
begin

  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if other_user_id is null then
    raise exception 'Invalid recipient';
  end if;

  if other_user_id = auth.uid() then
    raise exception 'Cannot create conversation with yourself';
  end if;

  if not exists (
    select 1
    from public.profiles
    where id = other_user_id
  ) then
    raise exception 'Recipient does not exist';
  end if;

  insert into public.conversations default values
  returning id into conv_id;

  insert into public.conversation_members (
    conversation_id,
    user_id
  )
  values
    (conv_id, auth.uid()),
    (conv_id, other_user_id);

  return conv_id;
end;
$$;

revoke all
on function public.create_conversation(uuid)
from public;

grant execute
on function public.create_conversation(uuid)
to authenticated;


-- =========================================================
-- 6. CONVERSATION MEMBERS
-- =========================================================

drop policy if exists members_insert_own
on public.conversation_members;

-- لا يسمح للعميل بإضافة أعضاء يدويًا.
-- إنشاء أعضاء المحادثة يتم فقط من create_conversation() بصلاحيات موثوقة.
revoke insert
on public.conversation_members
from authenticated;

-- =========================================================
-- 7. حماية الرسائل
-- =========================================================

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
-- 8. حماية LIVE GIFTS من تزوير المرسل
-- =========================================================

drop policy if exists live_gifts_insert_sender
on public.live_gifts;

create policy live_gifts_insert_sender
on public.live_gifts
for insert
to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1
    from public.live_streams ls
    where ls.id = live_gifts.live_id
  )
);

-- =========================================================
-- 9. حماية COIN TRANSACTIONS
-- =========================================================

drop policy if exists coins_insert_own
on public.coin_transactions;

-- لا نسمح للمستخدم بإضافة عملات لنفسه مباشرة.
-- العمليات المالية يجب أن تتم عبر وظائف آمنة.
-- =========================================================


-- =========================================================
-- 10. منع المستخدم من تعديل age / coins / verified لنفسه
-- =========================================================

-- نحذف سياسة التحديث الحالية
drop policy if exists profiles_update_own
on public.profiles;

-- التحديث مسموح فقط للحقول الشخصية المعتادة عبر التطبيق،
-- لكن منع تعديل البيانات الحساسة يحتاج إلى trigger.
create policy profiles_update_own
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());


create or replace function public.protect_profile_sensitive_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin

  -- المستخدم لا يستطيع تغيير عمره بنفسه
  if new.age is distinct from old.age then
    if auth.uid() = old.id then
      new.age := old.age;
    end if;
  end if;

  -- المستخدم لا يستطيع تغيير العملات بنفسه
  if new.coins is distinct from old.coins then
    if auth.uid() = old.id then
      new.coins := old.coins;
    end if;
  end if;

  -- المستخدم لا يستطيع توثيق نفسه
  if new.verified is distinct from old.verified then
    if auth.uid() = old.id then
      new.verified := old.verified;
    end if;
  end if;

  -- المستخدم لا يستطيع تغيير مستويات الدعم
  if new.supporter_level is distinct from old.supporter_level then
    if auth.uid() = old.id then
      new.supporter_level := old.supporter_level;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists protect_profile_sensitive_fields
on public.profiles;

create trigger protect_profile_sensitive_fields
before update on public.profiles
for each row
execute function public.protect_profile_sensitive_fields();


-- =========================================================
-- 11. ملاحظة مهمة بخصوص profiles
-- =========================================================
--
-- email + age + coins موجودة في profiles.
-- سياسة:
--
-- profiles_select_authenticated
-- using (true)
--
-- تعني أن أي مستخدم يستطيع قراءة هذه الأعمدة.
--
-- لذلك لا نتركها مكشوفة.
--
-- سيتم إنشاء public_profiles لعرض البيانات العامة فقط.
-- =========================================================

drop view if exists public.public_profiles;

create view public.public_profiles
with (security_invoker = false)
as
select
  id,
  name,
  username,
  avatar_url,
  verified,
  private_account,
  activity_status,
  allow_messages,
  followers_count,
  following_count,
  posts_count,
  supporter_level,
  created_at,
  updated_at
from public.profiles;


-- =========================================================
-- 12. إيقاف كشف profiles بالكامل للمستخدمين الآخرين
-- =========================================================

drop policy if exists profiles_select_authenticated
on public.profiles;

create policy profiles_select_own
on public.profiles
for select
to authenticated
using (
  id = auth.uid()
);


-- =========================================================
-- 13. صلاحيات view العامة
-- =========================================================

grant select
on public.public_profiles
to authenticated;
grant select
on public.public_profiles
to anon;


-- =========================================================
-- 14. حماية COMMENTS
-- =========================================================

drop policy if exists comments_select_authenticated
on public.comments;

create policy comments_select_authenticated
on public.comments
for select
to authenticated
using (
  exists (
    select 1
    from public.posts p
    where p.id = comments.post_id
      and (
        p.user_id = auth.uid()
        or p.visibility = 'عام'
        or (
          p.visibility = 'المتابعون'
          and exists (
            select 1
            from public.follows f
            where f.follower_id = auth.uid()
              and f.following_id = p.user_id
          )
        )
      )
      and (
        p.adult = false
        or p.user_id = auth.uid()
        or exists (
          select 1
          from public.profiles me
          where me.id = auth.uid()
            and me.age >= 21
        )
      )
  )
);


-- =========================================================
-- 15. حماية LIKES من الإعجاب بمنشورات غير مسموحة
-- =========================================================

drop policy if exists likes_insert_own
on public.post_likes;

create policy likes_insert_own
on public.post_likes
for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.posts p
    where p.id = post_likes.post_id
      and (
        p.adult = false
        or p.user_id = auth.uid()
        or exists (
          select 1
          from public.profiles me
          where me.id = auth.uid()
            and me.age >= 21
        )
      )
  )
);


-- =========================================================
-- 16. حماية SAVED POSTS
-- =========================================================

drop policy if exists saved_insert_own
on public.saved_posts;

create policy saved_insert_own
on public.saved_posts
for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.posts p
    where p.id = saved_posts.post_id
      and (
        p.adult = false
        or p.user_id = auth.uid()
        or exists (
          select 1
          from public.profiles me
          where me.id = auth.uid()
            and me.age >= 21
        )
      )
  )
);


-- =========================================================
-- END SECURITY PATCH
-- =========================================================


-- =========================================================
-- N VIDEO INFRASTRUCTURE — المرحلة الأولى
-- =========================================================

alter table public.posts
  add column if not exists views_count bigint not null default 0;

create table if not exists public.post_views (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

alter table public.post_views enable row level security;

drop policy if exists post_views_insert_own on public.post_views;
create policy post_views_insert_own
on public.post_views for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists post_views_select_own on public.post_views;
create policy post_views_select_own
on public.post_views for select to authenticated
using (user_id = auth.uid());

create or replace function public.register_post_view(target_post_id uuid)
returns void language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if target_post_id is null then raise exception 'Invalid post'; end if;

  insert into public.post_views(post_id, user_id)
  values (target_post_id, auth.uid())
  on conflict (post_id, user_id) do nothing;

  update public.posts
  set views_count = (select count(*) from public.post_views where post_id = target_post_id)
  where id = target_post_id;
end;
$$;

revoke all on function public.register_post_view(uuid) from public;
grant execute on function public.register_post_view(uuid) to authenticated;

insert into storage.buckets (id, name, public)
values ('videos', 'videos', true)
on conflict (id) do update set public = excluded.public;

insert into storage.buckets (id, name, public)
values ('images', 'images', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists videos_insert_own_folder on storage.objects;
create policy videos_insert_own_folder on storage.objects
for insert to authenticated
with check (bucket_id = 'videos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists videos_update_own_folder on storage.objects;
create policy videos_update_own_folder on storage.objects
for update to authenticated
using (bucket_id = 'videos' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'videos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists videos_delete_own_folder on storage.objects;
create policy videos_delete_own_folder on storage.objects
for delete to authenticated
using (bucket_id = 'videos' and (storage.foldername(name))[1] = auth.uid()::text);

-- =========================================================
-- N WALLET / GIFTS / STORE — المرحلة التالية
-- =========================================================

create table if not exists public.n_gift_catalog (
  id text primary key,
  name text not null,
  icon text not null,
  price integer not null check (price > 0),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.n_coin_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  amount integer not null,
  type text not null check (type in ('credit','debit')),
  reason text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.n_gift_sends (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  gift_id text not null references public.n_gift_catalog(id),
  quantity integer not null default 1 check (quantity > 0),
  total_cost integer not null check (total_cost > 0),
  created_at timestamptz not null default now(),
  check (sender_id <> recipient_id)
);

alter table public.n_gift_catalog enable row level security;
alter table public.n_coin_transactions enable row level security;
alter table public.n_gift_sends enable row level security;

drop policy if exists n_gifts_catalog_read on public.n_gift_catalog;
create policy n_gifts_catalog_read on public.n_gift_catalog
for select to authenticated using (active = true);

drop policy if exists n_coin_transactions_own_read on public.n_coin_transactions;
create policy n_coin_transactions_own_read on public.n_coin_transactions
for select to authenticated using (user_id = auth.uid());

drop policy if exists n_gift_sends_participant_read on public.n_gift_sends;
create policy n_gift_sends_participant_read on public.n_gift_sends
for select to authenticated using (sender_id = auth.uid() or recipient_id = auth.uid());

insert into public.n_gift_catalog (id, name, icon, price) values
('rose', 'وردة', '🌹', 5),
('heart', 'قلب', '❤️', 20),
('star', 'نجمة', '⭐', 50),
('diamond', 'ألماسة', '💎', 100),
('crown', 'تاج N', '👑', 500)
on conflict (id) do update set name=excluded.name, icon=excluded.icon, price=excluded.price, active=true;

create or replace function public.n_send_gift(recipient_username text, gift_id text)
returns integer language plpgsql security definer set search_path=public
as $$
declare
  sender uuid := auth.uid();
  recipient uuid;
  gift_price integer;
  current_balance integer;
  new_balance integer;
begin
  if sender is null then raise exception 'غير مسجل الدخول'; end if;
  select id into recipient from public.profiles where lower(username)=lower(trim(both '@' from recipient_username)) limit 1;
  if recipient is null then raise exception 'المستخدم غير موجود'; end if;
  if recipient = sender then raise exception 'لا يمكنك إرسال هدية لنفسك'; end if;
  select price into gift_price from public.n_gift_catalog where id=gift_id and active=true;
  if gift_price is null then raise exception 'الهدية غير متاحة'; end if;
  select coalesce(coins,0) into current_balance from public.profiles where id=sender for update;
  if current_balance < gift_price then raise exception 'رصيد العملات غير كافٍ'; end if;
  update public.profiles set coins=current_balance-gift_price where id=sender returning coins into new_balance;
  insert into public.n_coin_transactions(user_id, amount, type, reason, metadata)
  values(sender, gift_price, 'debit', 'gift_sent', jsonb_build_object('gift_id',gift_id,'recipient_id',recipient));
  insert into public.n_gift_sends(sender_id, recipient_id, gift_id, total_cost)
  values(sender, recipient, gift_id, gift_price);
  return new_balance;
end;
$$;

revoke all on function public.n_send_gift(text,text) from public;
grant execute on function public.n_send_gift(text,text) to authenticated;


-- =========================================================
-- 10. NOTIFICATIONS — نظام إشعارات N
-- =========================================================

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  type text not null check (type in ('like','comment','follow','message','gift','live','system')),
  title text not null,
  body text,
  post_id uuid references public.posts(id) on delete cascade,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_created_idx
on public.notifications(user_id, created_at desc);

alter table public.notifications enable row level security;

drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own
on public.notifications for select to authenticated
using (user_id = auth.uid());

drop policy if exists notifications_update_own on public.notifications;
drop policy if exists notifications_insert_system on public.notifications;

-- الإشعارات تُنشأ من وظائف/Triggers موثوقة فقط.
-- لا نسمح للعميل بتعديل حقول الإشعار أو انتحال actor/type/post_id.
revoke insert, update, delete on public.notifications from authenticated;

create or replace function public.n_mark_notification_read(notification_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  update public.notifications
     set read = true
   where id = notification_id
     and user_id = auth.uid();
  return found;
end;
$$;

revoke all on function public.n_mark_notification_read(uuid) from public;
grant execute on function public.n_mark_notification_read(uuid) to authenticated;

-- بيانات العرض العامة للفاعل (بدون كشف البريد أو البيانات الحساسة).
-- إذا كان public_profiles موجودًا، يمكن للتطبيق جلب username بشكل منفصل.

-- =========================================================
-- N SAFETY CENTER — BLOCKS / REPORTS
-- =========================================================

create table if not exists public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create index if not exists user_blocks_blocked_idx on public.user_blocks(blocked_id);
alter table public.user_blocks enable row level security;

drop policy if exists user_blocks_select_own on public.user_blocks;
create policy user_blocks_select_own on public.user_blocks for select to authenticated
using (blocker_id = auth.uid());
drop policy if exists user_blocks_insert_own on public.user_blocks;
create policy user_blocks_insert_own on public.user_blocks for insert to authenticated
with check (blocker_id = auth.uid() and blocked_id <> auth.uid());
drop policy if exists user_blocks_delete_own on public.user_blocks;
create policy user_blocks_delete_own on public.user_blocks for delete to authenticated
using (blocker_id = auth.uid());

create table if not exists public.content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reported_user_id uuid references auth.users(id) on delete set null,
  post_id uuid references public.posts(id) on delete set null,
  reason text not null check (char_length(trim(reason)) between 2 and 100),
  details text,
  status text not null default 'open' check (status in ('open','reviewing','resolved','dismissed')),
  created_at timestamptz not null default now()
);

create index if not exists content_reports_status_created_idx on public.content_reports(status, created_at desc);
create index if not exists content_reports_reporter_idx on public.content_reports(reporter_id, created_at desc);
alter table public.content_reports enable row level security;

drop policy if exists content_reports_insert_own on public.content_reports;
create policy content_reports_insert_own on public.content_reports for insert to authenticated
with check (reporter_id = auth.uid());
drop policy if exists content_reports_select_own on public.content_reports;
create policy content_reports_select_own on public.content_reports for select to authenticated
using (reporter_id = auth.uid());



-- =========================================================
-- N ADMIN — إدارة المنصة والمحتوى
-- =========================================================

create table if not exists public.n_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.n_user_suspensions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  reason text not null,
  suspended_until timestamptz,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

alter table public.n_admins enable row level security;
alter table public.n_user_suspensions enable row level security;

-- =========================================================
-- N PRODUCTION SESSION HARDENING
-- =========================================================

create or replace function public.n_my_suspension()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select jsonb_build_object(
      'reason', reason,
      'suspended_until', suspended_until,
      'created_at', created_at
    )
    from public.n_user_suspensions
    where user_id = auth.uid()
      and (suspended_until is null or suspended_until > now())
    limit 1),
    '{}'::jsonb
  );
$$;

revoke all on function public.n_my_suspension() from public;
grant execute on function public.n_my_suspension() to authenticated;


-- لا توجد سياسات مباشرة للإدراج/التعديل من العميل؛ إدارة المشرفين تتم من SQL/لوحة Supabase.

drop policy if exists n_admins_select_own on public.n_admins;
create policy n_admins_select_own on public.n_admins for select to authenticated
using (user_id = auth.uid());

drop policy if exists n_user_suspensions_select_self on public.n_user_suspensions;
create policy n_user_suspensions_select_self on public.n_user_suspensions for select to authenticated
using (user_id = auth.uid());

create or replace function public.n_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.n_admins where user_id = auth.uid());
$$;

revoke all on function public.n_is_admin() from public;
grant execute on function public.n_is_admin() to authenticated;

create or replace function public.n_admin_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare result jsonb;
begin
  if not public.n_is_admin() then raise exception 'غير مصرح'; end if;
  select jsonb_build_object(
    'users', (select count(*) from public.profiles),
    'posts', (select count(*) from public.posts),
    'reports_open', (select count(*) from public.content_reports where status = 'open'),
    'reports_reviewing', (select count(*) from public.content_reports where status = 'reviewing'),
    'reports_total', (select count(*) from public.content_reports),
    'live_now', (select count(*) from public.live_streams)
  ) into result;
  return result;
end;
$$;

create or replace function public.n_admin_reports(limit_count integer default 50)
returns table (
  id uuid,
  reporter_id uuid,
  reported_user_id uuid,
  post_id uuid,
  reason text,
  details text,
  status text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.n_is_admin() then raise exception 'غير مصرح'; end if;
  return query
    select r.id, r.reporter_id, r.reported_user_id, r.post_id,
           r.reason, r.details, r.status, r.created_at
    from public.content_reports r
    order by r.created_at desc
    limit greatest(1, least(limit_count, 200));
end;
$$;

create or replace function public.n_admin_set_report_status(report_id uuid, new_status text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.n_is_admin() then raise exception 'غير مصرح'; end if;
  if new_status not in ('open','reviewing','resolved','dismissed') then raise exception 'حالة غير صالحة'; end if;
  update public.content_reports set status = new_status where id = report_id;
  return found;
end;
$$;

create or replace function public.n_admin_suspend_user(target_user_id uuid, suspension_reason text, until_at timestamptz default null)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.n_is_admin() then raise exception 'غير مصرح'; end if;
  if target_user_id = auth.uid() then raise exception 'لا يمكنك إيقاف حسابك'; end if;
  if not exists (select 1 from auth.users where id = target_user_id) then raise exception 'المستخدم غير موجود'; end if;
  insert into public.n_user_suspensions(user_id, reason, suspended_until, created_by)
  values(target_user_id, left(trim(suspension_reason), 500), until_at, auth.uid())
  on conflict (user_id) do update set reason = excluded.reason, suspended_until = excluded.suspended_until, created_by = excluded.created_by, created_at = now();
  return true;
end;
$$;

create or replace function public.n_admin_unsuspend_user(target_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.n_is_admin() then raise exception 'غير مصرح'; end if;
  delete from public.n_user_suspensions where user_id = target_user_id;
  return found;
end;
$$;

revoke all on function public.n_admin_overview() from public;
grant execute on function public.n_admin_overview() to authenticated;
revoke all on function public.n_admin_reports(integer) from public;
grant execute on function public.n_admin_reports(integer) to authenticated;
revoke all on function public.n_admin_set_report_status(uuid,text) from public;
grant execute on function public.n_admin_set_report_status(uuid,text) to authenticated;
revoke all on function public.n_admin_suspend_user(uuid,text,timestamptz) from public;
grant execute on function public.n_admin_suspend_user(uuid,text,timestamptz) to authenticated;
revoke all on function public.n_admin_unsuspend_user(uuid) from public;
grant execute on function public.n_admin_unsuspend_user(uuid) to authenticated;

-- بعد إنشاء حساب المدير في Auth، امنحه الدور من SQL الآمن في لوحة Supabase:
-- insert into public.n_admins(user_id) values ('USER-UUID-HERE');

-- =========================================================
-- 11. REALTIME — إشعارات N الفورية
-- =========================================================

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'notifications'
     ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
exception when others then
  raise notice 'N realtime publication setup skipped: %', sqlerrm;
end $$;

-- =========================================================
-- N VIDEO COVERS — حماية أغلفة الفيديو
-- =========================================================

drop policy if exists images_insert_own
on storage.objects;

create policy images_insert_own
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists images_update_own
on storage.objects;

create policy images_update_own
on storage.objects
for update
to authenticated
using (
  bucket_id = 'images'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists images_delete_own
on storage.objects;

create policy images_delete_own
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- =========================================================
-- N NOTIFICATION AUTOMATION — أحداث التفاعل
-- =========================================================

create or replace function public.n_notify_follow()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.follower_id is not null and new.following_id is not null
     and new.follower_id <> new.following_id then
    insert into public.notifications(user_id, actor_id, type, title, body)
    values (
      new.following_id,
      new.follower_id,
      'follow',
      'متابع جديد',
      'بدأ أحد المستخدمين بمتابعتك'
    );
  end if;
  return new;
end;
$$;

drop trigger if exists n_follow_notification on public.follows;
create trigger n_follow_notification
after insert on public.follows
for each row execute function public.n_notify_follow();

create or replace function public.n_notify_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare owner_id uuid;
begin
  select user_id into owner_id from public.posts where id = new.post_id;
  if owner_id is not null and owner_id <> new.user_id then
    insert into public.notifications(user_id, actor_id, type, title, body, post_id)
    values (
      owner_id,
      new.user_id,
      'like',
      'إعجاب جديد',
      'أعجب أحد المستخدمين بفيديوك',
      new.post_id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists n_like_notification on public.post_likes;
create trigger n_like_notification
after insert on public.post_likes
for each row execute function public.n_notify_like();

create or replace function public.n_notify_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare owner_id uuid;
begin
  select user_id into owner_id from public.posts where id = new.post_id;
  if owner_id is not null and owner_id <> new.user_id then
    insert into public.notifications(user_id, actor_id, type, title, body, post_id)
    values (
      owner_id,
      new.user_id,
      'comment',
      'تعليق جديد',
      'أضاف أحد المستخدمين تعليقًا على فيديوك',
      new.post_id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists n_comment_notification on public.comments;
create trigger n_comment_notification
after insert on public.comments
for each row execute function public.n_notify_comment();

create or replace function public.n_notify_gift()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.sender_id is not null and new.recipient_id is not null
     and new.sender_id <> new.recipient_id then
    insert into public.notifications(user_id, actor_id, type, title, body)
    values (
      new.recipient_id,
      new.sender_id,
      'gift',
      'هدية جديدة',
      'أرسل لك أحد المستخدمين هدية'
    );
  end if;
  return new;
end;
$$;

drop trigger if exists n_gift_notification on public.n_gift_sends;
create trigger n_gift_notification
after insert on public.n_gift_sends
for each row execute function public.n_notify_gift();

create or replace function public.n_notify_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications(user_id, actor_id, type, title, body)
  select cm.user_id, new.sender_id, 'message', 'رسالة جديدة', left(coalesce(new.text, ''), 120)
  from public.conversation_members cm
  where cm.conversation_id = new.conversation_id
    and cm.user_id <> new.sender_id;
  return new;
end;
$$;

drop trigger if exists n_message_notification on public.messages;
create trigger n_message_notification
after insert on public.messages
for each row execute function public.n_notify_message();

revoke all on function public.n_notify_follow() from public;
revoke all on function public.n_notify_like() from public;
revoke all on function public.n_notify_comment() from public;
revoke all on function public.n_notify_gift() from public;
revoke all on function public.n_notify_message() from public;
