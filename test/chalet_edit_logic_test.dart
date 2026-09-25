import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:makan/core/utils/number_utils.dart';
import 'package:makan/presentation/screens/owner/chalet_form/chalet_edit_model.dart';
import 'package:makan/presentation/screens/owner/chalet_form/chalet_edit_validation.dart';

import 'helpers/chalet_edit_test_harness.dart' show chaletImageUrl, sampleChaletRow;

typedef V = ChaletEditValidation;

ChaletEditValues _base([Map<String, dynamic> overrides = const {}]) =>
    ChaletEditValues.fromRow(sampleChaletRow(overrides: overrides));

/// نسخة من [o] مع تغيير حقول محددة (لبناء "التالي").
ChaletEditValues _with(
  ChaletEditValues o, {
  String? name,
  String? description,
  String? location,
  String? city,
  String? address,
  double? price,
  int? guests,
  int? bedrooms,
  int? bathrooms,
  bool? pool,
  bool? wifi,
  bool? bbq,
  bool? parking,
  bool? available,
  double? lat,
  double? lng,
  bool clearCoords = false,
  List<String>? images,
  String? video,
}) =>
    ChaletEditValues(
      name: name ?? o.name,
      description: description ?? o.description,
      location: location ?? o.location,
      city: city ?? o.city,
      address: address ?? o.address,
      pricePerNight: price ?? o.pricePerNight,
      maxGuests: guests ?? o.maxGuests,
      bedrooms: bedrooms ?? o.bedrooms,
      bathrooms: bathrooms ?? o.bathrooms,
      hasPool: pool ?? o.hasPool,
      hasWifi: wifi ?? o.hasWifi,
      hasBbq: bbq ?? o.hasBbq,
      hasParking: parking ?? o.hasParking,
      isAvailable: available ?? o.isAvailable,
      latitude: clearCoords ? null : (lat ?? o.latitude),
      longitude: clearCoords ? null : (lng ?? o.longitude),
      images: images ?? o.images,
      videoUrl: video ?? o.videoUrl,
    );

void main() {
  group('الأرقام العربية والتحليل', () {
    test('normalizeDigits يحوّل العربية-الهندية والفارسية والفاصلة العشرية', () {
      expect(normalizeDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
      expect(normalizeDigits('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
      expect(normalizeDigits('٣٢٫٥'), '32.5');
      expect(normalizeDigits('١٬٢٠٠'), '1200');
      expect(normalizeDigits('abc 12'), 'abc 12');
    });
    test('parseInt يرفض الكسور والنص', () {
      expect(V.parseInt(' ١٠ '), 10);
      expect(V.parseInt('3.5'), isNull);
      expect(V.parseInt('abc'), isNull);
      expect(V.parseInt(''), isNull);
    });
    test('parseNumber يرفض NaN وInfinity', () {
      expect(V.parseNumber('٣٢٫٢٢'), 32.22);
      expect(V.parseNumber('NaN'), isNull);
      expect(V.parseNumber('Infinity'), isNull);
      expect(V.parseNumber('-Infinity'), isNull);
      expect(V.parseNumber('x'), isNull);
    });
  });

  group('رسائل التحقق', () {
    test('الاسم', () {
      expect(V.name(''), 'اسم الشاليه مطلوب');
      expect(V.name('   '), 'اسم الشاليه مطلوب');
      expect(V.name('a' * 100), isNull);
      expect(V.name('a' * 101), 'الاسم طويل (الحد الأقصى 100 حرف)');
    });
    test('الوصف', () {
      expect(V.description(''), 'وصف الشاليه مطلوب');
      expect(V.description('a' * 2000), isNull);
      expect(V.description('a' * 2001), 'الوصف طويل (الحد الأقصى 2000 حرف)');
    });
    test('عدد الضيوف 1–200 صحيح فقط', () {
      const msg = 'أدخل عدداً صحيحاً بين 1 و200';
      for (final bad in ['', '0', '-1', '201', '3.5', 'abc']) {
        expect(V.maxGuests(bad), msg, reason: bad);
      }
      expect(V.maxGuests('1'), isNull);
      expect(V.maxGuests('200'), isNull);
      expect(V.maxGuests('٥'), isNull);
    });
    test('السعر > 0 و≤ 100000', () {
      for (final bad in ['', '0', '-5', 'abc', '0.0']) {
        expect(V.price(bad), 'أدخل سعراً أكبر من صفر', reason: bad);
      }
      expect(V.price('100000'), isNull);
      expect(V.price('100000.5'), 'سعر غير منطقي');
      expect(V.price('850.5'), isNull);
    });
    test('المدينة والنصوص الاختيارية', () {
      expect(V.city(null), 'اختر المدينة');
      expect(V.city(''), 'اختر المدينة');
      expect(V.city('نابلس'), isNull);
      expect(V.optionalText('a' * 100, 100), isNull);
      expect(V.optionalText('a' * 101, 100),
          'النص طويل (الحد الأقصى 100 حرف)');
    });
    test('رابط اليوتيوب', () {
      expect(V.videoUrl(''), isNull);
      expect(V.videoUrl('https://youtu.be/abc'), isNull);
      expect(V.videoUrl('https://www.youtube.com/watch?v=abc'), isNull);
      expect(V.videoUrl('https://example.com/x'),
          'يرجى إدخال رابط يوتيوب صحيح');
      expect(V.videoUrl('not a url'), 'يرجى إدخال رابط يوتيوب صحيح');
    });
    test('عدد الصور', () {
      expect(V.imagesCount(0), 'أضف صورة واحدة على الأقل');
      expect(V.imagesCount(1), isNull);
    });
  });

  group('الإحداثيات', () {
    test('فارغان: صالح', () {
      final c = V.coordinates('', '  ');
      expect(c.ok, isTrue);
      expect(c.warning, isNull);
    });
    test('أحدهما فقط: يُطلب الاثنان معاً على الحقل الفارغ', () {
      expect(V.coordinates('', '35.2').latError, V.coordinatesTogether);
      expect(V.coordinates('', '35.2').lngError, isNull);
      expect(V.coordinates('32.2', '').lngError, V.coordinatesTogether);
    });
    test('غير رقمي أو خارج المدى العالمي أو (0,0): إحداثيات غير صالحة', () {
      expect(V.coordinates('abc', '35').latError, V.coordinatesInvalid);
      expect(V.coordinates('91', '35').latError, V.coordinatesInvalid);
      expect(V.coordinates('-91', '35').latError, V.coordinatesInvalid);
      expect(V.coordinates('32', '181').lngError, V.coordinatesInvalid);
      expect(V.coordinates('32', '-181').lngError, V.coordinatesInvalid);
      final zero = V.coordinates('0', '0');
      expect(zero.latError, V.coordinatesInvalid);
      expect(zero.lngError, V.coordinatesInvalid);
    });
    test('داخل العالم وخارج فلسطين: تحذير فقط لا خطأ', () {
      final c = V.coordinates('10', '10');
      expect(c.ok, isTrue);
      expect(c.warning, V.coordinatesOutsidePalestine);
    });
    test('داخل حدود فلسطين: لا تحذير، وبالأرقام العربية أيضاً', () {
      expect(V.coordinates('32.2211', '35.2544').warning, isNull);
      expect(V.coordinates('٣٢٫٢٢١١', '٣٥٫٢٥٤٤').ok, isTrue);
      expect(V.coordinates('29', '34').warning, isNull);
      expect(V.coordinates('34', '36.5').warning, isNull);
      expect(V.coordinates('34.01', '35').warning,
          V.coordinatesOutsidePalestine);
    });
  });

  group('فحص ملف الصورة', () {
    test('الحجم: 10MB مقبول و10MB+1 مرفوض', () {
      expect(
          V.imageFile(
              fileName: 'a.jpg', sizeBytes: V.imageMaxBytes),
          isNull);
      expect(
          V.imageFile(
              fileName: 'a.jpg', sizeBytes: V.imageMaxBytes + 1),
          'الصورة "a.jpg" أكبر من 10 ميغابايت');
    });
    test('الصيغة: المسموح JPG/PNG/WEBP/HEIC', () {
      for (final n in ['a.jpg', 'a.JPEG', 'a.png', 'a.webp', 'a.heic']) {
        expect(V.imageFile(fileName: n, sizeBytes: 10), isNull, reason: n);
      }
      expect(V.imageFile(fileName: 'a.gif', sizeBytes: 10),
          'صيغة الصورة "a.gif" غير مدعومة (المسموح: JPG وPNG وWEBP وHEIC)');
      expect(
          V.imageFile(fileName: 'a.bmp', mimeType: 'image/bmp', sizeBytes: 10),
          isNotNull);
    });
    test('mime مسموح يغلب امتداداً غريباً، والمجهول يُقبل', () {
      expect(
          V.imageFile(
              fileName: 'noext', mimeType: 'image/png', sizeBytes: 10),
          isNull);
      expect(V.imageFile(fileName: 'blob', sizeBytes: 10), isNull);
    });
  });

  group('فروقات الحمولة (ChaletEditValues.diffTo)', () {
    test('بلا تغيير: فارغة', () {
      final o = _base();
      expect(o.diffTo(_with(o)), isEmpty);
    });

    test('كل حقل قابل للتعديل يظهر بمفتاحه وحده', () {
      final o = _base();
      final cases = <String, ChaletEditValues>{
        'name': _with(o, name: 'اسم جديد'),
        'description': _with(o, description: 'وصف جديد'),
        'location': _with(o, location: 'حي جديد'),
        'city': _with(o, city: 'جنين'),
        'address': _with(o, address: 'شارع الجامعة'),
        'price_per_night': _with(o, price: 900),
        'max_guests': _with(o, guests: 12),
        'bedrooms': _with(o, bedrooms: 4),
        'bathrooms': _with(o, bathrooms: 3),
        'has_pool': _with(o, pool: false),
        'has_wifi': _with(o, wifi: false),
        'has_bbq': _with(o, bbq: true),
        'has_parking': _with(o, parking: false),
        'is_available': _with(o, available: false),
        'latitude': _with(o, lat: 32.3),
        'longitude': _with(o, lng: 35.3),
        'video_url': _with(o, video: 'https://youtu.be/x'),
        'images': _with(o, images: [o.images[1], o.images[0], o.images[2]]),
      };
      for (final e in cases.entries) {
        final d = o.diffTo(e.value);
        expect(d.keys.toList(), [e.key], reason: e.key);
      }
    });

    test('القيم في الحمولة هي القيم الجديدة بالنوع الصحيح', () {
      final o = _base();
      final d = o.diffTo(_with(o, price: 900.5, guests: 12, pool: false));
      expect(d, {
        'price_per_night': 900.5,
        'max_guests': 12,
        'has_pool': false,
      });
    });

    test('مسح الإحداثيات يرسل null للاثنين', () {
      final o = _base();
      expect(o.diffTo(_with(o, clearCoords: true)),
          {'latitude': null, 'longitude': null});
    });

    test('النص يُقارَن بعد trim، والعنوان/الفيديو الفارغان يساويان null', () {
      final o = _base();
      expect(o.diffTo(_with(o, name: '  ${o.name}  ')), isEmpty);
      expect(o.diffTo(_with(o, address: '   ')), isEmpty);
      expect(o.diffTo(_with(o, video: '')), isEmpty);
      final withAddress = _base({'address': 'شارع'});
      expect(withAddress.diffTo(_with(withAddress, address: '')),
          {'address': null});
    });

    test('الصور: نفس الترتيب لا فرق، والترتيب/الحذف/الإضافة فروق', () {
      final o = _base();
      expect(o.diffTo(_with(o, images: [...o.images])), isEmpty);
      expect(o.diffTo(_with(o, images: o.images.sublist(1)))['images'],
          o.images.sublist(1));
      expect(
          o.diffTo(_with(o, images: [...o.images, chaletImageUrl('d')]))[
              'images'],
          hasLength(4));
    });

    test('لا يظهر أبداً أي عمود محمي أو خارج القائمة (اختبار عشوائي)', () {
      const forbidden = {
        'is_approved',
        'is_featured',
        'owner_id',
        'rating',
        'reviews_count',
        'updated_at',
        'booking_type',
        'min_nights',
        'deposit_amount',
        'id',
        'created_at',
      };
      final rnd = Random(42);
      final o = _base();
      for (var i = 0; i < 300; i++) {
        final next = _with(
          o,
          name: rnd.nextBool() ? 'n$i' : null,
          description: rnd.nextBool() ? 'd$i' : null,
          location: rnd.nextBool() ? 'l$i' : null,
          city: rnd.nextBool() ? 'جنين' : null,
          address: rnd.nextBool() ? 'a$i' : null,
          price: rnd.nextBool() ? 100.0 + i : null,
          guests: rnd.nextBool() ? 1 + i % 50 : null,
          bedrooms: rnd.nextBool() ? 1 + i % 9 : null,
          bathrooms: rnd.nextBool() ? 1 + i % 9 : null,
          pool: rnd.nextBool() ? rnd.nextBool() : null,
          wifi: rnd.nextBool() ? rnd.nextBool() : null,
          bbq: rnd.nextBool() ? rnd.nextBool() : null,
          parking: rnd.nextBool() ? rnd.nextBool() : null,
          available: rnd.nextBool() ? rnd.nextBool() : null,
          lat: rnd.nextBool() ? 30.0 + i / 100 : null,
          lng: rnd.nextBool() ? 35.0 + i / 100 : null,
          images: rnd.nextBool() ? o.images.reversed.toList() : null,
          video: rnd.nextBool() ? 'https://youtu.be/$i' : null,
        );
        final keys = o.diffTo(next).keys.toSet();
        expect(keys.intersection(forbidden), isEmpty);
        expect(chaletEditableColumns.containsAll(keys), isTrue,
            reason: '$keys');
      }
    });

    test('fromRow آمن ضد null وأنواع غريبة، ويقرأ الأرقام النصية', () {
      final v = ChaletEditValues.fromRow({
        'name': null,
        'price_per_night': '800.50', // numeric قد يصل نصاً
        'max_guests': '12',
        'latitude': '32.2211',
        'longitude': 'abc', // نص غير رقمي
        'images': null,
        'address': '   ',
      });
      expect(v.name, '');
      expect(v.pricePerNight, 800.5);
      expect(v.maxGuests, 12);
      expect(v.latitude, 32.2211);
      expect(v.longitude, isNull);
      expect(v.images, isEmpty);
      expect(v.address, isNull);
      expect(v.isAvailable, isTrue);
    });
  });

  group('chaletImageStoragePath — لا يُحذف إلا ملف هذا الشاليه', () {
    test('رابط صحيح تحت chalets/{id}/ يرجع المسار النسبي', () {
      expect(chaletImageStoragePath(chaletImageUrl('a'), 'chalet-1'),
          'chalets/chalet-1/a.jpg');
    });
    test('شاليه آخر أو رابط خارجي أو بلا bucket يرجع null', () {
      expect(
          chaletImageStoragePath(
              chaletImageUrl('a', chaletId: 'other'), 'chalet-1'),
          isNull);
      expect(chaletImageStoragePath('https://example.com/a.jpg', 'chalet-1'),
          isNull);
      expect(
          chaletImageStoragePath(
              'https://x.supabase.co/storage/v1/object/public/other-bucket/chalets/chalet-1/a.jpg',
              'chalet-1'),
          isNull);
      expect(chaletImageStoragePath('', 'chalet-1'), isNull);
    });
    test('مسار ملتوٍ أو بلا اسم ملف يرجع null', () {
      const p =
          'https://x.supabase.co/storage/v1/object/public/chalet-images/';
      expect(chaletImageStoragePath('${p}chalets/chalet-1/../other/a.jpg',
          'chalet-1'), isNull);
      expect(chaletImageStoragePath('${p}chalets/chalet-1/', 'chalet-1'),
          isNull);
      expect(chaletImageStoragePath('${p}chalets/chalet-10/a.jpg', 'chalet-1'),
          isNull);
    });
  });
}
