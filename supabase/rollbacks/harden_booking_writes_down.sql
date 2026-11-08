-- ROLLBACK لـ migrations/20260930122450_harden_booking_writes.sql — لا يُنفَّذ إلا بقرار صريح.
-- يعيد الحالة الحية كما قُرئت من jugnkxeqqgtoerlknadm بتاريخ 2026-09-30 (قبل التطبيق).
-- خارج مجلد migrations عمداً حتى لا يشغّله supabase db push.
--
-- أثر الرجوع على البيانات:
--   - لا يحذف ولا يعدّل أي صف.
--   - الحجوزات التي أُنشئت أثناء تفعيل الـ migration صالحة أيضاً تحت القواعد القديمة.

begin;

-- 1) triggers ودالة التحقق الجديدة
drop trigger if exists trg_validate_app_booking on public.bookings;
drop function if exists public.validate_app_booking();

drop trigger if exists trg_00_booking_insert_sanitize on public.bookings;

-- 2) enforce_booking_insert_defaults بنصها السابق (SECURITY DEFINER) واسم trigger السابق
create or replace function public.enforce_booking_insert_defaults()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
BEGIN
  IF is_current_user_admin() OR current_setting('app.trusted_booking_insert', true) = 'on' THEN
    RETURN NEW;
  END IF;

  IF NEW.user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'لا يمكن إنشاء حجز نيابة عن مستخدم آخر';
  END IF;

  NEW.status := 'pending';
  NEW.payment_status := 'unpaid';
  NEW.payment_tran_ref := NULL;
  NEW.payment_provider := NULL;
  NEW.deposit_percent := 30;
  NEW.platform_commission_percent := 12;
  NEW.deposit_amount := NULL;
  NEW.platform_commission_amount := NULL;
  NEW.owner_payout_amount := NULL;
  NEW.remaining_cash_amount := NULL;
  NEW.payout_status := 'pending';
  NEW.payout_due_at := NULL;
  NEW.payout_paid_at := NULL;

  RETURN NEW;
END;
$function$;

revoke execute on function public.enforce_booking_insert_defaults() from public, anon, authenticated;

create trigger trg_enforce_booking_insert_defaults
  before insert on public.bookings
  for each row execute function public.enforce_booking_insert_defaults();

-- 3) protect_booking_fields بنصها السابق (SECURITY DEFINER)
create or replace function public.protect_booking_fields()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
DECLARE
  v_is_owner boolean;
BEGIN
  IF is_current_user_admin() THEN
    RETURN NEW;
  END IF;

  -- تعديل موثوق قادم من دالة SECURITY DEFINER داخلية (مثل cancel_external_booking).
  -- app.trusted_booking_update لا يمكن ضبطه من العميل: set_config غير مكشوف عبر PostgREST.
  IF current_setting('app.trusted_booking_update', true) = 'on' THEN
    RETURN NEW;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.chalets c
    WHERE c.id = NEW.chalet_id AND c.owner_id = auth.uid()
  ) INTO v_is_owner;

  IF NEW.user_id                      IS DISTINCT FROM OLD.user_id
     OR NEW.chalet_id                 IS DISTINCT FROM OLD.chalet_id
     OR NEW.check_in                  IS DISTINCT FROM OLD.check_in
     OR NEW.check_out                 IS DISTINCT FROM OLD.check_out
     OR NEW.total_price               IS DISTINCT FROM OLD.total_price
     OR NEW.payment_status            IS DISTINCT FROM OLD.payment_status
     OR NEW.payment_tran_ref          IS DISTINCT FROM OLD.payment_tran_ref
     OR NEW.payment_provider          IS DISTINCT FROM OLD.payment_provider
     OR NEW.deposit_amount            IS DISTINCT FROM OLD.deposit_amount
     OR NEW.deposit_percent           IS DISTINCT FROM OLD.deposit_percent
     OR NEW.platform_commission_percent IS DISTINCT FROM OLD.platform_commission_percent
     OR NEW.platform_commission_amount  IS DISTINCT FROM OLD.platform_commission_amount
     OR NEW.owner_payout_amount       IS DISTINCT FROM OLD.owner_payout_amount
     OR NEW.remaining_cash_amount     IS DISTINCT FROM OLD.remaining_cash_amount
     OR NEW.payout_status             IS DISTINCT FROM OLD.payout_status
     OR NEW.payout_due_at             IS DISTINCT FROM OLD.payout_due_at
     OR NEW.payout_paid_at            IS DISTINCT FROM OLD.payout_paid_at
     OR NEW.source                    IS DISTINCT FROM OLD.source
  THEN
    RAISE EXCEPTION 'غير مسموح تعديل هذه الحقول من طرفك';
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF v_is_owner THEN
      IF NOT (OLD.status = 'pending' AND NEW.status IN ('confirmed', 'rejected')) THEN
        RAISE EXCEPTION 'غير مسموح للمالك بهذا التغيير في حالة الحجز';
      END IF;
    ELSE
      IF NOT (OLD.status IN ('pending', 'confirmed') AND NEW.status = 'cancelled') THEN
        RAISE EXCEPTION 'غير مسموح تغيير حالة الحجز لهذه القيمة';
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

revoke execute on function public.protect_booking_fields() from public, anon, authenticated;

-- 4) القيود الجديدة
alter table public.bookings
  drop constraint if exists bookings_guests_count_min,
  drop constraint if exists bookings_total_price_nonneg,
  drop constraint if exists bookings_notes_length;
alter table public.bookings alter column guests_count drop not null;

-- 5) صلاحية TRUNCATE كما كانت
grant truncate on public.bookings to anon, authenticated;

commit;
