import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/booking_period.dart';
import '../../../data/models/models.dart';
import '../../../data/services/services.dart';
import 'review_widgets.dart';

/// إرسال تقييم (النجوم، والتعليق أو null).
typedef ReviewSubmitter = Future<void> Function(int rating, String? comment);

/// يفتح ورقة تقييم [booking]؛ يرجع true إن أُرسل التقييم (حتى لو أُغلقت
/// الورقة بالسحب بعد رسالة الشكر). [submit] للاختبارات.
Future<bool> showWriteReviewSheet(
  BuildContext context, {
  required BookingModel booking,
  ReviewSubmitter? submit,
}) async {
  var submitted = false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => WriteReviewSheet(
      booking: booking,
      submit: submit ??
          (rating, comment) => ReviewsService.instance.addReview(
                chaletId: booking.chaletId,
                bookingId: booking.id,
                rating: rating,
                comment: comment,
              ),
      onSubmitted: () => submitted = true,
    ),
  );
  return submitted;
}

/// من إشعار "كيف كانت إقامتك؟" (لا يحمل رقم الحجز): يقيّم أحدث إقامة مكتملة
/// لم تُقيَّم بعد، أو يخبر أن لا شيء بانتظار التقييم.
Future<bool> openReviewForLatestStay(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  void snack(String text) => messenger.showSnackBar(SnackBar(
      content: Text(text, style: const TextStyle(fontFamily: 'Cairo'))));
  BookingModel? booking;
  try {
    booking = await ReviewsService.instance.latestBookingAwaitingReview();
  } catch (_) {
    snack('تعذر فتح التقييم، حاول مرة أخرى');
    return false;
  }
  if (booking == null) {
    snack('لا توجد إقامة بانتظار تقييمك، شكراً لك!');
    return false;
  }
  if (!context.mounted) return false;
  return showWriteReviewSheet(context, booking: booking);
}

class WriteReviewSheet extends StatefulWidget {
  final BookingModel booking;
  final ReviewSubmitter submit;
  final VoidCallback? onSubmitted;

  const WriteReviewSheet({
    super.key,
    required this.booking,
    required this.submit,
    this.onSubmitted,
  });

  static const maxCommentLength = 500;

  @override
  State<WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<WriteReviewSheet> {
  final _comment = TextEditingController();
  int _rating = 0;
  int? _pulsing;
  bool _sending = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _pick(int rating) {
    setState(() {
      _rating = rating;
      _pulsing = rating;
      _error = null;
    });
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted && _pulsing == rating) setState(() => _pulsing = null);
    });
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final text = _comment.text.trim();
    try {
      await widget.submit(_rating, text.isEmpty ? null : text);
      widget.onSubmitted?.call();
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      setState(() {
        _sending = false;
        _error = isAccountSuspendedError(e)
            ? accountSuspendedMessage
            : msg.contains('already_reviewed')
                ? 'لقد قيّمت هذه الإقامة من قبل'
                : msg.contains('not_eligible_review')
                    ? 'يمكن التقييم بعد اكتمال الإقامة فقط'
                    : 'تعذر إرسال التقييم، حاول مرة أخرى';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _done ? _thanks() : _form(),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    final b = widget.booking;
    return Column(
      key: const ValueKey('review_form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 56,
                height: 56,
                child: (b.chaletImage ?? '').isEmpty
                    ? _imageFallback()
                    : CachedNetworkImage(
                        imageUrl: b.chaletImage!,
                        fit: BoxFit.cover,
                        memCacheWidth: 168,
                        errorWidget: (_, __, ___) => _imageFallback(),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.chaletName ?? 'الشاليه',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.charcoal)),
                  Text('${b.dateLabel} · ${b.periodLabel}',
                      maxLines: 2,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(height: 1, color: AppColors.divider),
        ),
        const Text('كيف كانت إقامتك؟',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= 5; i++)
              Semantics(
                button: true,
                label: '$i من 5',
                child: GestureDetector(
                  key: Key('review_star_$i'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _sending ? null : () => _pick(i),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: AnimatedScale(
                      scale: _pulsing == i ? 1.25 : 1,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutBack,
                      child: Icon(
                        i <= _rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 42,
                        color: i <= _rating ? reviewGold : AppColors.textHint,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _rating == 0 ? 'اختر عدد النجوم' : ratingWord(_rating),
            key: ValueKey(_rating),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _rating == 0 ? AppColors.textHint : AppColors.accentDark),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('review_comment'),
          controller: _comment,
          enabled: !_sending,
          minLines: 3,
          maxLines: 5,
          maxLength: WriteReviewSheet.maxCommentLength,
          textInputAction: TextInputAction.newline,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, height: 1.6),
          decoration: InputDecoration(
            labelText: 'تعليقك (اختياري)',
            hintText: 'ما الذي أعجبك؟ ما الذي يمكن تحسينه؟',
            alignLabelWithHint: true,
            filled: true,
            fillColor: AppColors.scaffold,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(_error!,
              key: const Key('review_error'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 12.5, color: AppColors.error)),
        ],
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            key: const Key('review_submit'),
            onPressed: _rating > 0 && !_sending ? _send : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.25),
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: _sending
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('إرسال التقييم',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  Widget _imageFallback() => Container(
        color: AppColors.primaryPale,
        child: const Icon(Icons.home_work_rounded, color: AppColors.primary),
      );

  Widget _thanks() {
    return Column(
      key: const ValueKey('review_thanks'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (_, s, child) => Transform.scale(scale: s, child: child),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: reviewGold.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite_rounded,
                  color: reviewGold, size: 36),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('شكراً لتقييمك!',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.charcoal)),
        const SizedBox(height: 6),
        const Text('رأيك يساعد العائلات الأخرى على اختيار إقامتها.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            key: const Key('review_done'),
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('تم',
                style: TextStyle(
                    fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}
