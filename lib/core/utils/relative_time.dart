/// "منذ 3 أيام" — تاريخ نسبي عربي بصيغ العدد الصحيحة (مفرد، مثنى، جمع 3–10،
/// تمييز مفرد 11+). تاريخ في المستقبل (فرق ساعة الجهاز) يُعرض "الآن".
String relativeTimeAr(DateTime then, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(then);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inHours < 1) {
    return _ago(diff.inMinutes, 'دقيقة', 'دقيقتين', 'دقائق', 'دقيقة');
  }
  if (diff.inDays < 1) {
    return _ago(diff.inHours, 'ساعة', 'ساعتين', 'ساعات', 'ساعة');
  }
  final days = diff.inDays;
  if (days == 1) return 'أمس';
  if (days < 7) return _ago(days, 'يوم', 'يومين', 'أيام', 'يوماً');
  if (days < 30) {
    return _ago(days ~/ 7, 'أسبوع', 'أسبوعين', 'أسابيع', 'أسبوعاً');
  }
  if (days < 365) return _ago(days ~/ 30, 'شهر', 'شهرين', 'أشهر', 'شهراً');
  return _ago(days ~/ 365, 'سنة', 'سنتين', 'سنوات', 'سنة');
}

String _ago(int n, String one, String two, String few, String many) {
  if (n == 1) return 'منذ $one';
  if (n == 2) return 'منذ $two';
  if (n <= 10) return 'منذ $n $few';
  return 'منذ $n $many';
}
