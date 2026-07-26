-- =====================================================
-- Owner Dashboard + Booking status reasons migration
-- Applies to existing schema in supabase/schema.sql
-- =====================================================

BEGIN;

-- 1) Extend bookings.status + add cancelled_by

-- Extend status enum by switching from TEXT CHECK to dedicated type
-- We will keep `status` as TEXT for minimal app changes.
-- Replace CHECK constraint to allow: rejected

-- Drop existing CHECK constraint if present (best-effort)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'bookings_status_check'
  ) THEN
    ALTER TABLE public.bookings DROP CONSTRAINT bookings_status_check;
  END IF;
EXCEPTION WHEN undefined_object THEN
  -- ignore
END $$;

-- Add cancelled_by column if not exists
ALTER TABLE public.bookings
ADD COLUMN IF NOT EXISTS cancelled_by TEXT;

-- Update status constraint to include rejected
ALTER TABLE public.bookings
ADD CONSTRAINT bookings_status_check
CHECK (status IN ('pending', 'confirmed', 'cancelled', 'rejected', 'completed'));

-- 2) Add allowed values constraint for cancelled_by
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'bookings_cancelled_by_check'
  ) THEN
    ALTER TABLE public.bookings
    ADD CONSTRAINT bookings_cancelled_by_check
    CHECK (
      cancelled_by IS NULL
      OR cancelled_by IN ('user','owner','system')
    );
  END IF;
END $$;

-- 3) Indexes for dashboard queries
CREATE INDEX IF NOT EXISTS idx_bookings_chalet_id ON public.bookings(chalet_id);
CREATE INDEX IF NOT EXISTS idx_bookings_user_id ON public.bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON public.bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_check_in ON public.bookings(check_in);
CREATE INDEX IF NOT EXISTS idx_bookings_chalet_status_checkin
ON public.bookings(chalet_id, status, check_in);

-- 4) Update existing data: cancelled_by for already-cancelled rows.
-- We can’t know the real source for historical data.
-- Safe default: treat as owner (so they appear under "رفضها المسؤول")
-- You can change this after reviewing your production data.
UPDATE public.bookings
SET cancelled_by = COALESCE(cancelled_by, 'owner')
WHERE status = 'cancelled';

-- 5) Views for owner dashboard statistics
-- Owner id is auth.uid() (matches chalets.owner_id)

-- Helper view: owner bookings with chalet info
CREATE OR REPLACE VIEW public.owner_dashboard_bookings AS
SELECT
  b.id AS booking_id,
  b.chalet_id,
  b.user_id,
  b.check_in,
  b.status,
  COALESCE(b.cancelled_by, 'owner') AS cancelled_by,
  b.total_price,
  c.name AS chalet_name,
  c.images AS chalet_images,
  c.city AS chalet_city
FROM public.bookings b
JOIN public.chalets c ON c.id = b.chalet_id
WHERE c.owner_id = auth.uid();

-- Date-range views
-- 1) Today (check_in is DATE)
CREATE OR REPLACE VIEW public.owner_dashboard_bookings_today AS
SELECT *
FROM public.owner_dashboard_bookings
WHERE check_in = (CURRENT_DATE);

-- 2) Yesterday
CREATE OR REPLACE VIEW public.owner_dashboard_bookings_yesterday AS
SELECT *
FROM public.owner_dashboard_bookings
WHERE check_in = (CURRENT_DATE - INTERVAL '1 day')::date;

-- 3) Last 7 days (including today)
CREATE OR REPLACE VIEW public.owner_dashboard_bookings_last_7_days AS
SELECT *
FROM public.owner_dashboard_bookings
WHERE check_in BETWEEN (CURRENT_DATE - INTERVAL '6 day')::date AND CURRENT_DATE;

-- 4) Last month (previous calendar month)
CREATE OR REPLACE VIEW public.owner_dashboard_bookings_last_month AS
SELECT *
FROM public.owner_dashboard_bookings
WHERE check_in >= date_trunc('month', CURRENT_DATE - INTERVAL '1 month')::date
  AND check_in <  date_trunc('month', CURRENT_DATE)::date;

-- Aggregation views for cards

-- Total bookings + revenue + per-chalet breakdown for a given date-range
-- We'll create generic views per-range.

CREATE OR REPLACE VIEW public.owner_dashboard_stats_total_today AS
SELECT
  COUNT(*)::int AS total_bookings,
  COALESCE(SUM(total_price), 0)::numeric AS total_revenue,
  ROUND(
    (COUNT(*)::numeric / NULLIF((SELECT COUNT(*) FROM public.owner_dashboard_bookings_today), 0)) * 100
  , 2) AS total_bookings_ratio
FROM public.owner_dashboard_bookings_today;

-- Per-chalet breakdown view (for ratio relative to all bookings in that range)
CREATE OR REPLACE VIEW public.owner_dashboard_stats_by_chalet_today AS
WITH range_total AS (
  SELECT COUNT(*)::numeric AS cnt
  FROM public.owner_dashboard_bookings_today
)
SELECT
  ob.chalet_id,
  ob.chalet_name,
  COALESCE(ob.chalet_city, '') AS chalet_city,
  COUNT(*)::int AS bookings_count,
  COALESCE(SUM(ob.total_price), 0)::numeric AS revenue,
  ROUND((COUNT(*)::numeric / NULLIF(rt.cnt, 0)) * 100, 2) AS ratio_percent
FROM public.owner_dashboard_bookings_today ob
CROSS JOIN range_total rt
GROUP BY ob.chalet_id, ob.chalet_name, ob.chalet_city, rt.cnt;

-- Yesterday
CREATE OR REPLACE VIEW public.owner_dashboard_stats_by_chalet_yesterday AS
WITH range_total AS (
  SELECT COUNT(*)::numeric AS cnt
  FROM public.owner_dashboard_bookings_yesterday
)
SELECT
  ob.chalet_id,
  ob.chalet_name,
  COALESCE(ob.chalet_city, '') AS chalet_city,
  COUNT(*)::int AS bookings_count,
  COALESCE(SUM(ob.total_price), 0)::numeric AS revenue,
  ROUND((COUNT(*)::numeric / NULLIF(rt.cnt, 0)) * 100, 2) AS ratio_percent
FROM public.owner_dashboard_bookings_yesterday ob
CROSS JOIN range_total rt
GROUP BY ob.chalet_id, ob.chalet_name, ob.chalet_city, rt.cnt;

-- Last 7 days
CREATE OR REPLACE VIEW public.owner_dashboard_stats_by_chalet_last_7_days AS
WITH range_total AS (
  SELECT COUNT(*)::numeric AS cnt
  FROM public.owner_dashboard_bookings_last_7_days
)
SELECT
  ob.chalet_id,
  ob.chalet_name,
  COALESCE(ob.chalet_city, '') AS chalet_city,
  COUNT(*)::int AS bookings_count,
  COALESCE(SUM(ob.total_price), 0)::numeric AS revenue,
  ROUND((COUNT(*)::numeric / NULLIF(rt.cnt, 0)) * 100, 2) AS ratio_percent
FROM public.owner_dashboard_bookings_last_7_days ob
CROSS JOIN range_total rt
GROUP BY ob.chalet_id, ob.chalet_name, ob.chalet_city, rt.cnt;

-- Last month
CREATE OR REPLACE VIEW public.owner_dashboard_stats_by_chalet_last_month AS
WITH range_total AS (
  SELECT COUNT(*)::numeric AS cnt
  FROM public.owner_dashboard_bookings_last_month
)
SELECT
  ob.chalet_id,
  ob.chalet_name,
  COALESCE(ob.chalet_city, '') AS chalet_city,
  COUNT(*)::int AS bookings_count,
  COALESCE(SUM(ob.total_price), 0)::numeric AS revenue,
  ROUND((COUNT(*)::numeric / NULLIF(rt.cnt, 0)) * 100, 2) AS ratio_percent
FROM public.owner_dashboard_bookings_last_month ob
CROSS JOIN range_total rt
GROUP BY ob.chalet_id, ob.chalet_name, ob.chalet_city, rt.cnt;

-- Cancelled / Rejected cards (owner view)
-- Rule: cancelled & cancelled_by='user' => user_cancelled
-- rejected OR (cancelled & cancelled_by='owner') => owner_rejected

CREATE OR REPLACE VIEW public.owner_dashboard_stats_cancelled_rejected_today AS
WITH total AS (
  SELECT COUNT(*)::numeric AS total_cnt
  FROM public.owner_dashboard_bookings_today
)
SELECT
  SUM(CASE WHEN status='cancelled' AND cancelled_by='user' THEN 1 ELSE 0 END)::int AS cancelled_by_user,
  SUM(CASE WHEN status='rejected' OR (status='cancelled' AND cancelled_by='owner') THEN 1 ELSE 0 END)::int AS cancelled_or_rejected_by_owner,
  ROUND(
    (
      (SUM(CASE WHEN status='rejected' OR (status='cancelled' AND cancelled_by='owner') THEN 1 ELSE 0 END))
      / NULLIF(t.total_cnt, 0)
    ) * 100
  , 2) AS owner_rejected_ratio_percent
FROM public.owner_dashboard_bookings_today
CROSS JOIN total t;

-- Average daily bookings
-- average = count per day / number of days having in range (range size)
CREATE OR REPLACE VIEW public.owner_dashboard_stats_avg_daily_today AS
WITH days AS (
  SELECT CURRENT_DATE::date AS day
), counts AS (
  SELECT check_in::date AS day, COUNT(*)::numeric AS cnt
  FROM public.owner_dashboard_bookings_today
  GROUP BY check_in::date
)
SELECT
  COALESCE(SUM(cnt)::numeric / (SELECT COUNT(*) FROM days), 0)::numeric AS avg_daily_bookings,
  (SELECT COUNT(*) FROM public.owner_dashboard_bookings_today) AS total_bookings
FROM counts;

-- Last month average (range-aware)
CREATE OR REPLACE VIEW public.owner_dashboard_stats_avg_daily_last_month AS
WITH range_days AS (
  SELECT generate_series(
    date_trunc('month', CURRENT_DATE - INTERVAL '1 month')::date,
    (date_trunc('month', CURRENT_DATE)::date - INTERVAL '1 day')::date,
    interval '1 day'
  )::date AS day
), counts AS (
  SELECT check_in::date AS day, COUNT(*)::numeric AS cnt
  FROM public.owner_dashboard_bookings_last_month
  GROUP BY check_in::date
)
SELECT
  COALESCE(SUM(COALESCE(c.cnt,0))::numeric / NULLIF((SELECT COUNT(*) FROM range_days),0), 0)::numeric AS avg_daily_bookings,
  (SELECT COUNT(*) FROM public.owner_dashboard_bookings_last_month) AS total_bookings
FROM range_days rd
LEFT JOIN counts c ON c.day = rd.day;

-- Yesterday and last 7 days averages
CREATE OR REPLACE VIEW public.owner_dashboard_stats_avg_daily_yesterday AS
WITH range_days AS (
  SELECT (CURRENT_DATE - INTERVAL '1 day')::date AS day
), counts AS (
  SELECT check_in::date AS day, COUNT(*)::numeric AS cnt
  FROM public.owner_dashboard_bookings_yesterday
  GROUP BY check_in::date
)
SELECT
  COALESCE(SUM(COALESCE(c.cnt,0))::numeric / NULLIF((SELECT COUNT(*) FROM range_days),0), 0)::numeric AS avg_daily_bookings,
  (SELECT COUNT(*) FROM public.owner_dashboard_bookings_yesterday) AS total_bookings
FROM range_days rd
LEFT JOIN counts c ON c.day = rd.day;

CREATE OR REPLACE VIEW public.owner_dashboard_stats_avg_daily_last_7_days AS
WITH range_days AS (
  SELECT generate_series(
    (CURRENT_DATE - INTERVAL '6 day')::date,
    CURRENT_DATE::date,
    interval '1 day'
  )::date AS day
), counts AS (
  SELECT check_in::date AS day, COUNT(*)::numeric AS cnt
  FROM public.owner_dashboard_bookings_last_7_days
  GROUP BY check_in::date
)
SELECT
  COALESCE(SUM(COALESCE(c.cnt,0))::numeric / NULLIF((SELECT COUNT(*) FROM range_days),0), 0)::numeric AS avg_daily_bookings,
  (SELECT COUNT(*) FROM public.owner_dashboard_bookings_last_7_days) AS total_bookings
FROM range_days rd
LEFT JOIN counts c ON c.day = rd.day;

-- Total revenue card per range (total revenue + ratio placeholder)
-- Ratio for revenue per-chalet is done via by_chalet_* views.

CREATE OR REPLACE VIEW public.owner_dashboard_stats_revenue_total_today AS
SELECT
  COALESCE(SUM(total_price),0)::numeric AS total_revenue,
  COUNT(*)::int AS total_bookings
FROM public.owner_dashboard_bookings_today;

CREATE OR REPLACE VIEW public.owner_dashboard_stats_revenue_total_yesterday AS
SELECT
  COALESCE(SUM(total_price),0)::numeric AS total_revenue,
  COUNT(*)::int AS total_bookings
FROM public.owner_dashboard_bookings_yesterday;

CREATE OR REPLACE VIEW public.owner_dashboard_stats_revenue_total_last_7_days AS
SELECT
  COALESCE(SUM(total_price),0)::numeric AS total_revenue,
  COUNT(*)::int AS total_bookings
FROM public.owner_dashboard_bookings_last_7_days;

CREATE OR REPLACE VIEW public.owner_dashboard_stats_revenue_total_last_month AS
SELECT
  COALESCE(SUM(total_price),0)::numeric AS total_revenue,
  COUNT(*)::int AS total_bookings
FROM public.owner_dashboard_bookings_last_month;

-- Cancelled/rejected aggregates for other ranges
CREATE OR REPLACE VIEW public.owner_dashboard_stats_cancelled_rejected_yesterday AS
WITH total AS (
  SELECT COUNT(*)::numeric AS total_cnt
  FROM public.owner_dashboard_bookings_yesterday
)
SELECT
  SUM(CASE WHEN status='cancelled' AND cancelled_by='user' THEN 1 ELSE 0 END)::int AS cancelled_by_user,
  SUM(CASE WHEN status='rejected' OR (status='cancelled' AND cancelled_by='owner') THEN 1 ELSE 0 END)::int AS cancelled_or_rejected_by_owner,
  ROUND(
    (
      (SUM(CASE WHEN status='rejected' OR (status='cancelled' AND cancelled_by='owner') THEN 1 ELSE 0 END))
      / NULLIF(t.total_cnt, 0)
    ) * 100
  , 2) AS owner_rejected_ratio_percent
FROM public.owner_dashboard_bookings_yesterday
CROSS JOIN total t;

CREATE OR REPLACE VIEW public.owner_dashboard_stats_cancelled_rejected_last_7_days AS
WITH total AS (
  SELECT COUNT(*)::numeric AS total_cnt
  FROM public.owner_dashboard_bookings_last_7_days
)
SELECT
  SUM(CASE WHEN status='cancelled' AND cancelled_by='user' THEN 1 ELSE 0 END)::int AS cancelled_by_user,
  SUM(CASE WHEN status='rejected' OR (status='cancelled' AND cancelled_by='owner') THEN 1 ELSE 0 END)::int AS cancelled_or_rejected_by_owner,
  ROUND(
    (
      (SUM(CASE WHEN status='rejected' OR (status='cancelled' AND cancelled_by='owner') THEN 1 ELSE 0 END))
      / NULLIF(t.total_cnt, 0)
    ) * 100
  , 2) AS owner_rejected_ratio_percent
FROM public.owner_dashboard_bookings_last_7_days
CROSS JOIN total t;

CREATE OR REPLACE VIEW public.owner_dashboard_stats_cancelled_rejected_last_month AS
WITH total AS (
  SELECT COUNT(*)::numeric AS total_cnt
  FROM public.owner_dashboard_bookings_last_month
)
SELECT
  SUM(CASE WHEN status='cancelled' AND cancelled_by='user' THEN 1 ELSE 0 END)::int AS cancelled_by_user,
  SUM(CASE WHEN status='rejected' OR (status='cancelled' AND cancelled_by='owner') THEN 1 ELSE 0 END)::int AS cancelled_or_rejected_by_owner,
  ROUND(
    (
      (SUM(CASE WHEN status='rejected' OR (status='cancelled' AND cancelled_by='owner') THEN 1 ELSE 0 END))
      / NULLIF(t.total_cnt, 0)
    ) * 100
  , 2) AS owner_rejected_ratio_percent
FROM public.owner_dashboard_bookings_last_month
CROSS JOIN total t;

-- 6) RLS for bookings: allow owners to view their chalets bookings
-- Keep existing users booking policy.

-- Add owner read policy
DROP POLICY IF EXISTS "Owners can view bookings for their chalets" ON public.bookings;
CREATE POLICY "Owners can view bookings for their chalets"
  ON public.bookings
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.chalets c
      WHERE c.id = bookings.chalet_id
        AND c.owner_id = auth.uid()
    )
  );

-- Add owner update policy only for pending bookings -> set status confirmed/cancelled/rejected and cancelled_by accordingly
-- We support:
-- confirmIncomingBooking: set status='confirmed'
-- rejectIncomingBooking: set status='rejected', cancelled_by='owner'
-- cancel/reject by owner: status='cancelled' cancelled_by='owner'
DROP POLICY IF EXISTS "Owners can update pending bookings" ON public.bookings;
CREATE POLICY "Owners can update pending bookings"
  ON public.bookings
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.chalets c
      WHERE c.id = bookings.chalet_id
        AND c.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.chalets c
      WHERE c.id = bookings.chalet_id
        AND c.owner_id = auth.uid()
    )
  );

-- 7) Triggers to set cancelled_by when owner rejects/cancels.
-- Since current app updates only status, we add a trigger to infer.

CREATE OR REPLACE FUNCTION public.set_cancelled_by_owner_reject()
RETURNS TRIGGER AS $$
BEGIN
  -- If status changes to rejected => cancelled_by='owner'
  IF NEW.status = 'rejected' THEN
    NEW.cancelled_by := COALESCE(NEW.cancelled_by, 'owner');
  END IF;

  -- If status changes to cancelled and caller is owner => cancelled_by='owner'
  -- We determine owner based on chalet ownership.
  IF NEW.status = 'cancelled' THEN
    IF EXISTS (
      SELECT 1 FROM public.chalets c
      WHERE c.id = NEW.chalet_id AND c.owner_id = auth.uid()
    ) THEN
      NEW.cancelled_by := COALESCE(NEW.cancelled_by, 'owner');
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_set_cancelled_by_owner_reject ON public.bookings;
CREATE TRIGGER trg_set_cancelled_by_owner_reject
BEFORE UPDATE OF status, cancelled_by
ON public.bookings
FOR EACH ROW
EXECUTE PROCEDURE public.set_cancelled_by_owner_reject();

-- If user cancels in app via cancelBooking(status='cancelled'), set cancelled_by='user' when updater is owner of booking.
CREATE OR REPLACE FUNCTION public.set_cancelled_by_user()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'cancelled' THEN
    IF auth.uid() = NEW.user_id THEN
      NEW.cancelled_by := COALESCE(NEW.cancelled_by, 'user');
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_set_cancelled_by_user ON public.bookings;
CREATE TRIGGER trg_set_cancelled_by_user
BEFORE UPDATE OF status, cancelled_by
ON public.bookings
FOR EACH ROW
EXECUTE PROCEDURE public.set_cancelled_by_user();

COMMIT;

