part of '../chalet_detail_screen.dart';

extension _ChaletDetailSections on _ChaletDetailScreenState {
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
                  _setState(() => _descriptionExpanded = !_descriptionExpanded),
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
}
