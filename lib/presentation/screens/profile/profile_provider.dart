import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:makan/data/models/models.dart';
import 'package:makan/data/services/services.dart';

/// يجلب بيانات البروفايل الحالي (شامل is_owner / role / is_admin).
///
/// لماذا provider بدل تحميل محلي بـ initState؟ لأن شاشة "حسابي" غالبًا
/// تبقى محفوظة بالذاكرة ضمن التنقل السفلي (IndexedStack أو ما شابه)،
/// فـ initState ما بيعاد استدعاؤه لما يرجع المستخدم للتبويب. هيك، لو
/// صاحب شاليه ضاف شاليه وصار "مالك" فعليًا بقاعدة البيانات، شاشة
/// حسابه كانت تضل عارضة الحالة القديمة لحد ما يعيد فتح التطبيق بالكامل.
///
/// الحل: أي مكان بيغيّر دور المستخدم (مثلاً بعد `becomeOwner()`) ينادي
/// `ref.invalidate(profileProvider)`، فتتحدّث كل الشاشات اللي تراقب
/// هاد الـ provider فورًا — حتى لو كانت بالخلفية، بدون حاجة لإعادة
/// تشغيل التطبيق أو زيارة الشاشة يدويًا.
final profileProvider = FutureProvider<UserProfile?>((ref) async {
  return AuthService.instance.getCurrentProfile();
});

/// هل الحساب الحالي أدمن؟ مصدر واحد لإخفاء خيارات الزبون والمالك (المفضلة،
/// الحجوزات، الحجز، "أضف شاليهك"، وضع المالك) وإظهار هوية الإدارة. الأدمن
/// لا يحجز ولا يملك شاليهات (السيرفر يرفض ذلك أيضاً). false أثناء التحميل.
final isAdminProvider = Provider<bool>(
  (ref) => ref.watch(profileProvider).valueOrNull?.isAdmin ?? false,
);
