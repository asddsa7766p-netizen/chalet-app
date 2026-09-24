### lib/data/models/reel_model.dart

- **الوظيفة:** نموذج `ReelModel` لصف جدول `reels` مع بيانات الشاليه المرتبط مُجوينة (denormalized) — يمثّل فيديو Reel واحد جاهزاً للعرض.

- **الشرح التفصيلي:**
  - حقول Reel نفسه: `id, chaletId, videoUrl, thumbnailUrl, description, likesCount, createdAt`.
  - حقول شاليه مُجوينة (بادئة `chalet`): `chaletName, chaletDescription, chaletImages (List<String>), chaletCity, chaletLocation, chaletPricePerNight`.
  - `fromJson`: يقرأ `json['chalets']` كخريطة فرعية (`?? const {}` لو غائبة تماماً)، ثم يستخرج كل حقل شاليه منها بنفس نمط الحماية `as Type? ?? default` المستخدم بباقي النماذج الجيدة بالمشروع. `videoUrl`/`thumbnailUrl` هما الحقلان الوحيدان بـ cast مباشر بلا `?`/fallback (`as String`).
  - `toJson`: يُصدِّر الحقول الأساسية فقط (بدون بيانات الشاليه المُجوينة، منطقي لأنها للقراءة فقط).

- **الاعتماديات:** لا يستورد شيئاً. **من يستخدمه:** [reels_service.dart](../services/reels_service.md) (`fetchReels`)، وعلى الأرجح [reels_screen.dart](../../presentation/screens/reels/reels_screen.md) — يُؤكَّد عند مراجعته.

- **التعامل مع Supabase:** لا اتصال مباشر؛ يمثّل نتيجة `reels.select('*, chalets(*)')`.

- **نقاط القوة:** نمط حماية null متّسق مع بقية نماذج المشروع الجيدة (`chalet_model.dart`)، وفصل منطقي واضح بين حقول الـ Reel وحقول الشاليه المُجوينة (بادئة تسمية واضحة `chalet...`).

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة (سطر 40-41):** `videoUrl: json['video_url'] as String` و`thumbnailUrl: json['thumbnail_url'] as String` — بلا حماية `?`/fallback، بخلاف كل حقل آخر بنفس الدالة. لو وصل صف Reel (نظرياً غير متوقع، لأن `uploadReel` بـ[reels_service.dart](../services/reels_service.md) يُدرِج كلا الحقلين دائماً) بدون أحد هذين الحقلين، سيرمي `TypeError` غير مُترجَم عند عرض قائمة الـ Reels بأكملها (خطأ بعنصر واحد بالقائمة قد يكسر عرض كل القائمة حسب طريقة التكرار بالشاشة المستهلكة — يُتحقَّق عند مراجعة reels_screen.dart).

- **اقتراح الإصلاح:**
  - حماية الحقلين بنفس نمط بقية الدالة، مع تصفية أي صف ناقص بدل تعطّل التحويل بالكامل:
    ```dart
    videoUrl: json['video_url'] as String? ?? '',
    thumbnailUrl: json['thumbnail_url'] as String? ?? '',
    ```
    (أو تصفية الصف كاملاً بطبقة `fetchReels` لو أحد الحقلين الأساسيين مفقود، بدل عرض فيديو بلا رابط).
