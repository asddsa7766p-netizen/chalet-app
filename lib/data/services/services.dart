import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueNotifier, visibleForTesting;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/date_utils.dart';
import '../models/chalet_model.dart';
import '../models/models.dart';
import 'chalet_slot_availability.dart';
import 'rpc_caller.dart';
import '../../core/utils/error_reporter.dart';

part 'supabase_errors.dart';
part 'auth_service.dart';
part 'chalet_service.dart';
part 'booking_service.dart';
part 'favorites_service.dart';
part 'reviews_service.dart';
