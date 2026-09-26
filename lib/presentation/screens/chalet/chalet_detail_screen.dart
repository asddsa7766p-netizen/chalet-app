import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/chalet_model.dart';
import '../../../data/models/models.dart';
import '../../../data/services/services.dart';
import '../../../data/providers/favorites_provider.dart';
import '../../widgets/common/login_prompt.dart';
import '../profile/profile_provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../../data/services/location_service.dart';
import '../../../core/utils/error_reporter.dart';

part 'widgets/chalet_detail_header.dart';
part 'widgets/chalet_detail_sections.dart';
part 'widgets/chalet_reviews_section.dart';
part 'widgets/review_item.dart';
part 'widgets/full_screen_gallery.dart';

class ChaletDetailScreen extends ConsumerStatefulWidget {
  final String chaletId;
  final ChaletModel? chalet;
  const ChaletDetailScreen({super.key, required this.chaletId, this.chalet});

  @override
  ConsumerState<ChaletDetailScreen> createState() => _ChaletDetailScreenState();
}

class _ChaletDetailScreenState extends ConsumerState<ChaletDetailScreen> {
  // لأجزاء الشاشة (extensions بملفات part) التي لا تستطيع استدعاء
  // setState المحمي مباشرة.
  void _setState(VoidCallback fn) => setState(fn);

  ChaletModel? _chalet;
  List<ReviewModel> _reviews = [];

  bool _loading = true;
  // ✅ إصلاح: نفرّق بين فشل تحميل الشاليه نفسه (خطأ حقيقي يحتاج إعادة
  // محاولة) وفشل التقييمات (ثانوي، لا يجب أن يمنع عرض الشاليه أصلاً).
  bool _chaletLoadError = false;
  int _currentImage = 0;
  final _pageController = PageController();

  // وصف قابل للتوسيع "عرض المزيد" — زي الصورة المرجعية
  bool _descriptionExpanded = false;

  // مشغّل يوتيوب (لروابط youtube.com / youtu.be / shorts)
  YoutubePlayerController? _youtubeController;
  String? _youtubeVideoUrl;

  // مشغّل الفيديو المباشر (mp4 وغيره) — يُستخدم فقط إذا الرابط ليس يوتيوب
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _videoInitialized = false;
  bool _videoError = false;
  // ✅ إصلاح: منع استدعاءات متزامنة متعددة لـ _initVideoPlayer (كانت
  // ممكن تصير كل ما تُعاد بناء الشاشة قبل ما يخلص أول تهيئة، وينتج عنها
  // تعارض على نفس الـ controller أو استهلاك شبكة مضاعف).
  bool _videoInitializing = false;

  bool _heartAnimating = false;
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _chalet = widget.chalet;
    _load();
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (mounted && pos != null) {
      setState(() => _userPosition = pos);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _chewieController?.dispose();
    _videoController?.dispose();
    _youtubeController?.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _chaletLoadError = false;
    });

    // ✅ إصلاح: كان استخدام Future.wait يربط فشل تحميل التقييمات بفشل
    // تحميل الشاليه نفسه (Future.wait بيفشل بالكامل أول ما أي Future
    // جواه يفشل)، فلو صار خطأ بجلب التقييمات بس، الشاليه كان يختفي
    // بالكامل رغم نجاح تحميله فعلياً. الحل: تحميل مستقل لكل واحد.
    ChaletModel? chalet;
    var chaletFailed = false;
    try {
      chalet = await ChaletService.instance.getChaletById(widget.chaletId);
    } catch (_) {
      chaletFailed = true;
    }

    List<ReviewModel> reviews = [];
    try {
      reviews = await ReviewsService.instance.getChaletReviews(widget.chaletId);
    } catch (e, st) {
      // فشل التقييمات لا يمنع عرض باقي بيانات الشاليه — تبقى القائمة فاضية
      // ويظهر "لا يوجد تقييمات بعد" بدل كسر الشاشة كاملة.
      reportError(e, st, context: 'chalet_detail.reviews');
    }

    if (!mounted) return;
    setState(() {
      _chalet = chalet ?? _chalet;
      _reviews = reviews;
      _loading = false;
      // ✅ إصلاح: خطأ فعلي بس إذا فشل تحميل الشاليه ومافي أي بيانات
      // بديلة (لا widget.chalet ولا نتيجة سابقة) — عشان نعرض شاشة خطأ
      // بزر إعادة محاولة بدل مؤشر تحميل بيدور للأبد.
      _chaletLoadError = chaletFailed && _chalet == null;
    });
  }

  Future<void> _toggleFavorite() async {
    if (_chalet == null) return;
    if (!requireAuth(context,
        PendingAuthAction('toggle_favorite', {'chaletId': _chalet!.id}))) {
      return;
    }
    setState(() => _heartAnimating = true);
    try {
      await ref.read(favoritesProvider.notifier).toggleFavorite(_chalet!);
    } catch (_) {
      // ✅ إصلاح: كان فشل تبديل المفضلة يمر بصمت والمستخدم يشوف تأثير
      // حركي وكأنها نجحت رغم فشلها فعلياً بالسيرفر.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر تحديث المفضلة، حاول مرة أخرى',
              style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _heartAnimating = false);
    });
  }

  // ✅ إعادة تصميم: معرض صور غامر بشاشة كاملة (خلفية سوداء + تكبير
  // بالقرص لكل صورة + عدّاد) يُفتح بالضغط على أي صورة — بدل الاكتفاء
  // بكاروسيل صغير أعلى الصفحة فقط. يبدأ من الصورة المعروضة حالياً.
  void _openFullScreenGallery(List<String> images) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullScreenGallery(
          images: images,
          initialIndex: _currentImage,
        ),
      ),
    );
  }

  /// مشاركة رابط/تفاصيل الشاليه.
  /// ⚠️ هاي نسخة مبسطة عبر واتساب (نفس الأسلوب المستخدم بشاشة الحجز)
  /// حتى ما نضيف اعتمادية جديدة (share_plus). إذا عندكم الحزمة مضافة
  /// أصلاً بالمشروع، الأفضل استبدالها بـ Share.share() لفتح قائمة
  /// المشاركة الأصلية للنظام بدل تحديد واتساب فقط.
  Future<void> _shareChalet(ChaletModel chalet) async {
    final text = Uri.encodeComponent(
      'شاهد هذا الشاليه: ${chalet.name}\n'
      '${AppStrings.priceFrom} ${AppCurrency.formatPrice(chalet.pricePerNight)}\n'
      '${chalet.city}',
    );
    final uri = Uri.parse('https://wa.me/?text=$text');
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('تعذرت المشاركة', style: TextStyle(fontFamily: 'Cairo')),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('تعذرت المشاركة', style: TextStyle(fontFamily: 'Cairo')),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  /// يتحقق إذا كان الرابط رابط يوتيوب (watch / shorts / youtu.be / embed)
  bool _isYoutubeUrl(String url) {
    return YoutubePlayerController.convertUrlToId(url) != null;
  }

  void _initYoutubePlayer(String videoUrl) {
    if (_youtubeVideoUrl == videoUrl && _youtubeController != null) return;

    final videoId = YoutubePlayerController.convertUrlToId(videoUrl);
    if (videoId == null) return;

    _youtubeController?.close();
    _youtubeController = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        showControls: true,
        strictRelatedVideos: true,
      ),
    );
    _youtubeVideoUrl = videoUrl;
  }

  Future<void> _initVideoPlayer(String? videoUrl) async {
    if (videoUrl == null || videoUrl.trim().isEmpty) {
      _videoInitialized = false;
      return;
    }
    if (_videoController != null && _videoController!.dataSource == videoUrl) {
      return;
    }
    // ✅ إصلاح: بدون هاد الحارس، كل إعادة بناء للشاشة (مثلاً بسبب
    // setState من تبديل المفضلة) قبل ما تخلص تهيئة الفيديو الأولى كانت
    // تجدول استدعاء جديد لـ _initVideoPlayer عبر addPostFrameCallback،
    // فيصير أكتر من controller يتنافسوا على نفس المصدر ويعملوا dispose
    // لبعض وهم لسا قيد الإنشاء.
    if (_videoInitializing) return;
    _videoInitializing = true;

    try {
      _chewieController?.dispose();
      _videoController?.dispose();
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: true,
        showControls: true,
        aspectRatio: _videoController!.value.aspectRatio == 0
            ? 16 / 9
            : _videoController!.value.aspectRatio,
        placeholder: Container(
          color: AppColors.sand,
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Container(
            color: AppColors.sand,
            child: const Center(
              child: Icon(Icons.error_outline_rounded,
                  color: AppColors.textHint, size: 40),
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _videoInitialized = true;
          _videoError = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _videoInitialized = false;
          _videoError = true;
        });
      }
    } finally {
      _videoInitializing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chalet == null && _loading) {
      return _buildSkeletonLoader();
    }
    // ✅ إصلاح: سابقاً، لو فشل التحميل (loading=false) وبقي _chalet فاضي،
    // كانت الشاشة تعرض CircularProgressIndicator للأبد بدون أي رسالة
    // خطأ أو زر إعادة محاولة — يعني المستخدم يضل عالق بمؤشر تحميل كاذب.
    if (_chalet == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: _chaletLoadError
              ? _buildLoadError()
              : const Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      );
    }
    final chalet = _chalet!;
    final images =
        chalet.images.isNotEmpty ? chalet.images : [chalet.coverImage];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Image Gallery AppBar
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                backgroundColor: AppColors.primary,
                leading: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    margin: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 8,
                            offset: Offset(0, 2))
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_ios_rounded,
                        color: AppColors.charcoal, size: 18),
                  ),
                ),
                actions: [
                  // الأدمن لا يستخدم المفضلة (ولا يحجز): القلب مخفي عنه.
                  if (!ref.watch(isAdminProvider))
                  GestureDetector(
                    onTap: _toggleFavorite,
                    child: Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.all(9),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 8,
                              offset: Offset(0, 2))
                        ],
                      ),
                      child: AnimatedScale(
                        scale: _heartAnimating ? 1.35 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: Icon(
                          ref.watch(isFavoriteProvider(widget.chaletId))
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: ref.watch(isFavoriteProvider(widget.chaletId))
                              ? AppColors.error
                              : AppColors.charcoal,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  // ✅ إصلاح: زر المشاركة كان بدون أي onTap إطلاقاً — يعني
                  // زر ميت بصرياً، المستخدم يضغطه ولا يصير أي شي.
                  GestureDetector(
                    onTap: () => _shareChalet(chalet),
                    child: Container(
                      margin: const EdgeInsets.only(
                          right: 10, left: 10, top: 10, bottom: 10),
                      padding: const EdgeInsets.all(9),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 8,
                              offset: Offset(0, 2))
                        ],
                      ),
                      child: const Icon(Icons.ios_share_rounded,
                          color: AppColors.charcoal, size: 18),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    children: [
                      // ✅ إصلاح: كان الـ PageView (سحب أفقي للتنقل بين
                      // الصور) ملفوف بـ InteractiveViewer (تكبير بالقرص).
                      // Flutter بتتعارض فيها إيماءات السحب الأفقي مع
                      // إيماءات InteractiveViewer، فيصير التنقل بين
                      // الصور متردد/غير سلس. شلت InteractiveViewer من
                      // هون؛ التكبير بالقرص مبني كـ viewer منفصل بشاشة
                      // كاملة (_FullScreenGallery) يُفتح بالضغط على الصورة
                      // بدل ما يكون مفعّلاً فوق الكاروسيل نفسه.
                      PageView.builder(
                        controller: _pageController,
                        itemCount: images.length,
                        onPageChanged: (i) => setState(() => _currentImage = i),
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => _openFullScreenGallery(images),
                          child: CachedNetworkImage(
                            imageUrl: images[i],
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: AppColors.sand),
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.sand,
                              child: const Icon(Icons.home_work_rounded,
                                  size: 60, color: AppColors.textHint),
                            ),
                          ),
                        ),
                      ),

                      // Image counter (e.g. 1/12)
                      if (images.length > 1)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_currentImage + 1}/${images.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                        ),

                      // Image counter dots
                      if (images.length > 1)
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              images.length,
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                width: _currentImage == i ? 20 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _currentImage == i
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Overlay gradient
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.4),
                                Colors.transparent
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.background,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderCard(chalet),
                      const SizedBox(height: 14),
                      _buildDescription(chalet),
                      const SizedBox(height: 14),
                      _buildAmenities(chalet),
                      const SizedBox(height: 14),
                      if (chalet.videoUrl != null &&
                          chalet.videoUrl!.isNotEmpty) ...[
                        _buildVideoSection(chalet),
                        const SizedBox(height: 14),
                      ],
                      _buildLocationPreview(chalet),
                      const SizedBox(height: 14),
                      // TODO: قسم "أماكن مشابهة" زي الصورة المرجعية يحتاج
                      // دالة جديدة بالسيرفس مثلاً:
                      // ChaletService.instance.getSimilarChalets(chalet.city, excludeId: chalet.id)
                      // لما تضيفها بالباك اند، خبرني وبربطها هون بنفس تصميم
                      // الكاردز الموجودة بصفحة الاستكشاف.
                      _buildReviews(),
                      const SizedBox(height: 110),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(chalet),
          ),
        ],
      ),
    );
  }

  // الشريط السفلي الثابت — السعر + زر "احجز الآن" هو الإجراء الرئيسي
  // الوحيد بالصفحة، بلا أزرار ثانوية تنافسه على الانتباه.
  Widget _buildBottomBar(ChaletModel chalet) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      // ✅ إصلاح: زر "تواصل مع المضيف" أُزيل هنا — كان onTap يحمل TODO فاضٍ
      // فعلياً (لا ينفّذ شيئاً)، ولا يوجد بالـbackend حالياً أي طريقة آمنة
      // لعرض رقم/بيانات تواصل المالك لعميل لم يحجز بعد (لا حقل owner
      // phone على ChaletModel، ولا RPC عام لذلك — الاستعلام الوحيد الذي
      // يُرجع هاتف عبر profiles هو getIncomingBookings، وهو خاص بالمالك
      // نفسه على حجوزاته). عرض الزر فعّالاً بلا وظيفة كان مضلّلاً؛
      // حذفه أفضل من زر معطّل دائم حتى تقرروا شكل ميزة التواصل المطلوبة.
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(AppStrings.priceFrom,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: AppColors.textSecondary)),
              Text(AppCurrency.formatPrice(chalet.pricePerNight),
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary)),
            ],
          ),
          // الأدمن لا يحجز (السيرفر يرفض أيضاً): يبقى السعر فقط بلا "احجز الآن".
          if (!ref.watch(isAdminProvider)) ...[
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                if (!requireAuth(
                    context,
                    PendingAuthAction(
                        'open_booking', {'chaletId': chalet.id}))) {
                  return;
                }
                context.push('/home/booking', extra: {'chaletId': chalet.id});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(AppStrings.bookNow,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          ],
        ],
      ),
    );
  }
}
