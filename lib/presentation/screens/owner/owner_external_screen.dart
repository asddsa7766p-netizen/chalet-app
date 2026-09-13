// lib/presentation/screens/owner/owner_external_screen.dart
//
// UX-01: شاشة الحجوزات الخارجية — بدلاً من "قريباً"
// الحجوزات الخارجية: booking_type = 'خارجي' (شاليهات خارج المنصة)
// المالك يضيف حجوزات يدوياً لإدارة التقويم ومنع التعارض.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/services/services.dart';
import '../../widgets/common/common_widgets.dart';

class OwnerExternalScreen extends StatefulWidget {
  const OwnerExternalScreen({super.key});

  @override
  State<OwnerExternalScreen> createState() => _OwnerExternalScreenState();
}

class _OwnerExternalScreenState extends State<OwnerExternalScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _externalChalets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final ownerId = AuthService.instance.currentUser?.id;
    if (ownerId == null) {
      setState(() {
        _loading = false;
        _error = 'لا يوجد مستخدم مسجل دخول';
      });
      return;
    }
    try {
      // جلب الشاليهات الخارجية للمالك
      _externalChalets =
          await ChaletService.instance.getOwnerExternalChalets(ownerId);
      final chaletIds = _externalChalets.map((c) => c['id'] as String).toList();

      List<Map<String, dynamic>> bookings = [];
      if (chaletIds.isNotEmpty) {
        bookings =
            await BookingService.instance.getOwnerExternalBookings(chaletIds);
      }

      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل الحجوزات، يرجى المحاولة لاحقاً';
      });
    }
  }

  Future<void> _addExternalBooking() async {
    if (_externalChalets.isEmpty) {
      _showSnack('لا يوجد شاليهات خارجية — أضف شاليهاً من نوع "خارجي" أولاً',
          isError: true);
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddExternalBookingSheet(
        chalets: _externalChalets,
        onSaved: () {
          Navigator.pop(context);
          _load();
        },
      ),
    );
  }

  Future<void> _deleteBooking(String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف الحجز',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: const Text('هل تريد حذف هذا الحجز الخارجي؟',
            style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف',
                  style:
                      TextStyle(fontFamily: 'Cairo', color: AppColors.error))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await BookingService.instance.deleteBookingRecord(bookingId);
      _showSnack('تم حذف الحجز');
      _load();
    } catch (_) {
      _showSnack('فشل الحذف، يرجى المحاولة لاحقاً', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: isError ? AppColors.error : AppColors.primary,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('الحجوزات الخارجية',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
            onPressed: _addExternalBooking,
            tooltip: 'إضافة حجز خارجي',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: _error != null
                  ? _buildError()
                  : _bookings.isEmpty
                      ? _buildEmpty()
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _bookings.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _bookingTile(_bookings[i]),
                        ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExternalBooking,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة حجز',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _buildError() => ListView(children: [
        const SizedBox(height: 100),
        Center(
            child: Text(_error!,
                style: const TextStyle(
                    fontFamily: 'Cairo', color: AppColors.textSecondary))),
        Center(
            child: TextButton(
                onPressed: _load,
                child: const Text('إعادة المحاولة',
                    style: TextStyle(
                        fontFamily: 'Cairo', color: AppColors.primary)))),
      ]);

  Widget _buildEmpty() => ListView(children: [
        const SizedBox(height: 100),
        const Icon(Icons.public_off_rounded,
            size: 56, color: AppColors.textMuted),
        const SizedBox(height: 14),
        const Center(
            child: Text('لا توجد حجوزات خارجية',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary))),
        const SizedBox(height: 6),
        const Center(
            child: Text('اضغط + لإضافة حجز يدوي خارج المنصة',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: AppColors.textMuted))),
      ]);

  Widget _bookingTile(Map<String, dynamic> b) {
    final chaletName = (b['chalets'] as Map?)?['name'] as String? ?? 'شاليه';
    final checkIn = b['check_in'] as String? ?? '';
    final checkOut = b['check_out'] as String? ?? '';
    final price = (b['total_price'] as num?)?.toDouble() ?? 0;
    final notes = b['notes'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.public_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(chaletName,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text('$checkIn → $checkOut',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: AppColors.textSecondary)),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(notes,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: AppColors.textMuted)),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₪${price.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary)),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _deleteBooking(b['id'] as String),
                child: const Icon(Icons.delete_outline_rounded,
                    size: 20, color: AppColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Bottom Sheet إضافة حجز خارجي ──────────────────────────────────────────

class _AddExternalBookingSheet extends StatefulWidget {
  final List<Map<String, dynamic>> chalets;
  final VoidCallback onSaved;

  const _AddExternalBookingSheet(
      {required this.chalets, required this.onSaved});

  @override
  State<_AddExternalBookingSheet> createState() =>
      _AddExternalBookingSheetState();
}

class _AddExternalBookingSheetState extends State<_AddExternalBookingSheet> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0');

  String? _selectedChaletId;
  DateTime? _checkIn;
  DateTime? _checkOut;
  bool _saving = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isCheckIn}) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: isCheckIn
          ? (_checkIn ?? now)
          : (_checkOut ?? now.add(const Duration(days: 1))),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (date == null) return;
    setState(() {
      if (isCheckIn)
        _checkIn = date;
      else
        _checkOut = date;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_checkIn == null || _checkOut == null) {
      _showSnack('اختر تواريخ الحجز', isError: true);
      return;
    }
    if (!_checkOut!.isAfter(_checkIn!)) {
      _showSnack('تاريخ المغادرة يجب أن يكون بعد الوصول', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      final guestsCount = 1;
      final totalPrice = double.tryParse(_priceCtrl.text.trim()) ?? 0;
      final guestName =
          userId; // fallback if RPC expects guest_name based on current user; keep UI logic unchanged
      final guestPhone =
          userId; // fallback; RPC will validate/override if needed

      await BookingService.instance.createExternalBooking(
        chaletId: _selectedChaletId!,
        checkIn: _checkIn!,
        checkOut: _checkOut!,
        guestsCount: guestsCount,
        totalPrice: totalPrice,
        guestName: guestName,
        guestPhone: guestPhone,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        stayType: 'خارجي',
      );
      widget.onSaved();
    } catch (_) {
      if (mounted) _showSnack('فشل الحفظ، يرجى المحاولة لاحقاً', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: isError ? AppColors.error : AppColors.primary,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إضافة حجز خارجي',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              // اختيار الشاليه
              DropdownButtonFormField<String>(
                value: _selectedChaletId,
                decoration: InputDecoration(
                  labelText: 'الشاليه',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: widget.chalets
                    .map((c) => DropdownMenuItem(
                          value: c['id'] as String,
                          child: Text(c['name'] as String? ?? '',
                              style: const TextStyle(
                                  fontFamily: 'Cairo', fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedChaletId = v),
                validator: (v) => v == null ? 'اختر الشاليه' : null,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _dateTile(
                        label: 'تاريخ الوصول',
                        date: _checkIn,
                        onTap: () => _pickDate(isCheckIn: true))),
                const SizedBox(width: 10),
                Expanded(
                    child: _dateTile(
                        label: 'تاريخ المغادرة',
                        date: _checkOut,
                        onTap: () => _pickDate(isCheckIn: false))),
              ]),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _priceCtrl,
                label: 'السعر الإجمالي (اختياري)',
                hint: '0',
                prefixIcon: Icons.attach_money_rounded,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _notesCtrl,
                label: 'ملاحظات (اختياري)',
                hint: 'اسم الضيف أو أي تفاصيل...',
                prefixIcon: Icons.notes_rounded,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              AppButton(
                label: _saving ? 'جارٍ الحفظ...' : 'حفظ الحجز',
                loading: _saving,
                icon: Icons.save_rounded,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateTile(
      {required String label,
      required DateTime? date,
      required VoidCallback onTap}) {
    final text = date == null
        ? 'اختر التاريخ'
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
          color: AppColors.card,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(text,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: date == null
                      ? AppColors.textHint
                      : AppColors.textPrimary)),
        ]),
      ),
    );
  }
}
