# TODO: chalet_images migration + light theme redesign

## Phase A — Critical fix (REMOVE chalet.images / chalet['images'])
- [ ] Update `lib/data/models/chalet_model.dart`:
  - [ ] Remove `images` field/list.
  - [ ] Add `coverImage` (String) and `discountPercent` (if present) and keep existing fields.
  - [ ] Update `fromJson`/`toJson`/`mainImage` usage.
- [ ] Update `lib/data/services/services.dart`:
  - [ ] Update all Supabase selects that include `chalets(name, images, city)` for bookings.
  - [ ] Join `chalet_images` (cover) to return `cover_image` (or `coverImage`).
  - [ ] Ensure all other Supabase queries remain unchanged.
- [ ] Update `lib/data/models/models.dart` BookingModel:
  - [ ] Remove `(json['chalets']?['images']...)` usage.
  - [ ] Read `cover_image` from joined chalet_images.
- [ ] Update `lib/data/models/reel_model.dart`:
  - [ ] Remove `chalet['images']` mapping.
  - [ ] Map cover image from joined chalet_images.
- [ ] Update `lib/presentation/screens/chalet/chalet_detail_screen.dart`:
  - [ ] Remove gallery usage depending on `chalet.images`.
  - [ ] Use `coverImage` (and optionally fetched gallery if exists).

- [ ] Re-run project-wide search to confirm:
  - [ ] No remaining `chalet.images` or `chalet['images']` or select(...images...chalets...)

## Phase B — Theme/UI
- [ ] Update `lib/core/constants/app_colors.dart` to the exact provided LIGHT palette.
- [ ] Rewrite `lib/presentation/screens/home/home_tab.dart` to match شاليه سبوت home.
- [ ] Run `flutter analyze`.
- [ ] Rewrite `lib/presentation/screens/profile/profile_screen.dart` to match شاليه سبوت profile.
- [ ] Run `flutter analyze`.
- [ ] Final search for any remaining image-column references.

## Reporting
- [ ] Report all modified files in final completion.

