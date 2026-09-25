import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as latlong2;

import '../../../data/models/chalet_model.dart';
import '../../../data/services/services.dart';

class PalestineChaletsMapScreen extends StatefulWidget {
  const PalestineChaletsMapScreen({super.key});

  @override
  State<PalestineChaletsMapScreen> createState() =>
      _PalestineChaletsMapScreenState();
}

class _PalestineChaletsMapScreenState extends State<PalestineChaletsMapScreen> {
  static const _palestineCenter = latlong2.LatLng(31.9, 35.2);

  bool _loading = true;
  String? _error;
  List<ChaletModel> _chalets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final chalets = await ChaletService.instance.getChalets(limit: 1000);

      // نحتفظ فقط بالشاليهات اللي عندها إحداثيات حقيقية داخل فلسطين
      final filtered = chalets.where((c) {
        final lat = c.latitude;
        final lng = c.longitude;
        if (lat == null || lng == null) return false;
        if (lat == 0.0 && lng == 0.0) return false;
        // فلسطين تقريباً: latitude 29-34, longitude 34-36.5
        if (lat < 29.0 || lat > 34.0) return false;
        if (lng < 34.0 || lng > 36.5) return false;
        return true;
      }).toList();

      if (!mounted) return;
      setState(() {
        _chalets = filtered;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل الخريطة، يرجى المحاولة لاحقاً';
        _loading = false;
      });
    }
  }

  void _showChaletBottomSheet(ChaletModel chalet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      chalet.name,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'السعر يبدأ من ${chalet.pricePerNight.toStringAsFixed(0)} ₪',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B1B1B),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFF0D5BAE)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'إغلاق',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D5BAE),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push('/home/chalet/${chalet.id}',
                            extra: chalet);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF0D5BAE),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'عرض الشاليه',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = _chalets.map((chalet) {
      final double lat = chalet.latitude ?? 0.0;
      final double lng = chalet.longitude ?? 0.0;
      final position = latlong2.LatLng(lat, lng);

      return Marker(
        point: position,
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showChaletBottomSheet(chalet),
          child: const Icon(
            Icons.location_on_rounded,
            color: Color(0xFF0D5BAE),
            size: 36,
          ),
        ),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('خريطة الشاليهات في فلسطين'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'حدث خطأ أثناء تحميل البيانات: $_error',
                      style: const TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                )
              : FlutterMap(
                  options: const MapOptions(
                    initialCenter: _palestineCenter,
                    initialZoom: 9.5,
                    interactionOptions: InteractionOptions(
                      flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'makan',
                      maxZoom: 19,
                    ),
                    MarkerLayer(markers: markers),
                  ],
                ),
    );
  }
}
