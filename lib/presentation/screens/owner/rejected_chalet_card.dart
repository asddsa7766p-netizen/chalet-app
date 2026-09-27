import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/chalet_approval.dart';

/// بطاقة شاليه رفضته الإدارة (شاليهاتي): شارة "مرفوض" حمراء، سبب الرفض
/// وتاريخه بوضوح، "تعديل" و"الأسعار"، ثم — بعد التعديل ([canResubmit]) —
/// "إعادة الإرسال للمراجعة" (resubmit_chalet) فيعود "بانتظار الموافقة".
class RejectedChaletCard extends StatefulWidget {
  final Map<String, dynamic> chalet;
  final bool canResubmit;
  final VoidCallback onEdit;
  final VoidCallback onManagePrices;

  /// يستدعي resubmit_chalet؛ الخطأ يُعرض برسالته ويبقى الشاليه مرفوضاً.
  final Future<void> Function() resubmit;
  final VoidCallback onResubmitted;

  const RejectedChaletCard({
    super.key,
    required this.chalet,
    required this.canResubmit,
    required this.onEdit,
    required this.onManagePrices,
    required this.resubmit,
    required this.onResubmitted,
  });

  @override
  State<RejectedChaletCard> createState() => _RejectedChaletCardState();
}

class _RejectedChaletCardState extends State<RejectedChaletCard> {
  bool _sending = false;

  Future<void> _resubmit() async {
    if (_sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.resubmit();
      messenger.showSnackBar(const SnackBar(
        content: Text('أُعيد إرسال الشاليه للمراجعة ✅',
            style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.primary,
      ));
      widget.onResubmitted();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', ''),
            style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.error,
      ));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.chalet;
    final name = (c['name'] as String?)?.trim().isNotEmpty == true
        ? c['name'] as String
        : 'بدون اسم';
    final rejectedAt = c.rejectedAt;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                key: const Key('rejected_badge'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'مرفوض',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rejectedAt == null
                      ? 'سبب الرفض'
                      : 'سبب الرفض · ${formatRejectionDate(rejectedAt)}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  c.rejectionReason ?? '—',
                  key: const Key('rejection_reason_text'),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.canResubmit
                ? 'عدّلت الشاليه؟ أعد إرساله ليراجعه فريق الإدارة من جديد.'
                : 'عدّل الشاليه حسب السبب، ثم أعد إرساله للمراجعة.',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _outlined(
                  key: const Key('rejected_edit'),
                  icon: Icons.edit_rounded,
                  label: 'تعديل',
                  onPressed: _sending ? null : widget.onEdit,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _outlined(
                  icon: Icons.sell_rounded,
                  label: 'الأسعار',
                  onPressed: _sending ? null : widget.onManagePrices,
                ),
              ),
            ],
          ),
          if (widget.canResubmit) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              key: const Key('rejected_resubmit'),
              onPressed: _sending ? null : _resubmit,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 16),
              label: const Text('إعادة الإرسال للمراجعة',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _outlined({
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      key: key,
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label,
          style:
              const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.7)),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
