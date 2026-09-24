### lib/presentation/screens/owner/owner_profile_screen.dart

- **الوظيفة:** غلاف رفيع (12 سطراً) يُعيد استخدام [`ProfileScreen`](../profile/profile_screen.md) نفسها (شاشة "حسابي" الخاصة بالعميل) كصفحة "ملفي" بقسم المالك — لا محتوى خاص به.

- **الشرح التفصيلي:** `OwnerProfileScreen extends StatelessWidget` يُرجع `const ProfileScreen()` مباشرة بدون أي معطى إضافي. منطقي: `ProfileScreen` تعرض أصلاً أزرار خاصة بالمالك (لوحة التحكم، إلخ) حسب `isHost` من `profileProvider`، فلا حاجة لنسخة منفصلة.

- **الاعتماديات:** `profile_screen.dart`. **من يستخدمه:** [app_router.dart](../../../core/router/app_router.md) (مسار `/owner-profile`).

- **التعامل مع Supabase:** لا يوجد مباشرة (يُفوَّض بالكامل لـ`ProfileScreen`).

- **نقاط القوة:** إعادة استخدام منطقية بدل تكرار شاشة "حسابي" بنسخة موازية.

- **الأخطاء والمخاطر المحتملة:** لا مخاطر تُذكر بهذا الملف تحديداً؛ أي مخاطر فعلية تخص [profile_screen.dart](../profile/profile_screen.md) نفسها (مُراجَعة سابقاً).

- **اقتراح الإصلاح:** لا شيء مطلوب.
