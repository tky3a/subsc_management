/// 金額・日付の表示用フォーマット。
library;

String _group(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return (n < 0 ? '-' : '') + buf.toString();
}

/// 円表示（端数は四捨五入）: 1590.4 → ¥1,590
String yen(num value) => '¥${_group(value.round())}';

/// 符号付きの円表示: 100 → +¥100 / -100 → −¥100
String signedYen(num value) {
  final r = value.round();
  if (r == 0) return '±¥0';
  return '${r > 0 ? '+' : '−'}¥${_group(r.abs())}';
}

/// 通貨の最小単位の整数を表示: (1999, '$', 100) → $19.99 / (1590, '¥', 1) → ¥1,590
String money(int minor, String symbol, int factor) {
  if (factor == 1) return '$symbol${_group(minor)}';
  final major = minor ~/ factor;
  final digits = (factor - 1).toString().length;
  final fraction = (minor.abs() % factor).toString().padLeft(digits, '0');
  return '$symbol${_group(major)}.$fraction';
}

/// 入力欄に表示する金額（記号・桁区切りなし）: (1999, 100) → 19.99
String moneyInput(int minor, int factor) {
  if (factor == 1) return minor.toString();
  final digits = (factor - 1).toString().length;
  return '${minor ~/ factor}.${(minor % factor).toString().padLeft(digits, '0')}';
}

/// 入力文字列を最小単位の整数に変換。不正な値は null。
int? parseMoney(String text, int factor) {
  final cleaned = text.replaceAll(RegExp(r'[,\s¥$円]'), '');
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  if (value == null || value < 0) return null;
  return (value * factor).round();
}

String rateLabel(double rate) => '¥${rate.toStringAsFixed(1)}';

/// 契約形態: 1 → 月額 / 12 → 年額 / 3 → 3か月ごと
String contractLabel(int intervalMonths) => switch (intervalMonths) {
      1 => '月額',
      12 => '年額',
      _ => '$intervalMonthsか月ごと',
    };

/// 請求 1 回の単位: 1 → 月 / 12 → 年 / 3 → 3か月
String intervalUnit(int intervalMonths) => switch (intervalMonths) {
      1 => '月',
      12 => '年',
      _ => '$intervalMonthsか月',
    };

String yearMonthOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

String currentYearMonth() => yearMonthOf(DateTime.now());

/// '2026-09' → 2026年9月
String yearMonthLabel(String ym) {
  final parts = ym.split('-');
  return '${parts[0]}年${int.parse(parts[1])}月';
}

/// '2026-09' → 2026/09
String yearMonthShort(String ym) => ym.replaceAll('-', '/');

/// DateTime → '2026-09-28'
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// '2026-09-28' → 2026/09/28
String dateLabel(String iso) => iso.replaceAll('-', '/');
