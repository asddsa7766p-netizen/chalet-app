-- =====================================================
-- شاليهات الأصدقاء - Friends Chalets
-- Supabase Database Schema
-- =====================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- PROFILES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  full_name TEXT,
  phone TEXT,
  avatar_url TEXT,
  email TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'full_name',
    NEW.email
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- =====================================================
-- CHALETS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS chalets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  location TEXT NOT NULL,
  city TEXT NOT NULL,
  price_per_night NUMERIC(10,2) NOT NULL,
  max_guests INT DEFAULT 10,
  bedrooms INT DEFAULT 3,
  bathrooms INT DEFAULT 2,
  has_pool BOOLEAN DEFAULT FALSE,
  has_wifi BOOLEAN DEFAULT TRUE,
  has_bbq BOOLEAN DEFAULT FALSE,
  has_parking BOOLEAN DEFAULT TRUE,
  images TEXT[] DEFAULT '{}',
  owner_id UUID REFERENCES profiles(id),
  rating NUMERIC(3,2) DEFAULT 0.00,
  reviews_count INT DEFAULT 0,
  is_available BOOLEAN DEFAULT TRUE,
  latitude NUMERIC(10,7),
  longitude NUMERIC(10,7),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- BOOKINGS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chalet_id UUID REFERENCES chalets(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  check_in DATE NOT NULL,
  check_out DATE NOT NULL,
  guests_count INT DEFAULT 1,
  total_price NUMERIC(10,2) NOT NULL,
  status TEXT DEFAULT 'pending'
    CHECK (status IN ('pending', 'confirmed', 'cancelled', 'completed')),
  payment_method TEXT DEFAULT 'cash'
    CHECK (payment_method IN ('cash', 'online')),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT valid_dates CHECK (check_out > check_in)
);

-- =====================================================
-- REVIEWS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chalet_id UUID REFERENCES chalets(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  booking_id UUID REFERENCES bookings(id),
  rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update chalet rating when review added
CREATE OR REPLACE FUNCTION update_chalet_rating()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE chalets SET
    rating = (SELECT AVG(rating) FROM reviews WHERE chalet_id = NEW.chalet_id),
    reviews_count = (SELECT COUNT(*) FROM reviews WHERE chalet_id = NEW.chalet_id),
    updated_at = NOW()
  WHERE id = NEW.chalet_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_review_created
  AFTER INSERT ON reviews
  FOR EACH ROW EXECUTE PROCEDURE update_chalet_rating();

-- =====================================================
-- FAVORITES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS favorites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  chalet_id UUID REFERENCES chalets(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, chalet_id)
);

-- =====================================================
-- NOTIFICATIONS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  body TEXT,
  type TEXT CHECK (type IN ('booking_confirmed', 'offer', 'reminder', 'review', 'system')),
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE chalets ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- PROFILES Policies
CREATE POLICY "Users can view their own profile"
  ON profiles FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON profiles FOR UPDATE USING (auth.uid() = id);

-- CHALETS Policies (public read)
CREATE POLICY "Anyone can view available chalets"
  ON chalets FOR SELECT USING (is_available = TRUE);

CREATE POLICY "Owners can manage their chalets"
  ON chalets FOR ALL USING (auth.uid() = owner_id);

-- BOOKINGS Policies
CREATE POLICY "Users can view their own bookings"
  ON bookings FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create bookings"
  ON bookings FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own bookings"
  ON bookings FOR UPDATE USING (auth.uid() = user_id);

-- REVIEWS Policies
CREATE POLICY "Anyone can read reviews"
  ON reviews FOR SELECT USING (TRUE);

CREATE POLICY "Authenticated users can create reviews"
  ON reviews FOR INSERT WITH CHECK (auth.uid() = user_id);

-- FAVORITES Policies
CREATE POLICY "Users can manage their favorites"
  ON favorites FOR ALL USING (auth.uid() = user_id);

-- NOTIFICATIONS Policies
CREATE POLICY "Users can view their notifications"
  ON notifications FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their notifications"
  ON notifications FOR UPDATE USING (auth.uid() = user_id);

-- =====================================================
-- SAMPLE DATA (للاختبار)
-- =====================================================

INSERT INTO chalets (name, description, location, city, price_per_night,
  max_guests, bedrooms, bathrooms, has_pool, has_wifi, has_bbq, has_parking,
  images, rating, reviews_count)
VALUES
  (
    'شاليه جبل الزيتون',
    'شاليه فاخر بإطلالة بانورامية على جبال نابلس، يضم مسبحاً خاصاً وحديقة واسعة. مجهز بالكامل بأحدث المعدات ويتسع لـ 10 أفراد.',
    'جبل عيبال - نابلس', 'نابلس',
    450.00, 10, 4, 3, TRUE, TRUE, TRUE, TRUE,
    ARRAY['https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800',
          'https://images.unsplash.com/photo-1613490493576-7fde63acd811?w=800'],
    4.8, 125
  ),
  (
    'شاليه الريف الأخضر',
    'وسط أشجار الزيتون والطبيعة الخلابة، شاليه يوفر هدوءاً وراحة تامة. مناسب للعائلات الباحثة عن الاسترخاء بعيداً عن الضوضاء.',
    'بيت دقو - رام الله', 'رام الله',
    600.00, 14, 5, 3, TRUE, TRUE, TRUE, TRUE,
    ARRAY['https://images.unsplash.com/photo-1582268611958-ebfd161ef9cf?w=800',
          'https://images.unsplash.com/photo-1510798831971-661eb04b3739?w=800'],
    4.6, 89
  ),
  (
    'شاليه البدر',
    'تجربة فريدة في قلب الطبيعة الجنينية. يطل الشاليه على واد خضراء وبه نافورة مائية ومنطقة شواء مجهزة.',
    'وادي الدير - جنين', 'جنين',
    550.00, 12, 4, 2, FALSE, TRUE, TRUE, TRUE,
    ARRAY['https://images.unsplash.com/photo-1587061949409-02df41d5e562?w=800'],
    4.3, 67
  ),
  (
    'شاليه الخليل الملكي',
    'فيلا فاخرة بتصميم عصري وإطلالة رائعة على المرج الأخضر. يضم مسبحاً مسقوفاً وغرفة ألعاب وصالة أفلام.',
    'حلحول - الخليل', 'الخليل',
    780.00, 16, 6, 4, TRUE, TRUE, TRUE, TRUE,
    ARRAY['https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800'],
    4.9, 203
  ),
  (
    'شاليه بيت لحم الراقي',
    'شاليه مطل على بلدة بيت لحم العريقة، بتصميم تراثي حجري أصيل. مزيج فريد بين الأصالة والحداثة.',
    'بيت جالا - بيت لحم', 'بيت لحم',
    520.00, 8, 3, 2, FALSE, TRUE, FALSE, TRUE,
    ARRAY['https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800'],
    4.5, 44
  ),
  (
    'شاليه أريحا النخيل',
    'في أخفض بقعة على الأرض وأدفأها. شاليه استوائي محاط بأشجار النخيل والليمون، مع جلسات خارجية فاخرة.',
    'عين السلطان - أريحا', 'أريحا',
    380.00, 8, 3, 2, TRUE, TRUE, TRUE, TRUE,
    ARRAY['https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=800'],
    4.4, 56
  );

-- Sample notifications (will be linked to real users after signup)
-- These are templates - actual notifications created via app logic

COMMIT;
