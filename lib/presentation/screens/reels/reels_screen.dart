import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/reel_model.dart';
import '../../../data/services/reels_service.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
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
    _load();
    _pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    for (final c in _chewieControllers.values) {
      c.dispose();
    }
    for (final v in _videoControllers.values) {
      v.dispose();
    }
    _pageController.dispose();
    super.dispose();
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
      final reels = await ReelsService.instance.fetchReels();
      if (!mounted) return;
      setState(() {
        _reels = reels;
        _loading = false;
      });

      // Initialize first reel controllers
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureControllerForIndex(0);
        _togglePlaybackForVisibleIndex();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
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

  void _togglePlaybackForVisibleIndex() {
    for (var i = 0; i < _reels.length; i++) {
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
  }

  Future<void> _onTapReel(ReelModel reel) async {
    // Reuse existing navigation to chalet detail.
    context.push('/home/chalet/${reel.chaletId}', extra: null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reels'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                )
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
}
