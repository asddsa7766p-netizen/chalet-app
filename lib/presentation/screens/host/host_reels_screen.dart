
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../widgets/common/common_widgets.dart';

class HostReelsScreen extends StatefulWidget {
  const HostReelsScreen({super.key});

  @override
  State<HostReelsScreen> createState() => _HostReelsScreenState();
}

class _HostReelsScreenState extends State<HostReelsScreen> {
  bool _loading = false;

  Future<void> _uploadPlaceholder() async {
    setState(() => _loading = true);
    try {
      // TODO: Pick video + thumbnail and upload to Supabase.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primary,
            content: Text('رفع Reels (قيد التنفيذ)',
                style: TextStyle(fontFamily: 'Cairo')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('إدارة Reels'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.sand),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الرفع',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'اختر فيديو وصورة مصغرة ثم ارفعها. (قيد التنفيذ)',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'رفع Reels',
                    onPressed: _uploadPlaceholder,
                    loading: _loading,
                    icon: Icons.cloud_upload_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.sand),
              ),
              child: const Text(
                'قائمة Reels/حذفها (قيد التنفيذ)',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
