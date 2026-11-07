/// Türkçe göreli zaman: "az önce", "5 dk önce", "dün", "12.11.2026".
String relativeTime(DateTime? t) {
  if (t == null) return '';
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'az önce';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
  if (diff.inHours < 24) return '${diff.inHours} saat önce';
  if (diff.inDays == 1) return 'dün';
  if (diff.inDays < 7) return '${diff.inDays} gün önce';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}.${two(t.month)}.${t.year}';
}
