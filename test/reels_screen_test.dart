import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan/data/models/reel_model.dart';
import 'package:makan/presentation/screens/reels/reels_screen.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// منصة فيديو وهمية: لا تشغّل أي فيديو حقيقياً، فقط تحاكي رسائل platform
/// channel كافية ليعمل video_player/chewie داخل اختبار widget بلا شبكة.
class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  int _nextId = 0;
  final Set<int> aliveIds = {};
  final List<String> calls = [];
  final _events = <int, StreamController<VideoEvent>>{};

  @override
  Future<void> init() async {}

  @override
  Future<int> createWithOptions(VideoCreationOptions options) async {
    final id = _nextId++;
    aliveIds.add(id);
    calls.add('create:$id');
    _events[id] = StreamController<VideoEvent>.broadcast();
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    final controller = _events[playerId]!;
    // يُجدوَل بعد أن يشترك VideoPlayerController بالستريم (يحدث فوراً
    // ومتزامناً بعد استدعاء هذه الدالة)، لتفادي فقدان الحدث ببث بلا مستمع.
    scheduleMicrotask(() {
      if (controller.isClosed) return;
      controller.add(VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 10),
        size: const Size(100, 100),
      ));
    });
    return controller.stream;
  }

  @override
  Future<void> dispose(int playerId) async {
    aliveIds.remove(playerId);
    calls.add('dispose:$playerId');
    await _events.remove(playerId)?.close();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> play(int playerId) async {
    calls.add('play:$playerId');
  }

  @override
  Future<void> pause(int playerId) async {
    calls.add('pause:$playerId');
  }

  @override
  Widget buildView(int playerId) => const SizedBox.shrink();
}

ReelModel _fakeReel(int i) => ReelModel(
      id: 'reel-$i',
      chaletId: 'chalet-$i',
      videoUrl: 'https://example.com/video-$i.mp4',
      thumbnailUrl: 'https://example.com/thumb-$i.jpg',
      description: 'وصف $i',
      likesCount: i,
      createdAt: DateTime(2030, 1, 1 + i),
      chaletName: 'شاليه $i',
      chaletDescription: '',
      chaletImages: const [],
      chaletCity: '',
      chaletLocation: '',
      chaletPricePerNight: 0,
    );

void main() {
  late _FakeVideoPlayerPlatform fakePlatform;

  setUp(() {
    fakePlatform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;
  });

  group('حالات بلا بيانات فعلية', () {
    testWidgets('قائمة فارغة تعرض "لا توجد فيديوهات بعد" بدل صفحة بيضاء',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ReelsScreen(fetchReels: () async => const []),
      ));
      await tester.pumpAndSettle();

      expect(find.text('لا توجد فيديوهات بعد'), findsOneWidget);
      expect(fakePlatform.aliveIds, isEmpty);
    });

    testWidgets('فشل التحميل يعرض رسالة خطأ وزر إعادة محاولة يعمل فعلياً',
        (tester) async {
      var attempt = 0;
      await tester.pumpWidget(MaterialApp(
        home: ReelsScreen(
          fetchReels: () async {
            attempt++;
            if (attempt == 1) throw Exception('network down');
            return [_fakeReel(0)];
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('تعذر تحميل الفيديوهات، يرجى المحاولة لاحقاً'),
          findsOneWidget);
      final retryButton = find.text('إعادة المحاولة');
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      await tester.pumpAndSettle();

      expect(attempt, 2);
      expect(find.text('تعذر تحميل الفيديوهات، يرجى المحاولة لاحقاً'),
          findsNothing);
    });
  });

  group('نافذة تشغيل الفيديو', () {
    testWidgets(
        'لا يتجاوز عدد مشغّلات الفيديو الحية 3 عند التنقّل بين 5 فيديوهات',
        (tester) async {
      final reels = List.generate(5, _fakeReel);
      await tester.pumpWidget(MaterialApp(
        home: ReelsScreen(fetchReels: () async => reels),
      ));
      await tester.pumpAndSettle();

      expect(fakePlatform.aliveIds.length, lessThanOrEqualTo(3));

      final pageView = find.byType(PageView);
      for (var i = 0; i < 4; i++) {
        await tester.drag(pageView, const Offset(0, -700));
        await tester.pumpAndSettle();
        expect(fakePlatform.aliveIds.length, lessThanOrEqualTo(3));
      }

      // تأكيد أن التنقّل حصل فعلاً (أُنشئت مشغّلات أكثر من حجم نافذة واحدة)
      // وأن بعضها فعلاً تم تخريبه بدل تركه حياً للأبد.
      final totalCreated =
          fakePlatform.calls.where((c) => c.startsWith('create:')).length;
      expect(totalCreated, greaterThan(2));
      expect(
        fakePlatform.calls.where((c) => c.startsWith('dispose:')).length,
        greaterThan(0),
      );
    });

    testWidgets('مغادرة الشاشة (dispose) توقف كل المشغّلات ولا تُسرّب أياً منها',
        (tester) async {
      final reels = List.generate(3, _fakeReel);
      await tester.pumpWidget(MaterialApp(
        home: ReelsScreen(fetchReels: () async => reels),
      ));
      await tester.pumpAndSettle();

      expect(fakePlatform.aliveIds, isNotEmpty);

      // استبدال شجرة الودجت بالكامل يُنهي ReelsScreen (نفس أثر مغادرة الشاشة
      // فعلياً) ويستدعي dispose() الخاص بها.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      expect(fakePlatform.aliveIds, isEmpty);
    });
  });
}
