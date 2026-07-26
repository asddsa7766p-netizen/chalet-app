import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reel_model.dart';

final _supabase = Supabase.instance.client;

class ReelsService {
  static ReelsService? _instance;
  static ReelsService get instance => _instance ??= ReelsService._();
  ReelsService._();

  Future<List<ReelModel>> fetchReels() async {
    final data = await _supabase
        .from('reels')
        .select('*, chalets(*)')
        .order('created_at', ascending: false);

    return (data as List).map((e) => ReelModel.fromJson(e)).toList();
  }

  Future<void> uploadReel({
    required File videoFile,
    required File thumbnailFile,
    required String chaletId,
    required String description,
  }) async {
    // Security checks before any upload
    // - size limit: 100MB for the video, 10MB for the thumbnail
    // - extension/MIME: only allow video (mp4/mov) and thumbnail images (png/jpg/jpeg)
    const maxVideoBytes = 100 * 1024 * 1024;
    const maxThumbBytes = 10 * 1024 * 1024;

    final videoBytes = await videoFile.length();
    if (videoBytes > maxVideoBytes) {
      throw FormatException('File too large');
    }

    final thumbBytes = await thumbnailFile.length();
    if (thumbBytes > maxThumbBytes) {
      throw FormatException('Thumbnail too large');
    }

    final videoName = videoFile.path.split('/').last;
    final thumbName = thumbnailFile.path.split('/').last;
    final videoExt = videoName.contains('.') ? videoName.split('.').last : '';
    final thumbExt = thumbName.contains('.') ? thumbName.split('.').last : '';

    final allowedVideoExt = {'mp4', 'mov'};
    final allowedThumbExt = {'png', 'jpg', 'jpeg'};

    final videoExtLower = videoExt.toLowerCase();
    final thumbExtLower = thumbExt.toLowerCase();

    if (!allowedVideoExt.contains(videoExtLower)) {
      throw FormatException('Invalid video type');
    }

    if (!allowedThumbExt.contains(thumbExtLower)) {
      throw FormatException('Invalid thumbnail type');
    }

    // Best-effort MIME validation based on file extension.
    // (Dart/Flutter cannot reliably detect MIME without extra packages; this still blocks obvious bypasses.)
    final inferredVideoMime = videoExtLower == 'mp4'
        ? 'video/mp4'
        : videoExtLower == 'mov'
            ? 'video/quicktime'
            : null;

    if (inferredVideoMime == null) {
      throw FormatException('Invalid video type');
    }

    try {
      final videoPath =
          'reels/${DateTime.now().millisecondsSinceEpoch}_video.$videoExtLower';
      final thumbPath =
          'thumbnails/${DateTime.now().millisecondsSinceEpoch}_thumb.$thumbExtLower';

      final videoUrl = await _uploadFile(
        file: videoFile,
        path: videoPath,
        bucket: 'reels',
      );
      final thumbnailUrl = await _uploadFile(
        file: thumbnailFile,
        path: thumbPath,
        bucket: 'thumbnails',
      );

      await _supabase.from('reels').insert({
        'chalet_id': chaletId,
        'video_url': videoUrl,
        'thumbnail_url': thumbnailUrl,
        'description': description,
      });
    } catch (_) {
      // Don't leak storage/Supabase error details to the UI.
      throw Exception('Upload failed');
    }
  }

  Future<void> toggleLike({required String reelId}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final existing = await _supabase
        .from('reel_likes')
        .select('id')
        .eq('reel_id', reelId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing == null) {
      await _supabase.from('reel_likes').insert({
        'reel_id': reelId,
        'user_id': userId,
      });
      return;
    }

    await _supabase.from('reel_likes').delete().eq('id', existing['id']);
  }

  Future<bool> isLiked({required String reelId}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final data = await _supabase
        .from('reel_likes')
        .select('id')
        .eq('reel_id', reelId)
        .eq('user_id', userId)
        .limit(1);

    return (data as List).isNotEmpty;
  }

  Future<String> _uploadFile({
    required File file,
    required String path,
    required String bucket,
  }) async {
    await _supabase.storage
        .from(bucket)
        .upload(path, file, fileOptions: const FileOptions(upsert: true));

    final publicUrl = _supabase.storage.from(bucket).getPublicUrl(path);

    return publicUrl;
  }
}
