# TODO - Palestine Chalets Map

- [x] Update pubspec.yaml with flutter_map + latlong2 dependencies.

- [ ] Create map screen: lib/presentation/screens/map/palestine_chalets_map_screen.dart
  - [ ] Fetch chalets from Supabase via ChaletService (use latitude/longitude fields).
  - [ ] Center FlutterMap on Palestine (31.9, 35.2).
  - [ ] Render OSM tiles and chalet markers.
  - [ ] On marker tap, show bottom sheet with chalet name and price.
- [x] Update router: lib/core/router/app_router.dart
  - [x] Add route '/map' that builds the map screen.
- [x] Update MainScreen bottom navigation to include a new tab for map.
- [ ] Run flutter analyze / tests to ensure compile success.


