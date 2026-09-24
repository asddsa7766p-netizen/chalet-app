import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/reel_model.dart';
import '../../../data/services/reels_service.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key, this.fetchReels});

  /// Injectable for tests; defaults to [ReelsService.instance.fetchReels].
  @visibleForTesting
  final Future<List<ReelModel>> Function()? fetchReels;

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> with WidgetsBindingObserver {
  // أقصى عدد مشغّلات فيديو حية بنفس اللحظة: الحالي + واحد قبله + واحد بعده.
  static const _windowRadius = 1;

  final _pageController = PageController();
  final _chewieControllers = <int, ChewieController>{};
  final _videoControllers = <int, VideoPlayerController>{};

  List<ReelModel> _reels = [];
  bool _loading = true;
  String? _error;

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.removeListener(_onPageChanged);
    for (final c in _chewieControllers.values) {
      c.dispose();
    }
    for (final v in _videoControllers.values) {
      v.dispose();
    }
    _chewieControllers.clear();
    _videoControllers.clear();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _pauseAll();
        break;
      case AppLifecycleState.resumed:
        _togglePlaybackForVisibleIndex();
        break;
    }
  }

  void _onPageChanged() {
    final idx = _pageController.page?.round() ?? 0;
    if (idx == _currentIndex) return;
    setState(() => _currentIndex = idx);
    _togglePlaybackForVisibleIndex();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final fetch = widget.fetchReels ?? ReelsService.instance.fetchReels;
      final reels = await fetch();
      if (!mounted) return;
      setState(() {
        _reels = reels;
        _loading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _togglePlaybackForVisibleIndex();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل الفيديوهات، يرجى المحاولة لاحقاً';
        _loading = false;
      });
    }
  }

  void _ensureControllerForIndex(int index) {
    if (index < 0 || index >= _reels.length) return;
    if (_videoControllers.containsKey(index)) return;

    final reel = _reels[index];

    final videoController = VideoPlayerController.networkUrl(
      Uri.parse(reel.videoUrl),
    );

    final chewieController = ChewieController(
      videoPlayerController: videoController,
      autoPlay: false,
      looping: true,
      allowMuting: false,
      showControls: false,
      placeholder: Container(
        color: AppColors.sand,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
    );

    _videoControllers[index] = videoController;
    _chewieControllers[index] = chewieController;

    // Start loading asynchronously.
    unawaited(videoController.initialize());
  }

  /// فهارس النافذة المسموح ببقاء مشغّلاتها حية: الحالي ± [_windowRadius].
  Set<int> _activeWindow() {
    if (_reels.isEmpty) return const {};
    final window = <int>{};
    for (var i = _currentIndex - _windowRadius;
        i <= _currentIndex + _windowRadius;
        i++) {
      if (i >= 0 && i < _reels.length) window.add(i);
    }
    return window;
  }

  void _disposeControllerForIndex(int index) {
    final chewie = _chewieControllers.remove(index);
    chewie?.dispose();
    final video = _videoControllers.remove(index);
    video?.dispose();
  }

  void _pauseAll() {
    for (final c in _videoControllers.values) {
      c.pause();
    }
  }

  void _togglePlaybackForVisibleIndex() {
    final window = _activeWindow();

    // تخريب أي مشغّل خرج عن النافذة فوراً (بدل إبقائه حياً بلا داعٍ).
    // نتتبّع أي تغيير فعلي بالخريطتين لإعادة البناء فقط عند الحاجة (وليس
    // مع كل استدعاء تشغيل/إيقاف مؤقت لا يغيّر أي مشغّل، مثل استئناف التطبيق).
    var changed = false;
    for (final idx in _videoControllers.keys.toList()) {
      if (!window.contains(idx)) {
        _disposeControllerForIndex(idx);
        changed = true;
      }
    }

    for (final i in window) {
      if (!_videoControllers.containsKey(i)) changed = true;
      _ensureControllerForIndex(i);
    }

    final visible = _currentIndex;
    for (final entry in _videoControllers.entries) {
      final idx = entry.key;
      final controller = entry.value;
      if (idx == visible) {
        if (controller.value.isInitialized) {
          controller.play();
        }
      } else {
        controller.pause();
      }
    }

    // بدون هذا، لا يُعاد بناء itemBuilder فور إنشاء المشغّل الأول، فيبقى
    // العنصر عالقاً على الصورة المصغّرة الثابتة إلى أن يسحب المستخدم الشاشة.
    if (changed && mounted) setState(() {});
  }

  Future<void> _onTapReel(ReelModel reel) async {
    // إيقاف التشغيل قبل مغادرة الشاشة (تفاصيل الشاليه)، واستئنافه عند الرجوع.
    _pauseAll();
    await context.push('/home/chalet/${reel.chaletId}', extra: null);
    if (!mounted) return;
    _togglePlaybackForVisibleIndex();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reels'),
      ),
      body: _loading
          ? const ReelsSkeletonLoader()
          : _error != null
              ? _buildErrorState()
              : _reels.isEmpty
                  ? _buildEmptyState()
                  : PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: _reels.length,
                  itemBuilder: (context, index) {
                    final reel = _reels[index];
                    final chewie = _chewieControllers[index];

                    return GestureDetector(
                      onTap: () => _onTapReel(reel),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: chewie == null
                                ? Container(
                                    color: AppColors.sand,
                                    child: Image.network(
                                      reel.thumbnailUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: AppColors.sand,
                                      ),
                                    ),
                                  )
                                : Chewie(controller: chewie),
                          ),
                          // Bottom overlay
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 24,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        reel.chaletName,
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  reel.description,
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 13,
                                    color: Colors.white70,
                                    height: 1.4,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                // Like (UI only for now; wiring requires userId + like mutation)
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.35),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.favorite_rounded,
                                            color: AppColors.error,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${reel.likesCount}',
                                            style: const TextStyle(
                                              fontFamily: 'Cairo',
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Gradient overlay
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.55),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.textHint,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              child: const Text(
                'إعادة المحاولة',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_off_rounded,
              color: AppColors.textHint,
              size: 48,
            ),
            SizedBox(height: 12),
            Text(
              'لا توجد فيديوهات بعد',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: AppColors.textHint,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// REELS SKELETON LOADER
// ============================================
class ReelsSkeletonLoader extends StatelessWidget {
  const ReelsSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: [
          // AppBar skeleton
          Container(
            height: 56,
            color: Colors.white,
          ),
          // Reel skeleton (takes remaining space)
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(0),
              color: Colors.white,
              child: Stack(
                children: [
                  // Video area skeleton
                  Positioned.fill(
                    child: Container(
                      color: Colors.grey[300],
                    ),
                  ),
                  // Bottom overlay skeleton
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title skeleton
                        Container(
                          width: 200,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Description skeleton
                        Container(
                          width: double.infinity,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 150,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Like button skeleton
                        Container(
                          width: 80,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ],
                    ),
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
