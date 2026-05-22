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
    final videoExt = videoFile.path.split('.').last;
    final thumbExt = thumbnailFile.path.split('.').last;

    final videoPath =
        'reels/${DateTime.now().millisecondsSinceEpoch}_video.$videoExt';
    final thumbPath =
        'thumbnails/${DateTime.now().millisecondsSinceEpoch}_thumb.$thumbExt';

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
  }

  Future<void> toggleLike({
    required String reelId,
    required String userId,
  }) async {
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

  Future<bool> isLiked({
    required String reelId,
    required String userId,
  }) async {
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
