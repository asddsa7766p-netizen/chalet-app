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
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../../data/services/location_service.dart';

class ChaletDetailScreen extends ConsumerStatefulWidget {
  final String chaletId;
  final ChaletModel? chalet;
  const ChaletDetailScreen({super.key, required this.chaletId, this.chalet});

  @override
  ConsumerState<ChaletDetailScreen> createState() => _ChaletDetailScreenState();
}

class _ChaletDetailScreenState extends ConsumerState<ChaletDetailScreen> {
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
    } catch (_) {
      // فشل التقييمات لا يمنع عرض باقي بيانات الشاليه — تبقى القائمة فاضية
      // ويظهر "لا يوجد تقييمات بعد" بدل كسر الشاشة كاملة.
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

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            const Text('تعذر تحميل بيانات الشاليه',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal)),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () => context.pop(),
                  child:
                      const Text('رجوع', style: TextStyle(fontFamily: 'Cairo')),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  label: const Text('إعادة المحاولة',
                      style: TextStyle(fontFamily: 'Cairo')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Shimmer.fromColors(
        baseColor: AppColors.sand,
        highlightColor: Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 260,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 20,
                width: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 14,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 14,
                width: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: List.generate(
                  4,
                  (i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ إعادة تصميم: كانت بطاقة العنوان/التقييم وصف الإحصائيات (غرف/حمامات/
  // ضيوف) بطاقتين منفصلتين متلاصقتين بنفس الظل والزوايا — تكرار بصري بلا
  // فائدة أول ما يراه المستخدم بعد المعرض. الآن بطاقة واحدة متماسكة:
  // الشارة/التقييم، الاسم، الموقع، ثم فاصل خفيف، ثم صف الإحصائيات — نظرة
  // واحدة سريعة تلخّص الشاليه بدل تكديس بطاقات متطابقة الشكل.
  Widget _buildHeaderCard(ChaletModel chalet) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // تقييم بنمط الصورة: نجمة + رقم أعلى العنوان
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 20, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text(chalet.rating.toStringAsFixed(1),
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.charcoal)),
                    ],
                  ),
                  Text('(${chalet.reviewsCount} تقييم)',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: AppColors.textSecondary)),
                ],
              ),
              const Spacer(),
              if (chalet.isFeatured)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('مميز',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(chalet.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: AppColors.charcoal)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 15, color: AppColors.primary),
              const SizedBox(width: 4),
              Expanded(
                  child: Text('${chalet.city}، ${chalet.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: AppColors.textSecondary))),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 14),
          // ملاحظة: الموديل الحالي لا يحوي حقل مساحة (م²) أو نوع عقار،
          // فتم الاكتفاء بالحقول المتوفرة فعلياً بقاعدة البيانات.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _stat(Icons.bed_rounded, '${chalet.bedrooms}', 'غرف نوم'),
              _divider(),
              _stat(Icons.bathroom_rounded, '${chalet.bathrooms}', 'حمامات'),
              _divider(),
              _stat(Icons.people_alt_rounded, '${chalet.maxGuests}', 'ضيف'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: AppColors.primaryPale,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.charcoal)),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _divider() =>
      Container(height: 44, width: 1, color: AppColors.divider);

  Widget _buildLocationPreview(ChaletModel chalet) {
    final lat = chalet.latitude;
    final lng = chalet.longitude;

    if (lat == null || lng == null) return const SizedBox.shrink();

    final center = latlong2.LatLng(lat, lng);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            AppStrings.location,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
          ),
          if (chalet.address != null && chalet.address!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(chalet.address!,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: AppColors.textSecondary)),
          ],
          if (_userPosition != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.near_me_rounded,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'يبعد عنك ${LocationService.instance.distanceInKm(
                        lat1: _userPosition!.latitude,
                        lon1: _userPosition!.longitude,
                        lat2: lat,
                        lon2: lng,
                      ).toStringAsFixed(1)} كم',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 14,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'makan',
                    maxZoom: 19,
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: center,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.primary,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final url =
                    'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.directions_rounded, size: 18),
              label: const Text(
                'عرض على الخريطة',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // وصف قابل للتوسيع "عرض المزيد" — زي الصورة المرجعية بالضبط
  // ✅ إصلاح: كان يُعرض نص تسويقي عام مختلق عندما لا يكتب المالك وصفاً
  // فعلياً — يظهر كأنه وصف حقيقي للشاليه رغم أنه نفس النص لأي شاليه بلا
  // وصف. الآن القسم بأكمله يختفي بصدق بدل اختراع محتوى غير حقيقي.
  Widget _buildDescription(ChaletModel chalet) {
    final text = chalet.description.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('لمحة عن المكان',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal)),
          const SizedBox(height: 10),
          Text(text,
              maxLines: _descriptionExpanded ? null : 3,
              overflow: _descriptionExpanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.7)),
          if (text.length > 100)
            GestureDetector(
              onTap: () =>
                  setState(() => _descriptionExpanded = !_descriptionExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _descriptionExpanded ? 'عرض أقل' : 'عرض المزيد',
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // شبكة المرافق والخدمات — أيقونة دائرية بأعلى + تسمية أسفلها، زي الصورة
  Widget _buildAmenities(ChaletModel chalet) {
    final amenities = <Map<String, dynamic>>[
      {
        'icon': Icons.pool_rounded,
        'label': 'مسبح خاص',
        'available': chalet.hasPool
      },
      {
        'icon': Icons.wifi_rounded,
        'label': 'واي فاي',
        'available': chalet.hasWifi
      },
      {
        'icon': Icons.local_parking_rounded,
        'label': 'موقف سيارات',
        'available': chalet.hasParking
      },
      {
        'icon': Icons.outdoor_grill_rounded,
        'label': 'أدوات شواء',
        'available': chalet.hasBbq
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(AppStrings.amenities,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal)),
          const SizedBox(height: 14),
          // ✅ إعادة تصميم: شبكة أيقونة-فوق-تسمية بـ3 أعمدة كانت مصمّمة
          // أصلاً لـ6 عناصر (اثنان منها وهميان تم حذفهما — مطبخ/تكييف
          // بلا حقل حقيقي بقاعدة البيانات). مع 4 مرافق حقيقية فقط، شكل
          // "شريحة أفقية" بعمودين يعطي توازناً بصرياً أفضل من عمود ثالث
          // فيه عنصر واحد معلّق وحيد.
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: amenities.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.6,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (_, i) {
              final a = amenities[i];
              final available = a['available'] as bool;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: available ? AppColors.primaryPale : AppColors.sand,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(a['icon'] as IconData,
                        size: 20,
                        color:
                            available ? AppColors.primary : AppColors.textHint),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(a['label'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: available
                                  ? AppColors.charcoal
                                  : AppColors.textHint,
                              fontWeight: FontWeight.w600,
                              decoration: available
                                  ? null
                                  : TextDecoration.lineThrough)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSection(ChaletModel chalet) {
    final videoUrl = chalet.videoUrl;
    if (videoUrl == null || videoUrl.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final isYoutube = _isYoutubeUrl(videoUrl);

    Widget playerChild;

    if (isYoutube) {
      _initYoutubePlayer(videoUrl);

      if (_youtubeController == null) {
        playerChild = Container(
          color: AppColors.sand,
          child: const Center(
            child: Icon(Icons.error_outline_rounded,
                color: AppColors.textHint, size: 40),
          ),
        );
      } else {
        playerChild = YoutubePlayer(controller: _youtubeController!);
      }
    } else {
      if (_videoController == null ||
          _videoController!.dataSource != videoUrl) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _initVideoPlayer(videoUrl));
      }

      playerChild = _videoError
          ? Container(
              color: AppColors.sand,
              child: const Center(
                child: Icon(Icons.error_outline_rounded,
                    color: AppColors.textHint, size: 40),
              ),
            )
          : (_videoInitialized && _chewieController != null
              ? Chewie(controller: _chewieController!)
              : Container(
                  color: AppColors.sand,
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ));
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'فيديو الشاليه',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: playerChild,
            ),
          ),
        ],
      ),
    );
  }

  // تقييمات الضيوف — إضافة توزيع النجوم (5★...1★) زي الصورة المرجعية
  Widget _buildReviews() {
    // حساب توزيع التقييمات من قائمة المراجعات الفعلية
    final distribution = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in _reviews) {
      final rounded = r.rating.round().clamp(1, 5);
      distribution[rounded] = (distribution[rounded] ?? 0) + 1;
    }
    final maxCount = distribution.values.isEmpty
        ? 1
        : distribution.values.reduce((a, b) => a > b ? a : b).clamp(1, 999999);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(AppStrings.reviews,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal)),
              TextButton(
                onPressed: () {
                  if (!requireAuth(
                      context,
                      PendingAuthAction('open_reviews', {
                        'chaletId': widget.chaletId,
                        'chaletName': _chalet?.name ?? ''
                      }))) {
                    return;
                  }
                  context.push('/home/reviews/${widget.chaletId}',
                      extra: _chalet?.name);
                },
                child: const Text('عرض الكل',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_chalet != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Text(_chalet!.rating.toStringAsFixed(1),
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: AppColors.charcoal)),
                    Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                            5,
                            (i) => Icon(
                                i < _chalet!.rating.round()
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: AppColors.accent,
                                size: 16))),
                    Text('${_chalet!.reviewsCount} تقييم',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [5, 4, 3, 2, 1]
                        .map((star) =>
                            _ratingBar(star, distribution[star] ?? 0, maxCount))
                        .toList(),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 14),
          if (_reviews.isEmpty)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('لا يوجد تقييمات بعد',
                  style: TextStyle(
                      fontFamily: 'Cairo', color: AppColors.textHint)),
            ))
          else
            ...(_reviews.take(2).map((r) => _ReviewItem(review: r))),
        ],
      ),
    );
  }

  Widget _ratingBar(int star, int count, int maxCount) {
    final ratio = maxCount == 0 ? 0.0 : count / maxCount;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text('$star',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: AppColors.textSecondary)),
          const SizedBox(width: 4),
          const Icon(Icons.star_rounded, size: 12, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: AppColors.sand,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 18,
            child: Text('$count',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: AppColors.textSecondary)),
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
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final ReviewModel review;
  const _ReviewItem({required this.review});

  @override
  Widget build(BuildContext context) {
    // ✅ إصلاح: كان (review.userName ?? 'م').characters.first بيرمي
    // StateError لو userName نص فاضي '' (مو null) — بدون عنصر أول.
    final displayName =
        (review.userName != null && review.userName!.trim().isNotEmpty)
            ? review.userName!
            : 'مستخدم';
    final avatarLetter = displayName.characters.first;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryPale,
                backgroundImage: review.userAvatar != null
                    ? NetworkImage(review.userAvatar!)
                    : null,
                child: review.userAvatar == null
                    ? Text(avatarLetter,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    Text(_formatDate(review.createdAt),
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: AppColors.textHint)),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                    5,
                    (i) => Icon(
                        i < review.rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: AppColors.accent,
                        size: 14)),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.comment!,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.6)),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.divider),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ✅ إعادة تصميم: معرض صور بشاشة كاملة — خلفية سوداء غامرة، تكبير/تصغير
// بالقرص لكل صورة (InteractiveViewer) مع سحب أفقي للتنقل بين الصور
// (PageView)، وعدّاد أعلى الشاشة. مستقل تماماً عن كاروسيل الصفحة
// الرئيسية فما في أي تعارض إيماءات مع بقية الصفحة القابلة للتمرير.
class _FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenGallery({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.images[i],
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.home_work_rounded,
                    size: 60,
                    color: Colors.white38,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Material(
                      color: Colors.black45,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.of(context).pop(),
                        child: const SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(Icons.close_rounded,
                              color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                    if (widget.images.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${_index + 1}/${widget.images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
