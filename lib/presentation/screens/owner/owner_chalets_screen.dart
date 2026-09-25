import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/services/services.dart';
import '../../../data/services/notification_service.dart';
import 'owner_add_chalet_screen.dart';
import 'owner_edit_chalet_screen.dart';
import 'chalet_pricing_screen.dart';
import 'owner_bottom_nav.dart';

/// شاشة "شاليهاتي".
///
/// ⚠️ تم إعادة كتابة هذه الشاشة بالكامل. النسخة السابقة كانت:
/// 1) تعرض شاليهين ثابتين مكتوبين يدويًا في الكود (hardcoded) بغض النظر عن
///    شاليهات المالك الحقيقية في قاعدة البيانات — أي أنها لم تكن تعمل
///    فعليًا كشاشة "شاليهاتي" إطلاقًا.
/// 2) تحتوي على خطأ layout حقيقي (`OutlinedButton` بداخل `Row` بدون
///    `Expanded`/عرض محدد) كان يتسبب بانهيار الشاشة بالكامل عند العرض
///    (BoxConstraints forces an infinite width).
///
/// زر "تعديل" يفتح OwnerEditChaletScreen (شاشة تعديل مستقلة تتحقق من ملكية
/// الشاليه بنفسها). زر "الأسعار" يفتح ChaletPricingScreen لإدارة تسعير
/// الشاليه (سعر يوم الأسبوع + سعر تاريخ محدد).
class OwnerChaletsScreen extends StatefulWidget {
  const OwnerChaletsScreen({super.key});

  @override
  State<OwnerChaletsScreen> createState() => _OwnerChaletsScreenState();
}

class _OwnerChaletsScreenState extends State<OwnerChaletsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _chalets = [];
  // ✅ إصلاح: نفس نمط تحميل unreadCount المستخدم في owner_dashboard_screen.dart
  // (Problem #2)، حتى تعرض شارة الإشعارات في OwnerBottomNav هنا العدد
  // الحقيقي بدل الاعتماد على القيمة الافتراضية صفر.
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final ownerId = AuthService.instance.currentUser?.id;
    if (ownerId == null) {
      setState(() {
        _loading = false;
        _error = 'لا يوجد مستخدم مسجل دخول حاليًا';
      });
      return;
    }

    try {
      // الشاليهات هي الطلب الأساسي؛ عدّاد الإشعارات ثانوي ولا يُسقط القائمة
      // إن فشل (نفس نمط _init() بـ owner_calendar_screen.dart).
      final chalets = await ChaletService.instance.getOwnerChalets(ownerId);
      final unread = await NotificationService.instance
          .getUnreadCount()
          .catchError((_) => _unreadCount);

      if (!mounted) return;
      setState(() {
        _chalets = chalets;
        _unreadCount = unread;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل الشاليهات، حاول مرة أخرى';
      });
    }
  }

  /// فتح شاشة تعديل الشاليه. تُمرَّر معرّفه فقط؛ الشاشة تجلب الصف وتتحقق أنه
  /// للمستخدم الحالي. بعد الرجوع تُعاد القائمة لتعكس الاسم/الصورة/الحالة.
  Future<void> _goToEdit(Map<String, dynamic> chalet) async {
    final id = chalet['id'] as String;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OwnerEditChaletScreen(chaletId: id)),
    );
    if (mounted) _load();
  }

  Future<void> _goToAddChalet() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OwnerAddChaletScreen()),
    );
    // إعادة تحميل القائمة بعد الرجوع من شاشة الإضافة، لأن شاليهًا جديدًا قد
    // يكون أُضيف. كانت النسخة السابقة لا تحدّث القائمة أبدًا (وهذا كان غير
    // ملحوظ لأن القائمة كانت ثابتة على أي حال).
    if (mounted) _load();
  }

  /// ✅ جديد: فتح شاشة إدارة الأسعار لشاليه معيّن، مع تمرير الحقول المطلوبة.
  Future<void> _goToPricing(Map<String, dynamic> chalet) async {
    final id = chalet['id'] as String;
    final name = (chalet['name'] as String?)?.trim().isNotEmpty == true
        ? chalet['name'] as String
        : 'بدون اسم';
    final defaultPrice = (chalet['price_per_night'] as num?)?.toDouble() ?? 0;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChaletPricingScreen(
          chaletId: id,
          chaletName: name,
          defaultPricePerNight: defaultPrice,
        ),
      ),
    );
    // إعادة تحميل القائمة بعد الرجوع، احتياطًا لو تم تعديل السعر الافتراضي
    // من داخل شاشة إدارة الأسعار مستقبلًا.
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'شاليهاتي',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 92),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'شاليهاتي',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'إدارة شاليهاتك، توفرها، وأسعارها من مكان واحد.',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: _goToAddChalet,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text(
                                'إضافة شاليه جديد',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_error != null)
                            _buildErrorState()
                          else if (_chalets.isEmpty)
                            _buildEmptyState()
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _chalets.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                // تمت زيادة childAspectRatio بدل تثبيت ارتفاع
                                // صغير، لإعطاء البطاقة مساحة كافية بحيث لا
                                // تنكسر عناصرها الداخلية. تم تصغيره قليلًا
                                // (0.78 → 0.72) لاستيعاب زرَّين بدل زر واحد
                                // في أسفل البطاقة (تعديل + الأسعار).
                                childAspectRatio: 0.72,
                              ),
                              itemBuilder: (_, i) => _ChaletCard(
                                chalet: _chalets[i],
                                onEditPressed: () => _goToEdit(_chalets[i]),
                                onManagePricesPressed: () =>
                                    _goToPricing(_chalets[i]),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToAddChalet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'إضافة',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
        ),
      ),
      // ✅ إصلاح: هذه الشاشة كانت بلا أي طريقة مرئية للرجوع (تُفتح عبر
      // context.go من لوحة التحكم، فلا يوجد Route سابق لـ Navigator
      // ليعرض سهم رجوع تلقائي بالـ AppBar). إضافة الشريط السفلي
      // المشترك تعطي طريقًا واضحًا دائمًا للتنقّل بدل شاشة بلا مخرج.
      bottomNavigationBar: OwnerBottomNav(
        currentRoute: '/owner-chalets',
        unreadCount: _unreadCount,
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(
            _error ?? 'حدث خطأ',
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _load,
            child: const Text('إعادة المحاولة',
                style:
                    TextStyle(fontFamily: 'Cairo', color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.home_work_outlined, size: 56, color: AppColors.textMuted),
          SizedBox(height: 14),
          Text(
            'لا توجد شاليهات بعد',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary),
          ),
          SizedBox(height: 6),
          Text(
            'اضغط "إضافة شاليه جديد" لإضافة أول شاليه لك',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ChaletCard extends StatelessWidget {
  final Map<String, dynamic> chalet;
  final VoidCallback onEditPressed;
  final VoidCallback onManagePricesPressed;

  const _ChaletCard({
    required this.chalet,
    required this.onEditPressed,
    required this.onManagePricesPressed,
  });

  @override
  Widget build(BuildContext context) {
    final name = (chalet['name'] as String?)?.trim().isNotEmpty == true
        ? chalet['name'] as String
        : 'بدون اسم';
    final city = chalet['city'] as String? ?? '';
    final location = chalet['location'] as String? ?? '';
    final displayLocation =
        [city, location].where((s) => s.isNotEmpty).join('، ');
    final price = (chalet['price_per_night'] as num?)?.toDouble() ?? 0;
    final isAvailable = chalet['is_available'] as bool? ?? false;
    final isApproved = chalet['is_approved'] as bool? ?? false;
    final images = (chalet['images'] as List?)?.cast<String>() ?? [];
    final coverImage = images.isNotEmpty ? images.first : null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 110,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (coverImage != null)
                  Image.network(
                    coverImage,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      child: const Icon(Icons.home_work_rounded,
                          color: AppColors.primary, size: 40),
                    ),
                  )
                else
                  Container(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    child: const Icon(Icons.home_work_rounded,
                        color: AppColors.primary, size: 40),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: (isAvailable && isApproved
                                  ? AppColors.primary
                                  : AppColors.textMuted)
                              .withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isAvailable && isApproved
                                ? AppColors.primary
                                : AppColors.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          !isApproved
                              ? 'بانتظار الموافقة'
                              : (isAvailable ? 'متاح' : 'غير متاح'),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isAvailable && isApproved
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (displayLocation.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 13, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                displayLocation,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        'يبدأ من ₪${price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  // ✅ جديد: زرّان بدل زر واحد — "تعديل" و"الأسعار" — كل واحد
                  // بعرض متساوٍ (Expanded داخل Row) لتفادي مشكلة
                  // BoxConstraints forces an infinite width القديمة.
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onEditPressed,
                          icon: const Icon(Icons.edit_rounded, size: 15),
                          label: const Text(
                            'تعديل',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(
                                color: AppColors.primary.withValues(alpha: 0.7)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onManagePricesPressed,
                          icon: const Icon(Icons.sell_rounded, size: 15),
                          label: const Text(
                            'الأسعار',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
