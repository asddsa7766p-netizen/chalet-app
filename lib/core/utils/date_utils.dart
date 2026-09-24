/// عدد الليالي (الأيام التقويمية) بين تاريخين، بتجاهل الوقت.
///
/// الفرق بين تاريخين محليين عبر تغيير التوقيت الصيفي (DST) يكون 23 أو 25
/// ساعة، فـ `checkOut.difference(checkIn).inDays` يعطي أحياناً ليلة أقل
/// (مثال: 25→27 مارس 2027). الحساب بتواريخ UTC يعطي العدد الفعلي دائماً.
/// سالب إن كان [checkOut] قبل [checkIn].
int nightsBetween(DateTime checkIn, DateTime checkOut) =>
    DateTime.utc(checkOut.year, checkOut.month, checkOut.day)
        .difference(DateTime.utc(checkIn.year, checkIn.month, checkIn.day))
        .inDays;
