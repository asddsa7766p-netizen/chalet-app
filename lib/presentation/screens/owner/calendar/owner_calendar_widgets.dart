import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/manual_booking.dart';
import '../../../../data/models/booking_period.dart';
import '../../../../data/models/models.dart';
import '../../../../data/services/chalet_slot_availability.dart';
import '../../../../data/services/pricing_service.dart';
import '../bookings/manual_booking_actions.dart';
import 'owner_calendar_data_source.dart';
import 'owner_calendar_logic.dart';

part 'calendar_day_cell.dart';
part 'owner_day_panel.dart';
part 'range_action_bar.dart';
