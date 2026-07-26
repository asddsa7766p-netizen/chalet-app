import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  Widget _sectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sand, width: 1),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _bullets(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '•',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      e,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        height: 1.6,
                        color: AppColors.charcoal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('عن التطبيق'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon header (green + gold)
              Container(
                height: 110,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppColors.accent, width: 1),
                        ),
                      ),
                      const Icon(
                        Icons.home_work_rounded,
                        size: 56,
                        color: AppColors.white,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Title
              const Text(
                'شاليهات الأصدقاء',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),

              const Text(
                'في عالم يتسارع فيه نمط الحياة، نؤمن بأن لحظات الاسترخاء والاجتماع بالأحبة هي أثمن ما نملك. انطلق تطبيق "شاليهات الأصدقاء" ليكون المنصة الرائدة والأولى في فلسطين التي تجمع لك أرقى وأفخم الشاليهات وأماكن الاستجمام في مكان واحد. نحن هنا لنمنحك تجربة حجز سلسة، آمنة، وممتعة، تليق بأوقاتك الخاصة.',
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  height: 1.8,
                  color: AppColors.charcoal,
                ),
              ),

              const SizedBox(height: 14),

              _sectionCard(
                title: 'من نحن؟',
                child: const Text(
                  'شاليهات الأصدقاء ليس مجرد منصة حجز عادية، بل هو بوابتك الشخصية للهروب من ضغوط العمل وصخب الحياة اليومية إلى واحات من الراحة والخصوصية. سواء كنت تبحث عن ملاذ هادئ لعائلتك، أو مكان مميز للاحتفال والمرح مع أصدقائك، فإننا نوفر لك خيارات متنوعة تم اختيارها بعناية فائقة لتلبي أعلى معايير الفخامة والرفاهية في مختلف مناطق فلسطين.',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    height: 1.8,
                    color: AppColors.charcoal,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              _sectionCard(
                title: 'لماذا تختار شاليهات الأصدقاء؟',
                child: _bullets([
                  'تنوع وخيارات فاخرة: تجمع لك نخبة من أفضل الشاليهات التي تتميز بتصاميمها العصرية ومرافقها المتكاملة مثل المسابح والجلسات الخارجية الساحرة.',
                  'تصفح ذكي وسلس: واجهة مستخدم مريحة ومصممة بأحدث التقنيات تتيح لك استكشاف الشاليهات ومشاهدة صور عالية الجودة ومعرفة كافة التفاصيل والخدمات المتاحة بسهولة.',
                  'حجز فوري وآمن: يمكنك التحقق من التوفر وحجز شاليهك المفضل بكل سهولة وأمان تام.',
                  'شفافية ومصداقية: معلومات دقيقة وأسعار واضحة بدون رسوم مخفية وتقييمات حقيقية تساعدك على اختيار المكان المثالي.',
                ]),
              ),

              const SizedBox(height: 12),

              _sectionCard(
                title: 'الرسالة الختامية',
                child: const Text(
                  'صنعنا هذا التطبيق ليكون رفيقك في التخطيط لأجمل ذكرياتك.\nمع شاليهات الأصدقاء... راحتك واستجمامك يبدآن من هنا.',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    height: 1.8,
                    color: AppColors.charcoal,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.sand),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'الإصدار 1.0.0',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHint,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '© 2026 شاليهات الأصدقاء',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
