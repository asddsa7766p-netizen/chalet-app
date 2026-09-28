-- المالك لا يحجز شاليهه من التطبيق (يستخدم الحجز اليدوي)، ولا يقيّم شاليهه ولا
-- حجزاً يدوياً. مطابق لما طُبّق على القاعدة الحية (jugnkxeqqgtoerlknadm)
-- بتاريخ 2026-09-28 (قُرئ باستعلامات قراءة فقط).

-- 1) trigger الحجوزات: رفض حجز التطبيق (source 'app') من مالك الشاليه نفسه.
--    الـ trigger نفسه قائم ولم يتغيّر:
--    CREATE TRIGGER trg_enforce_bookable_chalet BEFORE INSERT ON public.bookings
--      FOR EACH ROW EXECUTE FUNCTION enforce_bookable_chalet()
create or replace function public.enforce_bookable_chalet()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
declare
  c public.chalets;
begin
  select * into c from public.chalets where id = new.chalet_id;

  if c.id is null or c.deleted_at is not null then
    raise exception 'هذا الشاليه لم يعد متاحاً للحجز' using errcode = 'P0001';
  end if;

  -- حجوزات التطبيق تحتاج شاليهاً معتمداً ومتاحاً؛ الحجز اليدوي للمالك يكفيه ألا يكون محذوفاً
  if coalesce(new.source, 'app') = 'app' and (not c.is_approved or not coalesce(c.is_available, true)) then
    raise exception 'هذا الشاليه لم يعد متاحاً للحجز' using errcode = 'P0001';
  end if;

  -- المالك لا يحجز شاليهه عبر التطبيق (يستخدم الحجز اليدوي)
  if coalesce(new.source, 'app') = 'app' and new.user_id = c.owner_id then
    raise exception 'لا يمكنك حجز شاليهك من التطبيق، استخدم الحجز اليدوي' using errcode = 'P0001';
  end if;

  return new;
end;
$function$;

-- ACL الحية: postgres وservice_role فقط (دالة trigger لا تُستدعى مباشرة).
revoke execute on function public.enforce_bookable_chalet() from public, anon, authenticated;
grant execute on function public.enforce_bookable_chalet() to service_role;

-- 2) إدراج التقييم: حجز تطبيق مكتمل للمستخدم نفسه، وليس لشاليه يملكه.
drop policy if exists reviews_insert_completed_booking_own on public.reviews;

create policy reviews_insert_completed_booking_own
  on public.reviews
  as permissive
  for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.bookings b
      join public.chalets c on c.id = b.chalet_id
      where b.id = reviews.booking_id
        and b.user_id = (select auth.uid())
        and b.status = 'completed'
        and b.chalet_id = reviews.chalet_id
        and coalesce(b.source, 'app') = 'app'
        and c.owner_id <> (select auth.uid())
    )
  );
