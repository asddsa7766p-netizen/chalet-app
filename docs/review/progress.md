# تقدّم المراجعة الشاملة (Makan app)

آخر تحديث: 2026-09-23

هذا الملف يتتبّع أي الملفات تمت مراجعتها بالكامل (قراءة + توثيق في `docs/review/files/...`)
وأيها متبقٍ، حتى يمكن إكمال العمل من حيث توقف لو انقطع السياق.

**قاعدة مهمة:** لا تعديل على أي ملف داخل `lib/`. كل الكتابة تكون داخل `docs/review/` فقط.

ترتيب العمل المطلوب من المستخدم: `core/config/utils` ← `services` ← `models` ← `providers/state` ← `screens` ← `widgets`.

مسار توثيق كل ملف: `docs/review/files/<نفس مسار الملف تحت lib>.md`
(مثال: `lib/core/constants/app_colors.dart` → `docs/review/files/core/constants/app_colors.md`)

## حالة عامة
- [x] فهم pubspec.yaml و main.dart
- [x] قراءة سكربتات supabase/*.sql و edge function — **ملاحظة مهمة:** السكيمة المحلية `supabase/schema.sql` و `owner_dashboard*.sql` **قديمة/غير مطابقة** لوصف المستخدم للباك إند الحالي (لا تحتوي على chalet_stay_types, chalet_weekday_prices, chalet_date_prices, availability, payments, conversations, messages, subscriptions، ولا على الدوال is_chalet_available/get_booked_dates/create_external_booking/cancel_external_booking/toggle_favorite/become_owner/become_customer/admin_*). لذلك الاعتماد الأساسي في التحقق من تطابق التطبيق مع الباك إند هو **وصف المستخدم + ما يستدعيه كود Dart فعلياً**، مع تنويه صريح بعدم التأكد كلما لزم الأمر (لا تخمين).
- [x] كتابة docs/review/00_overview.md
- [x] كتابة docs/review/99_summary.md

# ✅ المراجعة الكاملة منتهية (14/14 دفعة)

## دفعة 1: main.dart + core/constants + core/router + core/theme + core/utils (11 ملف) — ✅ مكتملة
- [x] lib/main.dart
- [x] lib/core/constants/app_colors.dart
- [x] lib/core/constants/app_strings.dart
- [x] lib/core/constants/pricing_constants.dart
- [x] lib/core/router/app_router.dart
- [x] lib/core/theme/app_state_providers.dart
- [x] lib/core/theme/app_theme.dart
- [x] lib/core/theme/locale_notifier.dart
- [x] lib/core/theme/shared_preferences_keys.dart
- [x] lib/core/theme/theme_notifier.dart
- [x] lib/core/utils/currency_formatter.dart

**ملاحظة اكتُشفت أثناء الدفعة:** تحويل flutter_analyze_after_fix.log (كان UTF-16، مكلف بالقراءة) لنسخة UTF-8 بالـ scratchpad ساعد كثيراً بربط الملاحظات بأرقام أسطر حقيقية من analyzer فعلي (267 مشكلة، أغلبها info/withOpacity deprecated + عدد لا بأس به من warning حقيقية: unused_field/unused_element/unused_import/duplicate_import، وأهمها use_build_context_synchronously في login_screen.dart (أسطر 49, 60, 71) و profile_screen.dart (سطر 652) — هذه بالضبط فئة "context بعد await بدون mounted" التي يجب فحصها بعمق عند الوصول لتلك الملفات. سأستخدم هذا اللوج كمرجع إرشادي (leads) في كل الدفعات القادمة، مع التحقق دائماً من رقم السطر الفعلي بالملف الحالي لأن الكود عُدِّل عن نسخة اللوج (git status يُظهر أغلب هذه الملفات كـ M).

## دفعة 2: data/services (10 ملفات) — ✅ مكتملة
- [x] lib/data/services/admin_service.dart
- [x] lib/data/services/dashboard_service.dart
- [x] lib/data/services/host_service.dart
- [x] lib/data/services/location_service.dart
- [x] lib/data/services/notification_service.dart
- [x] lib/data/services/payment_gateway.dart
- [x] lib/data/services/pricing_service.dart
- [x] lib/data/services/reels_service.dart
- [x] lib/data/services/services.dart
- [x] lib/data/services/unavailable_nights.dart

**اكتشافات مهمة بهذه الدفعة (ستُنقل لـ 99_summary.md):**
1. **أمان محتمل حرج (يحتاج تحقق مباشر بلوحة Supabase):** admin_service.dart لا يستخدم أي دالة `admin_*`، بل قراءات مباشرة لجداول profiles/bookings/chalets تعتمد بالكامل على RLS غير المؤكَّد من هنا — قد يسمح لأي مستخدم عادي بقراءة بيانات كل المستخدمين إن لم تكن RLS مقيَّدة فعلياً بـ is_admin.
2. **ازدواجية NotificationService (مفرد، بلا try/catch، 7 نقاط استهلاك) مقابل NotificationsService (جمع بـ services.dart، محمية) — مستخدمتان معاً بنفس الملف (profile_screen.dart).**
3. **ازدواجية فحص isHost()/isAdmin():** نمطان مختلفان (host_service.dart بلا try/catch ولا كاش، مقابل AuthService.isAdmin() بكاش وحماية)، بالإضافة لنسخة ثالثة AdminService.isCurrentUserAdmin() بلا حماية أيضاً.
4. **toggleFavorite (RPC ذرّية، مُصلَحة من Race Condition موثّق) مقابل ReelsService.toggleLike (لا يزال بالنمط القديم غير الآمن SELECT-then-INSERT/DELETE) — نفس المشكلة المُكتشفة والمُصلَحة بمكان لم تُطبَّق بمكان آخر مشابه.**
5. **pricing_service.dart: كل دوال الكتابة (أسعار/أنواع إقامة) بلا try/catch إطلاقاً — خطر خاص لأنها تتحكم بأسعار حقيقية.**
6. **دالة RPC ثالثة لعدم التوفر (`get_chalet_unavailable_dates`) لا تطابق أياً من الاسمين اللذين ذكرهما المستخدم (`is_chalet_available`/`get_booked_dates`) — يحتاج توضيح.**
7. **إصلاح توقيت صيفي حقيقي وموثّق جيداً بـ pricing_service.dart (DST bug فعلي بمنطقة القدس، أكتوبر) — نمط `.add(Duration(days:1))` الخاطئ يستحق تتبعه كـ"عيب معروف" بأي ملف آخر يفعل نفس الشيء دون نفس الإصلاح.**
8. **admin_service.dart وdashboard_service.dart كلاهما يجمّعان بيانات مالية (إيرادات) بجلب كل الصفوف ثم حساب محلي بـ Dart بدل SUM بالسيرفر — admin_service.dart أخطر لأنه يجلب كل حجوزات المنصة بأكملها بلا حدود.**
9. **ملف unavailable_nights.dart من أفضل ملفات المشروع هندسياً (قابل للاختبار، صادق بعدم اليقين، دفاعي بالكامل) — مرجع جودة إيجابي.**

## دفعة 3: data/models (6 ملفات) — ✅ مكتملة
- [x] lib/data/models/booking_payment_details.dart
- [x] lib/data/models/chalet_model.dart
- [x] lib/data/models/manual_booking.dart
- [x] lib/data/models/models.dart
- [x] lib/data/models/notification_model.dart
- [x] lib/data/models/reel_model.dart

**اكتشافات مهمة:**
1. **UserProfile.copyWith (بـ models.dart) يُسقط role/isOwner/isAdmin بصمت — خلل حقيقي مؤكَّد، لكن كود غير مُستخدَم حالياً (dead code)، لا أثر فعلي بعد.**
2. **تأكيد إضافي على ازدواجية NotificationModel (كلاسان بنفس الاسم الحرفي، ملفان منفصلان: notification_model.dart و models.dart) — لا خطأ تصريف (لا ملف يستورد الاثنين معاً) لكنها ازدواجية بيانات كاملة.**
3. **إصلاح DST ثانٍ موثّق (BookingModel.nightsCount بـ models.dart، بعد الأول بـ pricing_service.dart) — نمط متكرر وواعٍ بمشاكل التوقيت الصيفي بمنطقة القدس.**
4. **chalet_model.dart من أفضل نماذج null-safety بالمشروع؛ manual_booking.dart يوثّق بوضوح حماية عمود source بـ trigger.**

## دفعة 4: providers/state (2 ملفات) — ✅ مكتملة
- [x] lib/data/providers/favorites_provider.dart
- [x] lib/presentation/screens/profile/profile_provider.dart

كلا الملفين عالي الجودة (AsyncValue سليم، تحديث تفاؤلي صحيح مع rollback، توثيق معماري ممتاز لسبب استخدام FutureProvider بدل initState). لا اكتشافات حرجة.

## دفعة 5: screens — auth + onboarding + home + splash (7 ملفات + مجلد فارغ) — ✅ مكتملة
- [x] lib/presentation/screens/auth/auth_shared.dart
- [x] lib/presentation/screens/auth/forgot_password_screen.dart
- [x] lib/presentation/screens/auth/login_screen.dart
- [x] lib/presentation/screens/auth/register_screen.dart
- [x] lib/presentation/screens/onboarding/onboarding_screen.dart
- [x] lib/presentation/screens/home/home_tab.dart
- [x] lib/presentation/screens/home/main_screen.dart
- [x] lib/presentation/screens/splash/ (المجلد فارغ من ملفات dart — موثّق في overview فقط)

**اكتشافات مهمة:**
1. **مؤكَّد: `AppStrings.cities` (8 مدن) مستخدمة فعلياً بـsearch_screen.dart لكنها ناقصة (تفتقد طوباس وسلفيت) مقارنة بقائمة home_tab.dart (10 مدن) — نفس عطل "مدن غير قابلة للوصول بالفلتر" الذي وثّق home_tab.dart إصلاحه، لا يزال قائماً بشاشة البحث.**
2. **home_tab.dart أفضل مثال بالمشروع على توثيق إصلاحات حقيقية متتالية (12 إصلاحاً موثّقاً) — مرجع جودة ممتاز.**
3. **login_screen.dart: فجوة mounted حقيقية بحالة toggle_favorite (await جديد بعد الفحص الوحيد للـmounted).**
4. **register_screen.dart: رابط "الشروط والأحكام" TODO فارغ فعلياً بالكود الحالي.**
5. **forgot_password_screen.dart: أفضل مثال بالمشروع على إدارة Timer صحيحة (mounted check داخل كل tick + cancel في dispose).**
6. **اكتُشف مبكراً (أثناء تتبع main_screen.dart): favorites_screen.dart يحتوي فعلياً 3 شاشات غير مترابطة (FavoritesScreen + MyBookingsScreen + ReviewsScreen)؛ my_bookings_screen.dart وreviews_screen.dart مجرد شيمات export سطر واحد — كُتبت مراجعتهما مبكراً (منقولة من دفعة 6، معلَّمة أدناه).**

## دفعة 6: screens — booking + bookings + chalet + favorites + map + reviews (6 ملفات) — ✅ مكتملة
- [x] lib/presentation/screens/booking/booking_screen.dart — **اكتشاف مهم جداً: `_nights` (سطر 103-105) يستخدم نفس نمط DST المعطوب المُصلَح بـmodels.dart لكن غير مُصلَح هنا؛ فجوة mounted وحيدة بكل الملف بـcatch داخل _confirm؛ علمان منفصلان لـonlinePaymentEnabled (هنا وبـapp_router.dart)؛ أفضل دليل بالمشروع على الالتزام بسعر السيرفر (إزالة موثّقة لعمولة 6% وهمية كانت تُعرض فوق السعر الفعلي).**
- [x] lib/presentation/screens/bookings/my_bookings_screen.dart (ملف سطر واحد — تمت المراجعة مبكراً أثناء دفعة 5)
- [x] lib/presentation/screens/chalet/chalet_detail_screen.dart — نظيف نسبياً، بلا فجوات mounted؛ صدق ملحوظ (لا وصف/مرافق/تواصل وهمي).
- [x] lib/presentation/screens/favorites/favorites_screen.dart — **اكتشاف مهم: FavoritesScreen.build() يستدعي _loadChalets (يحتوي setState) بشكل متزامن أثناء build() نفسها عند فحص `_lastIds == null && favState.valueOrNull != null` — خطر "setState during build" حقيقي بوضع Debug.** بالإضافة لاستخدام `_` كمتغيّر مقروء فعلياً بـReviewsScreen (مربك لكن يعمل)، وتكرار _ReviewItem/_ReviewTile بين ملفين.
- [x] lib/presentation/screens/map/palestine_chalets_map_screen.dart — حد ثابت limit:1000، لا زر إعادة محاولة عند الخطأ (الوحيدة بالتطبيق بلا زر كهذا)
- [x] lib/presentation/screens/reviews/reviews_screen.dart (ملف سطر واحد — تمت المراجعة مبكراً أثناء دفعة 5)

## دفعة 7: screens — notifications + profile + reels + search + settings (9 ملفات) — ✅ مكتملة
- [x] lib/presentation/screens/settings/about_app_screen.dart
- [x] lib/presentation/screens/settings/help_support_screen.dart — بطاقات تواصل بلا أي onTap، رقم واتساب نائب حرفي (X)
- [x] lib/presentation/screens/settings/privacy_security_screen.dart — بريد نائب مختلف (yourapp.com)، يتناقض مع help_support
- [x] lib/presentation/screens/settings/settings_screen.dart — **🟠 عرض اللغة غير تفاعلي (يصبح قديماً فوراً)؛ 🟠 ميزة العملة بالكامل بلا أي أثر فعلي بباقي التطبيق رغم أنها تبدو تعمل**
- [x] lib/presentation/screens/notifications/notifications_screen.dart
- [x] lib/presentation/screens/notifications/owner_notifications_screen.dart
- [x] lib/presentation/screens/profile/profile_screen.dart — **🟠 اكتشاف كبير: يحتوي نسخة ثانية كاملة من NotificationsScreen (مستخدمة فعلياً) بينما النسخة الأكمل بمجلد notifications/ كود ميت غير مستورد من أي مكان؛ نفس عطل .characters.first على نص فارغ (مُصلَح مرتين بملفين آخرين) غير مُصلَح هنا على صورة المستخدم الرمزية؛ فجوة mounted بزر حفظ التعديلات.**
- [x] lib/presentation/screens/reels/reels_screen.dart — **🔴 اكتشاف حرج: يهيّئ كل مشغلات الفيديو بالقائمة دفعة واحدة (ليس الفهرس المرئي فقط)، خطر استنزاف ذاكرة/تعطّل حقيقي مع أكثر من بضعة فيديوهات.**
- [x] lib/presentation/screens/search/search_screen.dart — **🟠 اكتشاف: minGuests=2 يُرسل دائماً بصمت حتى بدون تدخل المستخدم (وحتى بعد "مسح الكل")، يستبعد شاليهات سعة ضيف واحد من كل نتائج البحث؛ لا يحدث بـhome_tab.dart (تناقض بين شاشتي تصفّح).**

## دفعة 8: screens — payment + admin (10 ملفات) — ✅ مكتملة
- [x] lib/presentation/screens/admin/admin_dashboard_screen.dart — **🔴 اكتشاف حرج: منح/سحب صلاحية is_admin عبر تحديث جدول profiles مباشر من التطبيق، وليس عبر RPC مخصصة — يعتمد بالكامل على RLS غير مؤكَّدة؛ حظر مستخدم بضغطة واحدة بلا تأكيد.**
- [x] lib/presentation/screens/payment/card_details_screen.dart — خيار "حفظ البطاقة" بلا أي تخزين فعلي
- [x] lib/presentation/screens/payment/payment_failed_screen.dart — زر "تحتاج مساعدة؟" بلا وظيفة
- [x] lib/presentation/screens/payment/payment_flow_entry.dart — **🟠 يعيد إنتاج مشكلة تسعير وهمي (5% إضافية) أُصلِحت عمداً بـbooking_screen.dart؛ لو فُعِّل الدفع كما هو ستعود المشكلة**
- [x] lib/presentation/screens/payment/payment_method_screen.dart — تكرار نسخ-لصق: قسم "مزايا الحجز" مكرَّر مرتين حرفياً
- [x] lib/presentation/screens/payment/payment_processing_screen.dart — من أفضل ملفات المجموعة (PopScope يمنع رجوع أثناء الدفع، pushReplacement نظيف)
- [x] lib/presentation/screens/payment/payment_review_screen.dart — استيراد flutter_material مزدوج غير ضروري (نمط متكرر بـ3 ملفات)
- [x] lib/presentation/screens/payment/payment_success_screen.dart — 🟠 ثلاثة أزرار رئيسية (عرض/مشاركة/تقويم) بلا وظيفة على شاشة النجاح نفسها
- [x] lib/presentation/screens/theme/payment_theme.dart
- [x] lib/presentation/screens/widgets/payment_widgets.dart — تناقض محتمل باتجاه سهم الرجوع مقارنة بـauth_shared.dart، يحتاج تحقق بصري

## دفعة 9: screens/owner — الجزء 1: pricing/edit models (9 ملفات) — ✅ مكتملة
- [x] lib/presentation/screens/owner/base_price_notice.dart
- [x] lib/presentation/screens/owner/chalet_edit_data_source.dart — **نمط مرجعي ممتاز: يتحقق من عدد صفوف UPDATE (RLS silent-reject) بخلاف services.dart**
- [x] lib/presentation/screens/owner/chalet_edit_model.dart — قائمة بيضاء صريحة للأعمدة القابلة للتعديل (حماية حقول محمية نموذجية)
- [x] lib/presentation/screens/owner/chalet_edit_validation.dart — normalizeDigits لمعالجة الأرقام العربية-الهندية (معزولة، غير مُعمَّمة)
- [x] lib/presentation/screens/owner/chalet_images_editor.dart
- [x] lib/presentation/screens/owner/chalet_pricing_screen.dart — **🟠 كل حقل سعر بالشاشة عرضة لعدم قبول أرقام عربية-هندية؛ تسريب Controller بـ_addDateOverride؛ فجوة mounted وحيدة بـ_deleteDateOverride. مقابل ذلك: أفضل حماية "تعديلات غير محفوظة" بكل المشروع.**
- [x] lib/presentation/screens/owner/effective_price_panel.dart
- [x] lib/presentation/screens/owner/pricing_data_source.dart
- [x] lib/presentation/screens/owner/pricing_preview.dart

**ملاحظة عامة على الدفعة:** وحدة "تعديل/تسعير الشاليه" (8 من 9 ملفات) من أعلى أجزاء المشروع جودة هندسية — منطق نقي قابل للاختبار، Dependency Inversion حقيقي، تحقق من عدد صفوف RLS، حماية فقدان بيانات شاملة، وإصلاحات فيض نص مُثبَتة بالاختبار الفعلي (نص كبير + ويب). المشكلة الوحيدة المتكررة: عدم تعميم `normalizeDigits` (معالجة الأرقام العربية) خارج هذه الوحدة تحديداً.

## دفعة 10: screens/owner — الجزء 2: add/edit chalet screens + chalets list (3 ملفات ضخمة) — ✅ مكتملة
- [x] lib/presentation/screens/owner/owner_add_chalet_screen.dart — **🟠 _uploadNewImages دالة ميتة ومعطوبة بالكامل؛ 🟠 لا زر "رجوع" بالمعالج رغم وجود _handleStepCancel جاهزة؛ مسار التعديل بهذا الملف غير قابل للوصول فعلياً (التعديل بملف منفصل).**
- [x] lib/presentation/screens/owner/owner_edit_chalet_screen.dart — **من أفضل ملفين بكل المشروع (مع chalet_pricing_screen.dart): تحقق ملكية صريح، فحص RLS صفوف، رفض صور ناقصة، لا فجوات mounted.**
- [x] lib/presentation/screens/owner/owner_chalets_screen.dart — **🟠 Future.wait يقرن تحميل الشاليهات بعدّاد إشعارات هش؛ فشل الأخير يُخفي القائمة كاملة.** توثيق صادق لعطل سابق (بيانات وهمية ثابتة).

## دفعة 11: screens/owner — الجزء 3: bookings + manual booking + calendar (10 ملفات)
- [x] lib/presentation/screens/owner/manual_booking_actions.dart — يستدعي RPC (cancelExternalBooking) لا تحديث مباشر، أقل خطراً من owner_booking_actions.dart؛ canCancelManualBooking غير معرَّضة لعائلة DST bug.
- [x] lib/presentation/screens/owner/manual_booking_sheet.dart — عالي الجودة: حقن اعتماديات كامل، حماية Race Condition مزدوجة (_priceToken + فحص chaletId)، إعادة استخدام isDayDisabledForStay. 🟡 نفس DST bug (عرض فقط، سطر 750)؛ 🟡 ازدواجية أخرى لتطبيع الأرقام العربية (parseManualPrice).
- [x] lib/presentation/screens/owner/owner_booking_actions.dart — **🟠 مؤكَّد: confirmBookingFlow/rejectBookingFlow يعرضان "نجاح" لمجرد غياب استثناء، رغم أن confirmIncomingBooking/rejectIncomingBooking (services.dart) بلا فحص عدد صفوف RLS — رسالة نجاح كاذبة محتملة حقيقية للمالك.**
- [x] lib/presentation/screens/owner/owner_bookings_screen.dart — **🟠 تكرار ثانٍ مؤكَّد لعطل اقتران Future.wait (نفس owner_chalets_screen.dart)؛ 🟠 عدم تناظر حماية الضغط المزدوج بين _onConfirm (محمي) و_onReject (غير محمي أثناء طلب الشبكة الفعلي).** 🟡 getIncomingBookings بلا limit؛ 🟡 GridView overflow محتمل؛ 🟡 عرض تاريخ يتجاهل عبور الشهر.
- [x] lib/presentation/screens/owner/owner_calendar_data_source.dart — نمط Dependency Inversion جيد؛ منطق تقاطع تواريخ صحيح؛ يتفادى DST عبر مقارنة نصوص ISO. 🟡 unblockDates بلا تحقق صفوف RLS (نفس النمط، استهلاك ثالث مؤكَّد لخطر confirm/reject).
- [x] lib/presentation/screens/owner/owner_calendar_logic.dart — **مرجع جودة ممتاز: منطق نقي بالكامل، يستخدم النمط الآمن من DST بشكل صحيح في مكانين (nightNumber بـ.utc(), addDays بمُنشئ يُطبِّع القيم)، صيغ جمع عربية صحيحة نحوياً. لا مخاطر حقيقية.**
- [x] lib/presentation/screens/owner/owner_calendar_screen.dart — **من أفضل ملفين بالمشروع: DI كامل، حماية Race Condition شاملة (_gen)، _init() يحل فعلياً عطل Future.wait الموثَّق بملفين آخرين (مرجع إصلاح جاهز)، أول اهتمام حقيقي بإمكانية الوصول (Semantics) بكل المشروع.** 🟡 _writeAndRefresh (تراجع) يتجاوز _busy؛ 🟡 تناقض a11y مع manual_booking_sheet.dart (لا يزال TableCalendar).
- [x] lib/presentation/screens/owner/owner_calendar_widgets.dart — **وعي حقيقي بإمكانية الوصول (لا اعتماد على اللون وحده، فحص تباين WCAG موثَّق، حد أقصى لتكبير النص بالخلية). أزرار معطَّلة مع تفسير نصي (نمط UX جيد).** 🟡 catch صامت بزر الاتصال بالضيف (لا رسالة خطأ).

## دفعة 11: ✅ مكتملة بالكامل (10/10 ملفات)
- [x] lib/presentation/screens/owner/owner_bottom_nav.dart — إصلاح زر "رسائل" ميت باستبداله بإشعارات حقيقية؛ withOpacity مهجورة فقط.
- [x] lib/presentation/screens/owner/owner_profile_screen.dart — غلاف رفيع يُعيد استخدام ProfileScreen، لا مخاطر خاصة به.

## دفعة 12: screens/owner — الجزء 4: dashboard/reports/external (3 ملفات)
- [x] lib/presentation/screens/owner/owner_dashboard_screen.dart — **🟠 أخطر تكرار لعطل Future.wait (5 طلبات مجمَّعة، يضرب شاشة الدخول الرئيسية للمالك).** أفضل توثيق ذاتي صادق لتاريخ إصلاحات حقيقية بكل المشروع. 🟡 تقدير "حجوزات مؤكدة" قد يشمل pending؛ 🟡 تعليق قديم غير مطابق؛ لا print() (يصحح ملاحظة عامة سابقة).
- [x] lib/presentation/screens/owner/owner_reports_screen.dart — بسيطة ونظيفة. 🟡 Race condition حقيقي عند تبديل المدى الزمني بسرعة (بلا عداد جيل، بخلاف manual_booking_sheet.dart/owner_calendar_screen.dart).
- [x] lib/presentation/screens/owner/owner_external_screen.dart — نظيف ومركَّز؛ أول استخدام لـ.withValues() (API حديث) بكل المشروع. 🟡 زر إلغاء بلا حماية ضغط مزدوج (أخف من owner_bookings_screen.dart لأنه RPC)؛ استهلاك رابع لـgetIncomingBookings بلا limit.

## دفعة 12: ✅ مكتملة بالكامل (3/3 ملفات)

## دفعة 13: presentation/widgets/common (4 ملفات)
- [x] lib/presentation/widgets/common/common_widgets.dart — **🟠 صورة بديلة ثابتة من Unsplash (خدمة خارجية) عند غياب صورة الشاليه — قد تُفهَم كصورة حقيقية للعقار.** 🟡 SectionHeader كود ميت مؤكَّد (بديله LuxurySectionHeader)؛ 🟡 ازدواجية ShimmerCard/LuxuryShimmerCard.
- [x] lib/presentation/widgets/common/language_bottom_sheet.dart — نظيف تماماً، ref.watch صحيح، context.mounted صحيح. يوضِّح أن عطل "عرض اللغة غير تفاعلي" الموثَّق سابقاً مصدره settings_screen.dart نفسها، ليس هذا الملف.
- [x] lib/presentation/widgets/common/login_prompt.dart — **requireAuth مركزية وحقيقية لكل ميزة التصفّح كضيف؛ تحقَّقتُ فعلياً أن تدفّق "احفظ النية → دخول → استئناف" مكتمل التنفيذ عبر login_screen.dart (ليس نصف منجز).** 🟡 LoginPrompt (كلاس الحوار) كود ميت مؤكَّد بالكامل.
- [x] lib/presentation/widgets/common/luxury_widgets.dart — **🟡 مؤكَّد بفحص مباشر: زر مسح البحث "X" بـLuxurySearchBar لا يتفاعل أثناء الكتابة (home_tab.dart لا يمرر onChanged ولا listener).** 🟡 LuxurySectionHeader وLuxuryEmptyState كود ميت مؤكَّد بالكامل (كلاهما، يصحح افتراضاً سابقاً).

## دفعة 13: ✅ مكتملة بالكامل (4/4 ملفات)

## دفعة 14: التقرير النهائي — ✅ مكتملة
- [x] docs/review/99_summary.md — جدول مشاكل مرتَّب حسب الخطورة (3 حرجة، ~14 متوسطة، ~15 مجموعة بسيطة)، أهم 10 إصلاحات قبل الإطلاق، نقاط قوة عامة، تقييم 6.5/10 مع تبرير.

---
## ملاحظات جانبية أثناء المراجعة (تُنقل لاحقاً لـ 99_summary.md)

- 3 ملفات فقط بالتطبيق كله تستخدم `context.mounted` (login_prompt.dart, language_bottom_sheet.dart, manual_booking_sheet.dart) — مؤشر أولي أن فحص mounted بعد await غير منتشر رغم انتشار async+context في 20+ ملف. يحتاج تأكيد لكل ملف على حدة.
- `flutter_secure_storage` مستخدم فعلاً لتخزين جلسة Supabase (main.dart) — نقطة قوة أمنية.
- لا وجود لأي service_role key داخل lib/ (فقط داخل edge function calculate-booking-price، وهو المكان الصحيح لها).
- يوجد Edge Function باسم calculate-booking-price يحسب السعر ويتحقق من التعارض على السيرفر — يحتاج تأكيد إن كان أي كود Dart يستدعيه فعلياً أو أنه غير مستخدم (dead code) والتطبيق يعتمد على RPC أخرى (create_external_booking إلخ) بدلاً منه.
- عدة ملفات بها `catch (e) {}` فارغ تماماً (يبتلع الخطأ بصمت): owner_calendar_screen.dart, owner_calendar_widgets.dart, booking_screen.dart, services.dart, profile_screen.dart — تحتاج فحص دقيق لكل حالة.
- استخدام print() موجود في 6 ملفات فقط (owner_dashboard_screen, register_screen, home_tab, chalet_detail_screen, payment_success_screen, payment_failed_screen) — نقطة يجب فحصها (تسريب معلومات بـ debug، أو أثر أداء).
