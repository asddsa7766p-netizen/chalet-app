/// يحوّل الأرقام العربية-الهندية (٠-٩) والفارسية (۰-۹) إلى لاتينية، والفاصلة
/// العشرية العربية (٫) إلى نقطة، ويحذف فاصل الآلاف العربي (٬). لوحات المفاتيح
/// العربية تكتب هذه الرموز و`int/double.tryParse` ترفضها.
String normalizeDigits(String input) {
  final b = StringBuffer();
  for (final unit in input.runes) {
    if (unit >= 0x0660 && unit <= 0x0669) {
      b.writeCharCode(0x30 + unit - 0x0660);
    } else if (unit >= 0x06F0 && unit <= 0x06F9) {
      b.writeCharCode(0x30 + unit - 0x06F0);
    } else if (unit == 0x066B) {
      b.write('.');
    } else if (unit == 0x066C) {
      // فاصل الآلاف العربي: يُحذف
    } else {
      b.writeCharCode(unit);
    }
  }
  return b.toString();
}

/// عدد صحيح من نص مُدخَل بأي أرقام (يرفض الكسور والنص). null إن لم يكن صالحاً.
int? parseLocalizedInt(String? input) =>
    int.tryParse(normalizeDigits(input ?? '').trim());

/// رقم عشري منتهٍ من نص مُدخَل بأي أرقام (يرفض NaN وInfinity). null إن لم
/// يكن صالحاً.
double? parseLocalizedDouble(String? input) {
  final v = double.tryParse(normalizeDigits(input ?? '').trim());
  if (v == null || !v.isFinite) return null;
  return v;
}
