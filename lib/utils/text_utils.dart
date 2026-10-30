/// Odstráni diakritiku a zmení na malé písmená – aby vyhľadávanie
/// "gulas" našlo aj "Guláš".
String normalize(String input) {
  const from = 'áäčďéěíĺľňóôŕřšťúůýžÁÄČĎÉĚÍĹĽŇÓÔŔŘŠŤÚŮÝŽ';
  const to = 'aacdeeillnoorrstuuyzAACDEEILLNOORRSTUUYZ';
  final sb = StringBuffer();
  for (final ch in input.split('')) {
    final i = from.indexOf(ch);
    sb.write(i >= 0 ? to[i] : ch);
  }
  return sb.toString().toLowerCase();
}

// ---------------------------------------------------------------------------
// Prepočet množstiev
// ---------------------------------------------------------------------------

const _fractions = {
  '½': 0.5,
  '¼': 0.25,
  '¾': 0.75,
  '⅓': 1 / 3,
  '⅔': 2 / 3,
};

const _num = r'(?:\d+(?:[.,]\d+)?(?:\s*[½¼¾⅓⅔])?|[½¼¾⅓⅔])';

/// Množstvo na začiatku riadku, napr. "700", "1 ½", "0,3", "3-4", "75 (150)".
final _leadingQty = RegExp(
  '^($_num)(?:\\s*[-–]\\s*($_num))?(?:\\s*\\(($_num)\\))?',
);

double? _parseNum(String s) {
  s = s.trim();
  if (_fractions.containsKey(s)) return _fractions[s];
  final m = RegExp(r'^(\d+(?:[.,]\d+)?)\s*([½¼¾⅓⅔])?$').firstMatch(s);
  if (m == null) return null;
  final base = double.parse(m.group(1)!.replaceAll(',', '.'));
  final frac = m.group(2) != null ? _fractions[m.group(2)!]! : 0.0;
  return base + frac;
}

/// Pekne naformátuje číslo: 0.5 -> "½", 1.5 -> "1 ½", 0.75 -> "¾", 2.4 -> "2,4".
String formatQty(double v) {
  if (v <= 0) return '0';
  final whole = v.floor();
  final rest = v - whole;
  for (final e in _fractions.entries) {
    if ((rest - e.value).abs() < 0.02) {
      return whole == 0 ? e.key : '$whole ${e.key}';
    }
  }
  if (rest < 0.02) return '$whole';
  if (rest > 0.98) return '${whole + 1}';
  // Väčšie čísla zaokrúhlime na celé, menšie na 1–2 desatinné miesta.
  String s;
  if (v >= 20) {
    s = v.round().toString();
  } else if (v >= 1) {
    s = v.toStringAsFixed(1);
  } else {
    s = v.toStringAsFixed(2);
  }
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return s.replaceAll('.', ',');
}

/// Rozdelí riadok suroviny na (množstvo, zvyšok). Ak riadok nezačína číslom,
/// množstvo je null.
({String? qty, String rest}) splitIngredient(String line, double factor) {
  final m = _leadingQty.firstMatch(line.trim());
  if (m == null) return (qty: null, rest: line.trim());
  String scale(String? s) {
    if (s == null) return '';
    final v = _parseNum(s);
    if (v == null) return s;
    return factor == 1 ? s.trim() : formatQty(v * factor);
  }

  var q = scale(m.group(1));
  if (m.group(2) != null) q += '–${scale(m.group(2))}';
  if (m.group(3) != null) q += ' (${scale(m.group(3))})';
  return (qty: q, rest: line.trim().substring(m.end).trim());
}
