import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/services/dashboard_service.dart';

class OwnerReportsScreen extends StatefulWidget {
  const OwnerReportsScreen({super.key});

  @override
  State<OwnerReportsScreen> createState() => _OwnerReportsScreenState();
}

class _OwnerReportsScreenState extends State<OwnerReportsScreen> {
  static const Color _darkGreen = Color(0xFF3D5228);

  OwnerDashboardRange _range = OwnerDashboardRange.last7Days;
  bool _loading = true;
  String? _error;
  OwnerDashboardStats? _stats;
  // عدّاد جيل: تبديل المدى بسرعة كان يعرض نتيجة طلب أقدم وصل متأخراً.
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats =
          await DashboardService.instance.getOwnerDashboardStats(range: _range);
      if (!mounted || gen != _gen) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل التقارير';
      });
    }
  }

  Future<void> _onRangeChanged(OwnerDashboardRange r) async {
    if (r == _range) return;
    setState(() => _range = r);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('التقارير',
              style:
                  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildRangeSelector(),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Column(
                      children: [
                        Text(_error!,
                            style: const TextStyle(fontFamily: 'Cairo')),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _load,
                          child: const Text('إعادة المحاولة',
                              style: TextStyle(fontFamily: 'Cairo')),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                _buildSummaryCards(),
                const SizedBox(height: 20),
                _buildChaletBreakdown(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRangeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: OwnerDashboardRange.values.map((r) {
        final selected = r == _range;
        return ChoiceChip(
          label: Text(r.arLabel,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : AppColors.charcoal,
              )),
          selected: selected,
          selectedColor: _darkGreen,
          backgroundColor: Colors.white,
          onSelected: (_) => _onRangeChanged(r),
        );
      }).toList(),
    );
  }

  Widget _buildSummaryCards() {
    final s = _stats!;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _summaryCard(
            'إجمالي الإيرادات', '₪${s.totalRevenue.toStringAsFixed(0)}'),
        _summaryCard('إجمالي الحجوزات', '${s.totalBookings}'),
        _summaryCard('حجوزات ملغاة/مرفوضة',
            '${s.cancelledOrRejectedByOwner + s.cancelledByUser}'),
        _summaryCard(
            'متوسط حجوزات يومي', s.avgDailyBookings.toStringAsFixed(1)),
      ],
    );
  }

  Widget _summaryCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.charcoal)),
          const SizedBox(height: 4),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildChaletBreakdown() {
    final list = _stats!.byChaletRevenue;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الإيرادات حسب الشاليه',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal)),
          const SizedBox(height: 12),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('لا توجد بيانات لهذه الفترة',
                    style: TextStyle(
                        fontFamily: 'Cairo', color: AppColors.textHint)),
              ),
            )
          else
            for (final c in list) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(c.chaletName,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.charcoal)),
                  ),
                  Text('${c.bookingsCount} حجز',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                  const SizedBox(width: 10),
                  Text('₪${c.revenue.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: _darkGreen)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: c.ratioPercent / 100,
                  minHeight: 6,
                  backgroundColor: AppColors.sand,
                  color: _darkGreen,
                ),
              ),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}
