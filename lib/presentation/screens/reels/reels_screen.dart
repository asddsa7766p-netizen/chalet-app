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
  const ReelsScreen({super.key, this.fetchReels, this.active = true});

  /// Injectable for tests; defaults to [ReelsService.instance.fetchReels].
  @visibleForTesting
  final Future<List<ReelModel>> Function()? fetchReels;

  /// هل الشاشة ظاهرة فعلياً؟ داخل IndexedStack بـ MainScreen تبقى الشاشة حية
  /// حتى وهي بتبويب مخفي، فبدون هذا العلم يستمر تشغيل الفيديو (بالصوت) بينما
  /// المستخدم بتبويب آخر. عند false تُوقف وتُحرَّر كل المشغّلات.
  final bool active;

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

  // true أثناء تغطية الشاشة بمسار آخر (تفاصيل الشاليه) أو خروج التطبيق
  // للخلفية، حتى لا يُستأنف التشغيل تحت شاشة أخرى.
  bool _suspended = false;

  bool get _canPlay => widget.active && !_suspended;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _pageController.addListener(_onPageChanged);
  }

  @override
  void didUpdateWidget(covariant ReelsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _syncPlayers();
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
        _syncPlayers();
        break;
    }
  }

  void _onPageChanged() {
    final idx = _pageController.page?.round() ?? 0;
    if (idx == _currentIndex) return;
    setState(() => _currentIndex = idx);
    _syncPlayers();
  }

  Future<void> _load() async {
    // المشغّلات مفهرسة حسب موقع الفيديو بالقائمة، فلا تصلح بعد إعادة الجلب.
    for (final idx in _videoControllers.keys.toList()) {
      _releaseControllerForIndex(idx);
    }
    setState(() {
      _loading = true;
      _error = null;
      _currentIndex = 0;
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
        _syncPlayers();
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

    // ملاحظة: Chewie يرسم placeholder دائماً تحت الفيديو (وليس فقط أثناء
    // التحميل)، فلا يوضع فيه أي مؤشّر متحرك لا ينتهي؛ مؤشّر التحميل يُرسم
    // فوقه بـ _LoadingOverlay ويختفي فور جاهزية الفيديو.
    final chewieController = ChewieController(
      videoPlayerController: videoController,
      autoPlay: false,
      looping: true,
      allowMuting: false,
      showControls: false,
      placeholder: _Thumbnail(url: reel.thumbnailUrl),
    );

    _videoControllers[index] = videoController;
    _chewieControllers[index] = chewieController;

    unawaited(
      videoController.initialize().then((_) {
        // الفيديو الظاهر يبدأ فور جاهزيته، لا عند أول سحب فقط.
        if (!mounted || _videoControllers[index] != videoController) return;
        if (index == _currentIndex && _canPlay) videoController.play();
      }).catchError((Object _) {
        // الخطأ يظهر للمستخدم عبر _LoadingOverlay (value.hasError).
      }),
    );
  }

  /// فهارس النافذة المسموح ببقاء مشغّلاتها حية: الحالي ± [_windowRadius].
  Set<int> _activeWindow() {
    if (_reels.isEmpty || !widget.active) return const {};
    final window = <int>{};
    for (var i = _currentIndex - _windowRadius;
        i <= _currentIndex + _windowRadius;
        i++) {
      if (i >= 0 && i < _reels.length) window.add(i);
    }
    return window;
  }

  void _releaseControllerForIndex(int index) {
    final chewie = _chewieControllers.remove(index);
    final video = _videoControllers.remove(index);
    video?.pause();
    // التخريب بعد إعادة البناء التالية، حتى لا تبقى ودجة Chewie/VideoPlayer
    // بالشجرة مرتبطة بمتحكّم مُخرَّب ولو لإطار واحد.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      chewie?.dispose();
      video?.dispose();
    });
  }

  void _pauseAll() {
    for (final c in _videoControllers.values) {
      c.pause();
    }
  }

  /// يحافظ على نافذة المشغّلات حول الفهرس الظاهر ويشغّل الظاهر فقط.
  void _syncPlayers() {
    if (!mounted) return;
    final window = _activeWindow();

    // تحرير أي مشغّل خرج عن النافذة فوراً (بدل إبقائه حياً بلا داعٍ).
    var changed = false;
    for (final idx in _videoControllers.keys.toList()) {
      if (!window.contains(idx)) {
        _releaseControllerForIndex(idx);
        changed = true;
      }
    }

    for (final i in window) {
      if (!_videoControllers.containsKey(i)) changed = true;
      _ensureControllerForIndex(i);
    }

    for (final entry in _videoControllers.entries) {
      final controller = entry.value;
      if (entry.key == _currentIndex && _canPlay) {
        if (controller.value.isInitialized) controller.play();
      } else {
        controller.pause();
      }
    }

    // بدون هذا، لا يُعاد بناء itemBuilder فور إنشاء المشغّل الأول، فيبقى
    // العنصر عالقاً على الصورة المصغّرة الثابتة إلى أن يسحب المستخدم الشاشة.
    if (changed) setState(() {});
  }

  Future<void> _onTapReel(ReelModel reel) async {
    // إيقاف التشغيل قبل مغادرة الشاشة (تفاصيل الشاليه)، واستئنافه عند الرجوع.
    _suspended = true;
    _pauseAll();
    await context.push('/home/chalet/${reel.chaletId}');
    if (!mounted) return;
    _suspended = false;
    _syncPlayers();
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
                      itemBuilder: (context, index) =>
                          _buildReel(_reels[index], index),
                    ),
    );
  }

  Widget _buildReel(ReelModel reel, int index) {
    final chewie = _chewieControllers[index];
    final video = _videoControllers[index];

    return GestureDetector(
      onTap: () => _onTapReel(reel),
      child: Stack(
        children: [
          Positioned.fill(
            child: chewie == null
                ? _Thumbnail(url: reel.thumbnailUrl)
                : Chewie(controller: chewie),
          ),
          if (video != null)
            Positioned.fill(child: _LoadingOverlay(controller: video)),
          // Gradient overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Bottom overlay
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
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
                // عدد الإعجابات للعرض فقط (زر الإعجاب غير موصول بعد).
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
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
          ),
        ],
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

/// الصورة المصغّرة للفيديو، بلون محايد عند غيابها أو فشل تحميلها.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.sand,
      child: url.isEmpty
          ? null
          : Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
    );
  }
}

/// مؤشّر تحميل فوق الفيديو حتى يجهز فقط، أو رسالة عند فشل تشغيله.
class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          if (value.hasError) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_off_rounded,
                      color: Colors.white70, size: 40),
                  SizedBox(height: 8),
                  Text(
                    'تعذر تشغيل هذا الفيديو',
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
                  ),
                ],
              ),
            );
          }
          if (value.isInitialized) return const SizedBox.shrink();
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        },
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
      child: Stack(
        children: [
          // Video area skeleton
          Positioned.fill(
            child: Container(color: Colors.grey[300]),
          ),
          // Bottom overlay skeleton
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(width: 200, height: 20),
                const SizedBox(height: 8),
                _bar(width: double.infinity, height: 14),
                const SizedBox(height: 4),
                _bar(width: 150, height: 14),
                const SizedBox(height: 12),
                _bar(width: 80, height: 36, radius: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar({
    required double width,
    required double height,
    double radius = 4,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
