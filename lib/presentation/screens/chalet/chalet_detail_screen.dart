import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/chalet_model.dart';
import '../../../data/models/models.dart';
import '../../../data/services/services.dart';
import '../../../data/providers/favorites_provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:url_launcher/url_launcher.dart';

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
  int _currentImage = 0;
  final _pageController = PageController();

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _videoInitialized = false;
  bool _videoError = false;

  bool _heartAnimating = false;

  @override
  void initState() {
    super.initState();
    _chalet = widget.chalet;
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ChaletService.instance.getChaletById(widget.chaletId),
        ReviewsService.instance.getChaletReviews(widget.chaletId),
      ]);

      if (mounted) {
        setState(() {
          _chalet = results[0] as ChaletModel? ?? _chalet;
          _reviews = results[1] as List<ReviewModel>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (widget.chalet == null) {
      return;
    }
    setState(() => _heartAnimating = true);
    await ref.read(favoritesProvider.notifier).toggleFavorite(widget.chalet!);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _heartAnimating = false);
    });
  }

  Future<void> _initVideoPlayer(String? videoUrl) async {
    if (videoUrl == null || videoUrl.trim().isEmpty) {
      _videoInitialized = false;
      return;
    }
    if (_videoController != null && _videoController!.dataSource == videoUrl) {
      return;
    }

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
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chalet == null && _loading) {
      return _buildSkeletonLoader();
    }
    if (_chalet == null) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    final chalet = _chalet!;
    // ملاحظة: مصدر الخطأ الوحيد في الملف الأصلي — chalet.mainImage غير موجود
    // في ChaletModel الحالي؛ تم استبداله بـ chalet.coverImage (السلوك مطابق:
    // يرجع أول صورة، أو نص فارغ إذا لا توجد صور).
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
                expandedHeight: 300,
                pinned: true,
                backgroundColor: AppColors.primary,
                leading: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_rounded,
                        color: AppColors.charcoal, size: 18),
                  ),
                ),
                actions: [
                  GestureDetector(
                    onTap: _toggleFavorite,
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
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
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    children: [
                      InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 3.0,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: images.length,
                          onPageChanged: (i) =>
                              setState(() => _currentImage = i),
                          itemBuilder: (_, i) => CachedNetworkImage(
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
                                      ? AppColors.accent
                                      : Colors.white.withOpacity(0.5),
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
                                Colors.black.withOpacity(0.4),
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
                      const SizedBox(height: 12),
                      _buildStatsRow(chalet),
                      const SizedBox(height: 12),
                      _buildDescription(chalet),
                      const SizedBox(height: 12),
                      _buildAmenities(chalet),
                      const SizedBox(height: 12),
                      if (chalet.videoUrl != null &&
                          chalet.videoUrl!.isNotEmpty) ...[
                        _buildVideoSection(chalet),
                        const SizedBox(height: 12),
                      ],
                      _buildLocationPreview(chalet),
                      const SizedBox(height: 12),
                      _buildReviews(),
                      const SizedBox(height: 100),
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

  Widget _buildHeaderCard(ChaletModel chalet) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(chalet.name,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.charcoal)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryPale.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(chalet.city,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 15, color: AppColors.primary),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(chalet.location,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: AppColors.textSecondary))),
            ],
          ),
          const SizedBox(height: 10),

          // Luxury badges
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _luxuryBadge(Icons.verified_rounded, 'VIP', AppColors.accent),
              if (chalet.hasPool)
                _luxuryBadge(
                    Icons.whatshot_rounded, 'مسبح مدفأ', Colors.deepOrange),
              _luxuryBadge(
                  Icons.landscape_rounded, 'إطلالة جبلية', Colors.teal),
              if (chalet.hasBbq)
                _luxuryBadge(Icons.outdoor_grill_rounded, 'شواء', Colors.brown),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              const Icon(Icons.star_rounded, size: 18, color: AppColors.accent),
              const SizedBox(width: 4),
              Text(chalet.rating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal)),
              Text(' (${chalet.reviewsCount} تقييم)',
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: AppColors.textSecondary)),
              const Spacer(),
              RichText(
                text: const TextSpan(children: [
                  TextSpan(
                      text: 'يبدأ من ',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                ]),
              ),
              RichText(
                text: TextSpan(children: [
                  TextSpan(
                      text: AppCurrency.formatPrice(chalet.pricePerNight),
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary)),
                  const TextSpan(
                      text: '/ليلة',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _luxuryBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }

  Widget _buildStatsRow(ChaletModel chalet) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _stat(Icons.bed_rounded, '${chalet.bedrooms}', 'غرف نوم'),
          _divider(),
          _stat(Icons.bathroom_rounded, '${chalet.bathrooms}', 'حمامات'),
          _divider(),
          _stat(Icons.people_rounded, '${chalet.maxGuests}', 'ضيف'),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
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
      Container(height: 40, width: 1, color: AppColors.divider);

  Widget _buildLocationPreview(ChaletModel chalet) {
    final lat = chalet.latitude;
    final lng = chalet.longitude;

    if (lat == null || lng == null) return const SizedBox.shrink();

    final center = latlong2.LatLng(lat, lng);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
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
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
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
                    userAgentPackageName: 'friends_chalets',
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
                          color: Color(0xFF0D5BAE),
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final url =
                    'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.directions),
              label: const Text(
                'Get Directions',
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

  Widget _buildDescription(ChaletModel chalet) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('وصف الشاليه',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal)),
          const SizedBox(height: 10),
          Text(
              chalet.description.isNotEmpty
                  ? chalet.description
                  : 'شاليه فاخر بإطلالة خلابة على الطبيعة، يوفر لك الراحة والخصوصية التامة بعيداً عن صخب المدينة. مجهز بالكامل بكل ما تحتاجه لقضاء إجازة مثالية مع عائلتك وأصدقائك.',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.7)),
        ],
      ),
    );
  }

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
        'icon': Icons.outdoor_grill_rounded,
        'label': 'منطقة شواء',
        'available': chalet.hasBbq
      },
      {
        'icon': Icons.local_parking_rounded,
        'label': 'مواقف سيارات',
        'available': chalet.hasParking
      },
      {'icon': Icons.ac_unit_rounded, 'label': 'تكييف', 'available': true},
      {'icon': Icons.kitchen_rounded, 'label': 'مطبخ', 'available': true},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
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
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: amenities.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.8,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (_, i) {
              final a = amenities[i];
              final available = a['available'] as bool;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: available
                      ? AppColors.primaryPale.withOpacity(0.4)
                      : AppColors.cream,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color:
                          available ? AppColors.primaryPale : AppColors.sand),
                ),
                child: Row(
                  children: [
                    Icon(a['icon'] as IconData,
                        size: 15,
                        color:
                            available ? AppColors.primary : AppColors.textHint),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(a['label'] as String,
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 10,
                              color: available
                                  ? AppColors.primary
                                  : AppColors.textHint,
                              fontWeight: available
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              decoration: available
                                  ? null
                                  : TextDecoration.lineThrough),
                          overflow: TextOverflow.ellipsis),
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

    if (_videoController == null || _videoController!.dataSource != videoUrl) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _initVideoPlayer(videoUrl));
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
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
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _videoError
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
                            child: CircularProgressIndicator(
                                color: AppColors.primary),
                          ),
                        )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviews() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
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
                onPressed: () => context.push(
                    '/home/reviews/${widget.chaletId}',
                    extra: _chalet?.name),
                child: const Text('عرض الكل',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (_chalet != null) ...[
            Row(
              children: [
                Text(_chalet!.rating.toStringAsFixed(1),
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: AppColors.charcoal)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        children: List.generate(
                            5,
                            (i) => Icon(
                                i < _chalet!.rating.round()
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: AppColors.accent,
                                size: 20))),
                    Text('${_chalet!.reviewsCount} تقييم',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
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

  Widget _buildBottomBar(ChaletModel chalet) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('السعر لليلة',
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
              onPressed: () => context.push('/home/booking', extra: chalet),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 50),
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
                    ? Text((review.userName ?? 'م').characters.first,
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
                    Text(review.userName ?? 'مستخدم',
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
          const Divider(height: 1),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
