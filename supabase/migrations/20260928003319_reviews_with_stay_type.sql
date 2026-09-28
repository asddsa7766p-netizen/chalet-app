-- get_chalet_reviews_with_author: يضيف stay_type (فترة الحجز المقيَّم) كآخر
-- عمود، لشارة الفترة ببطاقة التقييم. الزوار لا يقرؤون bookings (RLS)، والدالة
-- SECURITY DEFINER فتُرجع الفترة فقط دون أي بيانات حجز أخرى.
--
-- مطابق لما طُبّق على القاعدة الحية (jugnkxeqqgtoerlknadm) بتاريخ 2026-09-28.
-- DROP لازم: CREATE OR REPLACE لا يغيّر أعمدة RETURNS TABLE.

drop function if exists public.get_chalet_reviews_with_author(uuid);

create function public.get_chalet_reviews_with_author(p_chalet_id uuid)
returns table (
  id uuid,
  chalet_id uuid,
  user_id uuid,
  booking_id uuid,
  rating integer,
  comment text,
  created_at timestamptz,
  author_full_name text,
  author_avatar_url text,
  stay_type text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    r.id,
    r.chalet_id,
    r.user_id,
    r.booking_id,
    r.rating,
    r.comment,
    r.created_at,
    p.full_name  as author_full_name,
    p.avatar_url as author_avatar_url,
    b.stay_type::text as stay_type
  from public.reviews r
  join public.profiles p on p.id = r.user_id
  left join public.bookings b on b.id = r.booking_id
  where r.chalet_id = p_chalet_id
  order by r.created_at desc;
$$;

-- الحية بلا PUBLIC (proacl: postgres, anon, authenticated, service_role)؛
-- CREATE يمنح PUBLIC افتراضياً، فيُسحب ليطابقها.
revoke execute on function public.get_chalet_reviews_with_author(uuid) from public;
grant execute on function public.get_chalet_reviews_with_author(uuid)
  to anon, authenticated, service_role;
