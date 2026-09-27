/// حالة اعتماد الشاليه كما تحددها الإدارة.
///
/// الرفض لا يحذف الشاليه (admin_reject_chalet): يبقى غير معتمد مع
/// rejection_reason وrejected_at، فيعدّله المالك ثم يعيد إرساله
/// (resubmit_chalet) فيعود "بانتظار الموافقة". الاعتماد يمسح أي رفض سابق.
enum ChaletApprovalStatus { approved, pending, rejected }

extension ChaletApprovalRow on Map<String, dynamic> {
  DateTime? get rejectedAt => _date(this['rejected_at']);

  String? get rejectionReason {
    final r = (this['rejection_reason'] as String?)?.trim();
    return r == null || r.isEmpty ? null : r;
  }

  ChaletApprovalStatus get approvalStatus {
    if (this['is_approved'] == true) return ChaletApprovalStatus.approved;
    return rejectedAt != null
        ? ChaletApprovalStatus.rejected
        : ChaletApprovalStatus.pending;
  }
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// "26/9/2026" — تاريخ الرفض بتوقيت الجهاز.
String formatRejectionDate(DateTime d) {
  final l = d.toLocal();
  return '${l.day}/${l.month}/${l.year}';
}
