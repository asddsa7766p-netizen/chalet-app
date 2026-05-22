import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class HostBookingsScreen extends StatefulWidget {
  const HostBookingsScreen({super.key});

  @override
  State<HostBookingsScreen> createState() => _HostBookingsScreenState();
}

class _HostBookingsScreenState extends State<HostBookingsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // TODO: Load host bookings from Supabase.
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الحجوزات الواردة'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'قائمة الحجوزات (قيد التنفيذ)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ),
    );
  }
}
