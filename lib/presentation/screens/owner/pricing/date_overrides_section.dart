part of 'chalet_pricing_screen.dart';

extension _DateOverridesSection on _ChaletPricingScreenState {
  // ---------------- أسعار خاصة بتواريخ محددة ----------------

  Widget _buildDateOverridesSection() {
    final isDefault = _selectedEditingType == _ChaletPricingScreenState._defaultKey;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'أسعار خاصة لتواريخ محددة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _savingDateOverride ? null : _addDateOverride,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('إضافة',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
              ),
            ],
          ),
          Text(
            isDefault
                ? 'هاد السعر له الأولوية دايمًا فوق السعر الأسبوعي لنفس اليوم '
                    '(مثلاً أعياد أو مناسبات)، وأسعار «عام» هنا تسري على كل '
                    'الأنواع حتى لو لها سعر خاص بيومها. (تُحفظ فورًا)'
                : 'هاد السعر له الأولوية دايمًا فوق السعر الأسبوعي لنفس اليوم '
                    '(مثلاً أعياد أو مناسبات). (يُحفظ فورًا)',
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (_loadingOverrides)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_dateOverrides.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'لا يوجد أسعار خاصة مضافة بعد',
                  style:
                      TextStyle(fontFamily: 'Cairo', color: AppColors.textHint),
                ),
              ),
            )
          else
            ...(_dateOverrides.map((o) => _buildDateOverrideRow(o))),
        ],
      ),
    );
  }

  Widget _buildDateOverrideRow(ChaletDatePrice item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.date.year}/${item.date.month}/${item.date.day}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                if (item.note != null && item.note!.isNotEmpty)
                  Text(
                    item.note!,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          Text(
            '₪${formatPriceNumber(item.price)}',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error, size: 20),
            onPressed: () => _deleteDateOverride(item),
          ),
        ],
      ),
    );
  }
}
