import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/error_reporter.dart';

/// بلاطات OpenStreetMap بهوية التطبيق الحقيقية (سياسة OSM تطلب User-Agent
/// يعرّف التطبيق، وتحجب الغامض منها).
TileLayer osmTileLayer() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.makan.app',
      maxZoom: 19,
    );

/// إسناد OpenStreetMap الإلزامي (رخصة ODbL) فوق الخريطة، ويفتح صفحة
/// حقوق النشر عند الضغط. يوضع آخر عناصر `FlutterMap.children`.
class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key});

  static const text = '© OpenStreetMap contributors';
  static final _copyrightUri =
      Uri.parse('https://www.openstreetmap.org/copyright');

  Future<void> _open() async {
    try {
      await launchUrl(_copyrightUri, mode: LaunchMode.externalApplication);
    } catch (e, st) {
      reportError(e, st, context: 'osm_attribution.open');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: GestureDetector(
        onTap: _open,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          color: Colors.white.withValues(alpha: 0.8),
          // اتجاه ثابت: داخل واجهة RTL كان "©" سينتقل لآخر السطر.
          child: const Text(
            text,
            textDirection: TextDirection.ltr,
            style: TextStyle(fontSize: 10, color: Colors.black87),
          ),
        ),
      ),
    );
  }
}
