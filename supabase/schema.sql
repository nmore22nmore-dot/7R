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

-- لا يسمح للمستخدم بإضافة نفسه/أي شخص يدويًا.
-- الإضافة تتم فقط من create_conversation().
create policy members_insert_own
on public.conversation_members
for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.conversations c
    where c.id = conversation_members.conversation_id
  )
);

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
with (security_invoker = true)
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
