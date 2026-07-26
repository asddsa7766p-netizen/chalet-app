-- =====================================================
-- Owner dashboard split views for Chalet Spot design
-- Adds:
-- 1) Total bookings split: شاليه سبوت (blue) vs خارجي (green)
-- 2) Cancelled/rejected split: رفضها المسؤول vs ألغاها المستأجر
--
-- Assumptions based on current schema:
-- - bookings.status is TEXT (pending/confirmed/cancelled/completed + rejected via migration)
-- - bookings.cancelled_by is TEXT with values: user/owner/system (migration already added)
-- - chalets.booking_type exists? In current schema there is booking_type usage in app, but column may not exist.
--
-- To keep this migration safe, we:
-- - Treat "شاليه سبوت" as chalets.booking_type = 'يومي'
-- - Treat "خارجي" as chalets.booking_type = 'خارجي'
-- - If booking_type column does not exist yet, this migration WILL FAIL.
--   Fix: run after ensuring `chalets.booking_type` exists (app already uses it).
--
-- =====================================================

BEGIN;

-- -----------------------------------------------------------------
-- 0) Ensure booking_type column exists in chalets (best-effort)
-- -----------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'chalets'
      AND column_name = 'booking_type'
  ) THEN
    ALTER TABLE public.chalets
      ADD COLUMN booking_type TEXT DEFAULT 'يومي';
  END IF;
END $$;

-- -----------------------------------------------------------------
-- 1) Helper views for owner dashboard bookings with split fields
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW public.owner_dashboard_bookings_base AS
SELECT
  b.id AS booking_id,
  b.chalet_id,
  b.user_id,
  b.check_in,
  b.status,
  COALESCE(b.cancelled_by, 'owner') AS cancelled_by,
  b.total_price,

  c.name AS chalet_name,
  c.city AS chalet_city,
  COALESCE(c.booking_type, 'يومي') AS chalet_booking_type
FROM public.bookings b
JOIN public.chalets c ON c.id = b.chalet_id
WHERE c.owner_id = auth.uid();

-- Date-range views
CREATE OR REPLACE VIEW public.owner_dashboard_bookings_base_today AS
SELECT *
FROM public.owner_dashboard_bookings_base
WHERE check_in = (CURRENT_DATE);

CREATE OR REPLACE VIEW public.owner_dashboard_bookings_base_yesterday AS
SELECT *
FROM public.owner_dashboard_bookings_base
WHERE check_in = (CURRENT_DATE - INTERVAL '1 day')::date;

CREATE OR REPLACE VIEW public.owner_dashboard_bookings_base_last_7_days AS
SELECT *
FROM public.owner_dashboard_bookings_base
WHERE check_in BETWEEN (CURRENT_DATE - INTERVAL '6 day')::date AND CURRENT_DATE;

CREATE OR REPLACE VIEW public.owner_dashboard_bookings_base_last_month AS
SELECT *
FROM public.owner_dashboard_bookings_base
WHERE check_in >= date_trunc('month', CURRENT_DATE - INTERVAL '1 month')::date
  AND check_in <  date_trunc('month', CURRENT_DATE)::date;

-- -----------------------------------------------------------------
-- 2) Total bookings + revenue split by booking_type
--    "شاليه سبوت"  => booking_type = 'يومي'
--    "خارجي"       => booking_type = 'خارجي'
-- -----------------------------------------------------------------

-- TOTAL split: TODAY
CREATE OR REPLACE VIEW public.owner_dashboard_stats_total_split_today AS
SELECT
  -- شاليه سبوت
  SUM(CASE WHEN chalet_booking_type = 'يومي' THEN 1 ELSE 0 END)::int AS total_bookings_spot,
  COALESCE(SUM(CASE WHEN chalet_booking_type = 'يومي' THEN total_price ELSE 0 END),0)::numeric AS total_revenue_spot,

  -- خارجي
  SUM(CASE WHEN chalet_booking_type = 'خارجي' THEN 1 ELSE 0 END)::int AS total_bookings_external,
  COALESCE(SUM(CASE WHEN chalet_booking_type = 'خارجي' THEN total_price ELSE 0 END),0)::numeric AS total_revenue_external
FROM public.owner_dashboard_bookings_base_today;

-- TOTAL split: YESTERDAY
CREATE OR REPLACE VIEW public.owner_dashboard_stats_total_split_yesterday AS
SELECT
  SUM(CASE WHEN chalet_booking_type = 'يومي' THEN 1 ELSE 0 END)::int AS total_bookings_spot,
  COALESCE(SUM(CASE WHEN chalet_booking_type = 'يومي' THEN total_price ELSE 0 END),0)::numeric AS total_revenue_spot,

  SUM(CASE WHEN chalet_booking_type = 'خارجي' THEN 1 ELSE 0 END)::int AS total_bookings_external,
  COALESCE(SUM(CASE WHEN chalet_booking_type = 'خارجي' THEN total_price ELSE 0 END),0)::numeric AS total_revenue_external
FROM public.owner_dashboard_bookings_base_yesterday;

-- TOTAL split: LAST_7_DAYS
CREATE OR REPLACE VIEW public.owner_dashboard_stats_total_split_last_7_days AS
SELECT
  SUM(CASE WHEN chalet_booking_type = 'يومي' THEN 1 ELSE 0 END)::int AS total_bookings_spot,
  COALESCE(SUM(CASE WHEN chalet_booking_type = 'يومي' THEN total_price ELSE 0 END),0)::numeric AS total_revenue_spot,

  SUM(CASE WHEN chalet_booking_type = 'خارجي' THEN 1 ELSE 0 END)::int AS total_bookings_external,
  COALESCE(SUM(CASE WHEN chalet_booking_type = 'خارجي' THEN total_price ELSE 0 END),0)::numeric AS total_revenue_external
FROM public.owner_dashboard_bookings_base_last_7_days;

-- TOTAL split: LAST_MONTH
CREATE OR REPLACE VIEW public.owner_dashboard_stats_total_split_last_month AS
SELECT
  SUM(CASE WHEN chalet_booking_type = 'يومي' THEN 1 ELSE 0 END)::int AS total_bookings_spot,
  COALESCE(SUM(CASE WHEN chalet_booking_type = 'يومي' THEN total_price ELSE 0 END),0)::numeric AS total_revenue_spot,

  SUM(CASE WHEN chalet_booking_type = 'خارجي' THEN 1 ELSE 0 END)::int AS total_bookings_external,
  COALESCE(SUM(CASE WHEN chalet_booking_type = 'خارجي' THEN total_price ELSE 0 END),0)::numeric AS total_revenue_external
FROM public.owner_dashboard_bookings_base_last_month;

-- -----------------------------------------------------------------
-- 3) Cancelled/rejected split by "who canceled" semantics
--    Required:
--    - رفضها المسؤول (owner side) =>
--        rejected OR (status='cancelled' AND cancelled_by='owner')
--    - ألغاها المستأجر (user side) =>
--        cancelled AND cancelled_by='user'
-- -----------------------------------------------------------------

-- TODAY cancelled/rejected split
CREATE OR REPLACE VIEW public.owner_dashboard_stats_cancelled_rejected_split_today AS
SELECT
  -- رفضها المسؤول
  SUM(CASE
    WHEN status = 'rejected'
      OR (status = 'cancelled' AND cancelled_by = 'owner')
    THEN 1 ELSE 0
  END)::int AS cancelled_or_rejected_by_owner,

  -- ألغاها المستأجر
  SUM(CASE
    WHEN status = 'cancelled' AND cancelled_by = 'user'
    THEN 1 ELSE 0
  END)::int AS cancelled_by_user
FROM public.owner_dashboard_bookings_base_today;

-- YESTERDAY
CREATE OR REPLACE VIEW public.owner_dashboard_stats_cancelled_rejected_split_yesterday AS
SELECT
  SUM(CASE
    WHEN status = 'rejected'
      OR (status = 'cancelled' AND cancelled_by = 'owner')
    THEN 1 ELSE 0
  END)::int AS cancelled_or_rejected_by_owner,

  SUM(CASE
    WHEN status = 'cancelled' AND cancelled_by = 'user'
    THEN 1 ELSE 0
  END)::int AS cancelled_by_user
FROM public.owner_dashboard_bookings_base_yesterday;

-- LAST 7 DAYS
CREATE OR REPLACE VIEW public.owner_dashboard_stats_cancelled_rejected_split_last_7_days AS
SELECT
  SUM(CASE
    WHEN status = 'rejected'
      OR (status = 'cancelled' AND cancelled_by = 'owner')
    THEN 1 ELSE 0
  END)::int AS cancelled_or_rejected_by_owner,

  SUM(CASE
    WHEN status = 'cancelled' AND cancelled_by = 'user'
    THEN 1 ELSE 0
  END)::int AS cancelled_by_user
FROM public.owner_dashboard_bookings_base_last_7_days;

-- LAST MONTH
CREATE OR REPLACE VIEW public.owner_dashboard_stats_cancelled_rejected_split_last_month AS
SELECT
  SUM(CASE
    WHEN status = 'rejected'
      OR (status = 'cancelled' AND cancelled_by = 'owner')
    THEN 1 ELSE 0
  END)::int AS cancelled_or_rejected_by_owner,

  SUM(CASE
    WHEN status = 'cancelled' AND cancelled_by = 'user'
    THEN 1 ELSE 0
  END)::int AS cancelled_by_user
FROM public.owner_dashboard_bookings_base_last_month;

COMMIT;

