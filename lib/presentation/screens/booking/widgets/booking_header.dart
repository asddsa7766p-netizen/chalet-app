part of '../booking_screen.dart';

extension _BookingHeader on _BookingScreenState {
  // ===================== TOP BAR =====================
  Widget _buildTopBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: const CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFFF1EEE6),
            child: Icon(Icons.arrow_back, color: AppColors.charcoal, size: 20),
          ),
        ),
        const Expanded(
          child: Text('الحجز',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal)),
        ),
        const Icon(Icons.favorite_border, color: AppColors.charcoal),
        const SizedBox(width: 14),
        const Icon(Icons.share_outlined, color: AppColors.charcoal),
      ],
    );
  }

  // ===================== CHALET SUMMARY CARD =====================
  Widget _buildChaletCard() {
    // ⚠️ افترضت وجود widget.chalet.rating و widget.chalet.reviewsCount.
    // إذا أسماء الحقول عندك مختلفة بـ ChaletModel، بدّلها هون.
    final rating = _chaletModel?.rating ?? 0.0;
    final reviews = _chaletModel?.reviewsCount ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.sand),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: _chaletModel?.coverImage ?? '',
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 170,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 170,
                    color: Colors.grey[200],
                    child:
                        const Icon(Icons.home_work_rounded, color: Colors.grey),
                  ),
                ),
              ),
              // ⚠️ عداد الصور "1/25" ثابت هون كمثال. إذا عندك قائمة صور
              // فعلية بـ chalet.images (List<String>) بدّل الرقم الثابت
              // بـ _chaletModel?.images.length وفعّل كاروسيل حقيقي.
              if ((_chaletModel?.images.length ?? 0) > 1)
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${_chaletModel?.images.length ?? 0} صور',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: Colors.white)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_chaletModel?.name ?? 'شاليه',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.charcoal)),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: AppColors.textHint),
                      const SizedBox(width: 3),
                      Text(_chaletModel?.city ?? '',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ]),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F2E7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.star_rounded,
                      size: 16, color: Color(0xFFE0A63C)),
                  const SizedBox(width: 4),
                  Text('$rating',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(width: 3),
                  Text('($reviews)',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: AppColors.textSecondary)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ⚠️ أيقونات المرافق ثابتة (مسبح/جلسات خارجية/موقف خاص) كمثال
          // مطابق للصورة. إذا عندك قائمة amenities ديناميكية بالموديل،
          // بدّل هاد الـ Row بـ loop على _chaletModel?.amenities.
          // ✅ إصلاح: كانت الأيقونات (مسبح/جلسات خارجية/موقف خاص) ثابتة لكل
          // الشاليهات بغض النظر عن مرافقها الفعلية — تضليل للمستخدم. الآن من
          // بيانات الشاليه نفسها.
          if (_chaletModel != null &&
              (_chaletModel!.hasPool ||
                  _chaletModel!.hasWifi ||
                  _chaletModel!.hasParking ||
                  _chaletModel!.hasBbq))
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (_chaletModel!.hasPool)
                  _amenityIcon(Icons.pool_rounded, 'مسبح'),
                if (_chaletModel!.hasWifi)
                  _amenityIcon(Icons.wifi_rounded, 'واي فاي'),
                if (_chaletModel!.hasParking)
                  _amenityIcon(Icons.local_parking_outlined, 'موقف خاص'),
                if (_chaletModel!.hasBbq)
                  _amenityIcon(Icons.outdoor_grill_rounded, 'شواء'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _amenityIcon(IconData icon, String label) {
    return Column(children: [
      Icon(icon, color: _BookingScreenState._darkGreen, size: 22),
      const SizedBox(height: 4),
      Text(label,
          style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: AppColors.textSecondary)),
    ]);
  }
}
