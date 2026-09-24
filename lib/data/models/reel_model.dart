class ReelModel {
  final String id;
  final String chaletId;
  final String videoUrl;
  final String thumbnailUrl;
  final String description;
  final int likesCount;
  final DateTime createdAt;

  // Chalet info (denormalized via join)
  final String chaletName;
  final String chaletDescription;
  final List<String> chaletImages;
  final String chaletCity;
  final String chaletLocation;
  final double chaletPricePerNight;

  const ReelModel({
    required this.id,
    required this.chaletId,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.description,
    required this.likesCount,
    required this.createdAt,
    required this.chaletName,
    required this.chaletDescription,
    required this.chaletImages,
    required this.chaletCity,
    required this.chaletLocation,
    required this.chaletPricePerNight,
  });

  factory ReelModel.fromJson(Map<String, dynamic> json) {
    final chalet = json['chalets'] as Map<String, dynamic>? ?? const {};

    return ReelModel(
      id: json['id'] as String,
      // الأعمدة التالية nullable بالقاعدة؛ القيمة الفارغة تُفلتر بـ ReelsService.
      chaletId: json['chalet_id'] as String? ?? '',
      videoUrl: json['video_url'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      description: json['description'] as String? ?? '',
      likesCount: json['likes_count'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      chaletName: chalet['name'] as String? ?? '',
      chaletDescription: chalet['description'] as String? ?? '',
      chaletImages: (chalet['images'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      chaletCity: chalet['city'] as String? ?? '',
      chaletLocation: chalet['location'] as String? ?? '',
      chaletPricePerNight:
          (chalet['price_per_night'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'chalet_id': chaletId,
        'video_url': videoUrl,
        'thumbnail_url': thumbnailUrl,
        'description': description,
        'likes_count': likesCount,
        'created_at': createdAt.toIso8601String(),
      };
}
