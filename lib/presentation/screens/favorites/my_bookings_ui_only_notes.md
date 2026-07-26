UI-only conversion progress:
- Target HTML: stitch_/my_bookings/code.html
- Flutter target: MyBookingsScreen inside lib/presentation/screens/favorites/favorites_screen.dart
- Current status: conversion not completed.
- Next steps: Replace MyBookingsScreen build() and _BookingCard widget tree to match HTML: header w/ menu + title + notifications, tabs container, booking cards with image+badge+details+buttons, and bottom nav.
- Constraint: Do not change logic/API calls (keep _load(), _cancel(), BookingService calls, BookingModel data mapping).
