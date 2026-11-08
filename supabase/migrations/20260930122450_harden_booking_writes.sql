-- حماية كتابة الحجوزات: القاعدة هي المصدر النهائي لقيم الحجز، لا التطبيق.
-- يعالج من تقرير الفحص: SEC-003 وBOOK-002 وBOOK-004 وBOOK-005 وBOOK-001.
-- لا يعدّل أي صف قائم: التحقق يُطبَّق على INSERT الجديد، والقفل على UPDATE القادم.
-- الرجوع: supabase/rollbacks/harden_booking_writes_down.sql
--
-- ترتيب BEFORE INSERT على bookings (Postgres ينفّذها أبجدياً):
--   trg_00_booking_insert_sanitize   ← تنظيف الحقول الحساسة (يجب أن يسبق كل شيء)
--   trg_block_admin_bookings / trg_block_inactive_bookings
--   trg_block_overlapping_bookings   ← فحص مبكر؛ الضمان الحقيقي قيد bookings_no_overlap
--   trg_enforce_bookable_chalet      ← يرى الآن source المنظَّف
--   trg_enforce_booking_total_price  ← السعر من السيرفر
--   trg_enforce_single_day_booking
--   trg_validate_app_booking         ← تحقق مدخلات حجز التطبيق (بعد حساب السعر)

-- =====================================================================
-- 1) SEC-003: تنظيف INSERT غير الموثوق، ويعمل أولاً
-- =====================================================================
-- كان اسمه trg_enforce_booking_insert_defaults فيعمل بعد enforce_bookable_chalet،
-- فيرى ذلك الـ trigger source = 'external' المزوّر ويتخطى فحص الاعتماد والتوفر.
drop trigger if exists trg_enforce_booking_insert_defaults on public.bookings;

create or replace function public.enforce_booking_insert_defaults()
returns trigger
language plpgsql
security invoker
set search_path = public
as $function$
begin
  -- المسار الموثوق الوحيد: create_external_booking (SECURITY DEFINER) يضبط
  -- app.trusted_booking_insert محلياً للمعاملة. set_config غير مكشوف عبر PostgREST.
  if is_current_user_admin() or current_setting('app.trusted_booking_insert', true) = 'on' then
    return new;
  end if;

  if new.user_id is distinct from auth.uid() then
    raise exception 'لا يمكن إنشاء حجز نيابة عن مستخدم آخر';
  end if;

  -- الحجز من العميل هو دائماً حجز تطبيق؛ الحجز اليدوي يمر فقط عبر create_external_booking.
  new.source := 'app';
  new.guest_name := null;
  new.guest_phone := null;
  new.cancelled_by := null;
  -- الدفع الإلكتروني يجب أن يمر عبر مسار خادم موثوق؛ العميل يحجز نقداً فقط.
  new.payment_method := 'cash';

  new.status := 'pending';
  new.payment_status := 'unpaid';
  new.payment_tran_ref := null;
  new.payment_provider := null;
  new.deposit_percent := 30;
  new.platform_commission_percent := 12;
  new.deposit_amount := null;
  new.platform_commission_amount := null;
  new.owner_payout_amount := null;
  new.remaining_cash_amount := null;
  new.payout_status := 'pending';
  new.payout_due_at := null;
  new.payout_paid_at := null;
  new.created_at := now();
  new.updated_at := now();

  return new;
end;
$function$;

revoke execute on function public.enforce_booking_insert_defaults() from public, anon, authenticated;
grant execute on function public.enforce_booking_insert_defaults() to service_role;

create trigger trg_00_booking_insert_sanitize
  before insert on public.bookings
  for each row execute function public.enforce_booking_insert_defaults();

-- =====================================================================
-- 2) BOOK-002 + BOOK-004 + BOOK-005: تحقق مدخلات حجز التطبيق
-- =====================================================================
-- SECURITY INVOKER: كل ما يقرؤه متاح للضيف أصلاً عبر RLS (الشاليه المعتمد
-- المتاح، أنواع الإقامة، حجوزاته هو).
create or replace function public.validate_app_booking()
returns trigger
language plpgsql
security invoker
set search_path = public
as $function$
declare
  -- أقصى عدد طلبات معلّقة لكل مستخدم (BOOK-005).
  c_max_pending constant int := 3;
  -- أبعد تاريخ مسموح للحجز (مطابق لتقويم الضيف: سنة).
  c_max_days_ahead constant int := 365;
  c_max_notes constant int := 1000;
  v_today date := (now() at time zone 'Asia/Hebron')::date;
  v_max_guests int;
  v_has_types boolean;
  v_starts_at timestamptz;
  v_pending int;
begin
  -- الحجز اليدوي للمالك (مسار موثوق) له تحققه داخل create_external_booking.
  if current_setting('app.trusted_booking_insert', true) = 'on'
     or coalesce(new.source, 'app') <> 'app' then
    return new;
  end if;

  -- BOOK-004: عدد الضيوف ضمن سعة الشاليه.
  select c.max_guests into v_max_guests
  from public.chalets c
  where c.id = new.chalet_id;

  if new.guests_count is null or new.guests_count < 1
     or (v_max_guests is not null and new.guests_count > v_max_guests) then
    raise exception 'عدد الضيوف غير مسموح لهذا الشاليه' using errcode = 'P0001';
  end if;

  -- BOOK-002: الفترة يجب أن تكون معروضة فعلاً (نفس منطق التطبيق:
  -- الأنواع المفعّلة إن وُجدت، وإلا 'default' وحدها).
  select exists (
    select 1 from public.chalet_stay_types s
    where s.chalet_id = new.chalet_id and s.is_enabled
  ) into v_has_types;

  if (v_has_types and not exists (
        select 1 from public.chalet_stay_types s
        where s.chalet_id = new.chalet_id
          and s.stay_type = new.stay_type
          and s.is_enabled))
     or (not v_has_types and new.stay_type is distinct from 'default') then
    raise exception 'هذه الفترة غير متاحة في هذا الشاليه' using errcode = 'P0001';
  end if;

  -- total_price حسبه trg_enforce_booking_total_price قبل هذا الـ trigger.
  if new.total_price is null or new.total_price <= 0 then
    raise exception 'سعر هذه الفترة غير متوفر حالياً' using errcode = 'P0001';
  end if;

  -- BOOK-004: لا حجز لفترة بدأت أو ليوم مضى، ولا أبعد من سنة.
  if new.check_in > v_today + c_max_days_ahead then
    raise exception 'لا يمكن الحجز لأكثر من سنة مقدماً' using errcode = 'P0001';
  end if;

  select b.starts_at into v_starts_at from public.booking_period_bounds(new) b;
  if new.check_in < v_today or v_starts_at <= now() then
    raise exception 'هذه الفترة بدأت أو انتهت، اختر يوماً أو فترة أخرى' using errcode = 'P0001';
  end if;

  if new.notes is not null and char_length(new.notes) > c_max_notes then
    raise exception 'الملاحظات طويلة جداً (الحد 1000 حرف)' using errcode = 'P0001';
  end if;

  -- BOOK-005: حد الطلبات المعلّقة. القفل لكل مستخدم يسلسل طلباته المتزامنة،
  -- فلا يمر طلبان معاً قبل أن يرى أحدهما الآخر (قفل معاملة، يُحرَّر تلقائياً).
  perform pg_advisory_xact_lock(hashtextextended('booking_pending_cap:' || new.user_id::text, 0));

  select count(*) into v_pending
  from public.bookings b
  where b.user_id = new.user_id
    and b.status = 'pending'
    and coalesce(b.source, 'app') = 'app';

  if v_pending >= c_max_pending then
    raise exception 'لديك 3 طلبات حجز بانتظار رد المالك. انتظر الرد أو ألغِ أحدها قبل طلب جديد'
      using errcode = 'P0001';
  end if;

  return new;
end;
$function$;

revoke execute on function public.validate_app_booking() from public, anon, authenticated;
grant execute on function public.validate_app_booking() to service_role;

create trigger trg_validate_app_booking
  before insert on public.bookings
  for each row execute function public.validate_app_booking();

-- =====================================================================
-- 3) BOOK-001: قفل حقول الحجز بعد إنشائه
-- =====================================================================
-- كان id وstay_type وguests_count وnotes وguest_* وpayment_method قابلة للتعديل من
-- الضيف أو المالك بعد التأكيد (بلا إعادة تسعير ولا إشعار). التطبيق لا يعدّل إلا status.
create or replace function public.protect_booking_fields()
returns trigger
language plpgsql
security invoker
set search_path = public
as $function$
declare
  v_is_owner boolean;
begin
  if is_current_user_admin() then
    return new;
  end if;

  -- تعديل موثوق من دالة SECURITY DEFINER داخلية (cancel_external_booking،
  -- process_booking_lifecycle، delete_my_account).
  if current_setting('app.trusted_booking_update', true) = 'on' then
    return new;
  end if;

  select exists (
    select 1 from public.chalets c
    where c.id = new.chalet_id and c.owner_id = auth.uid()
  ) into v_is_owner;

  if new.id                           is distinct from old.id
     or new.user_id                   is distinct from old.user_id
     or new.chalet_id                 is distinct from old.chalet_id
     or new.check_in                  is distinct from old.check_in
     or new.check_out                 is distinct from old.check_out
     or new.stay_type                 is distinct from old.stay_type
     or new.guests_count              is distinct from old.guests_count
     or new.notes                     is distinct from old.notes
     or new.guest_name                is distinct from old.guest_name
     or new.guest_phone               is distinct from old.guest_phone
     or new.payment_method            is distinct from old.payment_method
     or new.created_at                is distinct from old.created_at
     or new.total_price               is distinct from old.total_price
     or new.payment_status            is distinct from old.payment_status
     or new.payment_tran_ref          is distinct from old.payment_tran_ref
     or new.payment_provider          is distinct from old.payment_provider
     or new.deposit_amount            is distinct from old.deposit_amount
     or new.deposit_percent           is distinct from old.deposit_percent
     or new.platform_commission_percent is distinct from old.platform_commission_percent
     or new.platform_commission_amount  is distinct from old.platform_commission_amount
     or new.owner_payout_amount       is distinct from old.owner_payout_amount
     or new.remaining_cash_amount     is distinct from old.remaining_cash_amount
     or new.payout_status             is distinct from old.payout_status
     or new.payout_due_at             is distinct from old.payout_due_at
     or new.payout_paid_at            is distinct from old.payout_paid_at
     or new.source                    is distinct from old.source
  then
    raise exception 'غير مسموح تعديل هذه الحقول من طرفك';
  end if;

  -- cancelled_by يحسبه trg_set_cancelled_by (يعمل بعد هذا الـ trigger) من هوية
  -- المستدعي؛ قيمة العميل تُهمل.
  new.cancelled_by := old.cancelled_by;

  if new.status is distinct from old.status then
    if v_is_owner then
      if not (old.status = 'pending' and new.status in ('confirmed', 'rejected')) then
        raise exception 'غير مسموح للمالك بهذا التغيير في حالة الحجز';
      end if;
    else
      if not (old.status in ('pending', 'confirmed') and new.status = 'cancelled') then
        raise exception 'غير مسموح تغيير حالة الحجز لهذه القيمة';
      end if;
    end if;
  end if;

  return new;
end;
$function$;

revoke execute on function public.protect_booking_fields() from public, anon, authenticated;
grant execute on function public.protect_booking_fields() to service_role;

-- =====================================================================
-- 4) BOOK-004: قيود على الجدول نفسه (خط دفاع أخير لأي مسار كتابة)
-- =====================================================================
-- البيانات القائمة متوافقة (تم التحقق قبل التطبيق).
alter table public.bookings alter column guests_count set not null;
alter table public.bookings
  add constraint bookings_guests_count_min check (guests_count >= 1),
  add constraint bookings_total_price_nonneg check (total_price >= 0),
  add constraint bookings_notes_length check (notes is null or char_length(notes) <= 1000);

-- =====================================================================
-- 5) دفاع إضافي: PostgREST لا يكشف TRUNCATE، لكن لا داعي لمنحه للعملاء
-- =====================================================================
revoke truncate on public.bookings from anon, authenticated;

-- ملاحظة BOOK-005: الطلب المعلّق ما زال يُلغى عند بدء فترته فقط
-- (process_booking_lifecycle دون تغيير). مهلة رد للمالك (مثل 24 ساعة) مؤجلة
-- لما بعد إشعارات push، وإلا أُلغيت طلبات حقيقية لم يرها المالك. الإغراق
-- يغطيه حد 3 طلبات معلّقة لكل مستخدم في validate_app_booking.
