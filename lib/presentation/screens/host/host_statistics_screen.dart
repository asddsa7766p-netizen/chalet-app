import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class HostStatisticsScreen extends StatefulWidget {
  const HostStatisticsScreen({super.key});

  @override
  State<HostStatisticsScreen> createState() => _HostStatisticsScreenState();
}

class _HostStatisticsScreenState extends State<HostStatisticsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // TODO: Load analytics from Supabase.
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الإحصائيات'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _statCard('حجوزات هذا الشهر', '0'),
                  const SizedBox(height: 14),
                  _statCard('الأرباح هذا الشهر', '₪0'),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.sand),
                    ),
                    child: const Text(
                      'أكثر التواريخ شعبية (قيد التنفيذ)',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primaryPale.withOpacity(0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.sand),
            ),
            child:
                const Icon(Icons.bar_chart_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
