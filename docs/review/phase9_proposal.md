# المرحلة 9 — مقترح ترتيب lib/ (بانتظار الموافقة، لم يُنقل شيء)

**المبدأ:** نقل وتقسيم فقط، بلا أي تغيير سلوك. الأجزاء المستخرجة من الشاشات تصبح `StatelessWidget` تستقبل البيانات والـ callbacks، والمنطق والحالة يبقيان في `State` الأصلي. المفاتيح (`Key`) والنصوص لا تتغير، فتبقى الاختبارات الحالية حَكَماً. التنفيذ مجلداً مجلداً، مع analyze + test + commit لكل مجلد.

`services.dart` و`models.dart` يبقيان **ملفّي تصدير (barrel)** بعد التقسيم، فلا تتغير عشرات الاستيرادات.

## أ) نقل وإعادة تسمية

| من | إلى | السبب |
|---|---|---|
| `data/services/services.dart` (1157) | `supabase_errors.dart` (العميل + الرسائل + `translateSupabaseError`)، `auth_service.dart` (+ `PendingAuthAction`، `AuthRedirectService`)، `chalet_service.dart`، `booking_service.dart`، `favorites_service.dart`، `reviews_service.dart` — و`services.dart` = exports | 6 خدمات في ملف واحد |
| `data/models/models.dart` | `booking_model.dart` (+ `BookingStatus`)، `user_profile.dart`، `review_model.dart` — و`models.dart` = exports | ملف لكل نموذج كبقية المجلد |
| `data/services/unavailable_nights.dart` | `data/services/rpc_caller.dart` | لم يبقَ فيه إلا `RpcCaller` |
| `core/theme/locale_notifier.dart`، `app_state_providers.dart` | `core/settings/` | اللغة ليست ثيماً |
| `screens/widgets/payment_widgets.dart` | `screens/payment/widgets/payment_widgets.dart` | مجلد `widgets` داخل `screens` شاذ |
| `screens/theme/payment_theme.dart` | `screens/payment/payment_theme.dart` | خاص بالدفع فقط |
| `screens/favorites/favorites_screen.dart` (1088) | `favorites/favorites_screen.dart` (FavoritesScreen ≈230)، `bookings/my_bookings_screen.dart` (MyBookingsScreen + `_BookingCard` ≈500، **يحل محل** ملف الـ export)، `reviews/reviews_screen.dart` (ReviewsScreen + `_ReviewTile` ≈360، **يحل محل** ملف الـ export) | 3 شاشات بملف واحد، وملفا export فارغان |
| `screens/notifications/owner_notifications_screen.dart` | `screens/owner/owner_notifications_screen.dart` | شاشة مالك |
| `screens/owner/` (25 ملفاً مسطّحاً) | `owner/` (لوحة، شاليهاتي، تقارير، بروفايل، شريط سفلي، إشعارات) + `owner/bookings/` (owner_bookings_screen، owner_booking_actions، owner_external_screen، manual_booking_sheet، manual_booking_actions) + `owner/calendar/` (screen، widgets، logic، data_source) + `owner/chalet_form/` (add، edit، edit_model، edit_validation، edit_data_source، images_editor) + `owner/pricing/` (chalet_pricing_screen، pricing_data_source، pricing_preview، effective_price_panel، base_price_notice) | تجميع حسب الميزة |

## ب) تقسيم الملفات > 800 سطر

| من (أسطر) | إلى (≈ أسطر) |
|---|---|
| `booking/booking_screen.dart` (1853) | `booking_screen.dart` (≈700: الحالة والمنطق) + `booking/widgets/`: `booking_calendar_section.dart` (التقويم وأنواع الإقامة ≈360)، `booking_form_sections.dart` (الضيوف، الدفع، الملاحظات ≈310)، `booking_price_summary.dart` (الملخص، الحالة، الشريط السفلي ≈210)، `booking_success_dialog.dart` (≈150) |
| `owner/owner_edit_chalet_screen.dart` (1646) | `edit_chalet_screen.dart` (≈850) + `chalet_form/edit_chalet_sections.dart` (أساسي، سعة، مرافق، موقع، وسائط، أسعار ≈800) |
| `chalet/chalet_detail_screen.dart` (1608) | `chalet_detail_screen.dart` (≈800) + `chalet/widgets/`: `chalet_detail_sections.dart` (الموقع، الوصف، المرافق، الفيديو ≈400)، `chalet_reviews_section.dart` (≈300)، `full_screen_gallery.dart` (≈90) |
| `owner/chalet_pricing_screen.dart` (1587) | `chalet_pricing_screen.dart` (≈900) + `pricing/`: `date_override_dialog.dart` (≈75)، `stay_type_card.dart` (≈230)، `weekday_prices_section.dart` (≈210)، `date_overrides_section.dart` (≈120) |
| `owner/owner_add_chalet_screen.dart` (1332) | `add_chalet_screen.dart` (≈700) + `chalet_form/add_chalet_steps.dart` (خطوات المعالج ≈450) + `chalet_form/add_chalet_widgets.dart` (غلاف الصورة، الإطار المنقّط، حقل الرقم ≈180) |
| `home/home_tab.dart` (1281) | `home_tab.dart` (≈430) + `home/widgets/`: `home_header.dart` (الرأس، الترحيب، البانر، الفئات ≈290)، `home_sections.dart` (الأكثر حجزاً، المدن، القريبة ≈500)، `city_picker_sheet.dart` (≈135) |
| `owner/owner_calendar_screen.dart` (1199) | `calendar/owner_calendar_screen.dart` (≈830) + `calendar/calendar_month_grid.dart` (≈220) + `calendar/calendar_chalet_selector.dart` (≈90) |
| `owner/owner_calendar_widgets.dart` (1161) | `calendar/calendar_day_cell.dart` (اللوحة، الرسام، الخلية، المفتاح ≈430)، `calendar/owner_day_panel.dart` (≈570)، `calendar/range_action_bar.dart` (≈150) |
| `admin/admin_dashboard_screen.dart` (1025) | `admin_dashboard_screen.dart` (≈245) + `admin/overview_tab.dart` (≈220)، `admin/chalet_approvals_tab.dart` (≈245)، `admin/users_tab.dart` (≈310) |
| `search/search_screen.dart` (1023) | `search_screen.dart` (≈680) + `search/search_filters_sheet.dart` (≈350) |
| `owner/manual_booking_sheet.dart` (1004) | `bookings/manual_booking_sheet.dart` (≈820) + `bookings/manual_booking_models.dart` (Chalet، Request، typedefs، validators ≈180) |
| `owner/owner_dashboard_screen.dart` (986) | `owner_dashboard_screen.dart` (≈560) + `owner/widgets/dashboard_upcoming_section.dart` (≈200) + `owner/widgets/dashboard_actions_section.dart` (إجراءات سريعة + أداء ≈200) |
| `profile/profile_screen.dart` (840) | `profile_screen.dart` (≈755) + `profile/edit_profile_sheet.dart` (≈85) |

بعد التنفيذ: لا ملف > 900 سطر، وأربعة فقط بين 800 و 900 (`booking_screen` منطقه وحده ≈700 ويشمل الحالة؛ `edit_chalet_screen` و`chalet_pricing_screen` و`manual_booking_sheet` منطقها المتداخل لا يُفصل بلا تغيير سلوك).

**الاختبارات:** استيرادات `test/` تتحدث للمسارات الجديدة فقط.
