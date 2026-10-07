/// Text decoding for imported chess files (F-IMP-03).
///
/// Supports UTF-8 (with or without BOM, also with stray single-byte
/// characters), UTF-16, Windows-1251 (Cyrillic, typical for ChessBase
/// exports), KOI8-U and Windows-1252 / Latin-1. A UTF-8 file that already
/// contains mojibake ("РЎРёС†..." – UTF-8 once read as Windows-1251) is
/// repaired. Detection is heuristic; the UI lets the user switch the
/// encoding manually.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

enum TextEncodingKind {
  utf8('UTF-8'),
  windows1251('Windows-1251'),
  koi8u('KOI8-U'),
  windows1252('Windows-1252'),
  utf16le('UTF-16 LE'),
  utf16be('UTF-16 BE');

  const TextEncodingKind(this.label);
  final String label;
}

class DecodedText {
  const DecodedText(this.text, this.encoding, {this.hadBom = false});
  final String text;
  final TextEncodingKind encoding;
  final bool hadBom;
}

const _cp1251High = <int>[
  // 0x80
  0x0402, 0x0403, 0x201A, 0x0453, 0x201E, 0x2026, 0x2020, 0x2021, //
  0x20AC, 0x2030, 0x0409, 0x2039, 0x040A, 0x040C, 0x040B, 0x040F,
  // 0x90
  0x0452, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
  0xFFFD, 0x2122, 0x0459, 0x203A, 0x045A, 0x045C, 0x045B, 0x045F,
  // 0xA0
  0x00A0, 0x040E, 0x045E, 0x0408, 0x00A4, 0x0490, 0x00A6, 0x00A7,
  0x0401, 0x00A9, 0x0404, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x0407,
  // 0xB0
  0x00B0, 0x00B1, 0x0406, 0x0456, 0x0491, 0x00B5, 0x00B6, 0x00B7,
  0x0451, 0x2116, 0x0454, 0x00BB, 0x0458, 0x0405, 0x0455, 0x0457,
];

const _cp1252C1 = <int>[
  0x20AC, 0x0081, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, //
  0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x008D, 0x017D, 0x008F,
  0x0090, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
  0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x009D, 0x017E, 0x0178,
];

const _koi8uHigh = <int>[
  0x2500, 0x2502, 0x250C, 0x2510, 0x2514, 0x2518, 0x251C, 0x2524, //
  0x252C, 0x2534, 0x253C, 0x2580, 0x2584, 0x2588, 0x258C, 0x2590,
  0x2591, 0x2592, 0x2593, 0x2320, 0x25A0, 0x2219, 0x221A, 0x2248,
  0x2264, 0x2265, 0x00A0, 0x2321, 0x00B0, 0x00B2, 0x00B7, 0x00F7,
  0x2550, 0x2551, 0x2552, 0x0451, 0x0454, 0x2554, 0x0456, 0x0457,
  0x2557, 0x2558, 0x2559, 0x255A, 0x255B, 0x0491, 0x255D, 0x255E,
  0x255F, 0x2560, 0x2561, 0x0401, 0x0404, 0x2563, 0x0406, 0x0407,
  0x2566, 0x2567, 0x2568, 0x2569, 0x256A, 0x0490, 0x256C, 0x00A9,
  0x044E, 0x0430, 0x0431, 0x0446, 0x0434, 0x0435, 0x0444, 0x0433,
  0x0445, 0x0438, 0x0439, 0x043A, 0x043B, 0x043C, 0x043D, 0x043E,
  0x043F, 0x044F, 0x0440, 0x0441, 0x0442, 0x0443, 0x0436, 0x0432,
  0x044C, 0x044B, 0x0437, 0x0448, 0x044D, 0x0449, 0x0447, 0x044A,
  0x042E, 0x0410, 0x0411, 0x0426, 0x0414, 0x0415, 0x0424, 0x0413,
  0x0425, 0x0418, 0x0419, 0x041A, 0x041B, 0x041C, 0x041D, 0x041E,
  0x041F, 0x042F, 0x0420, 0x0421, 0x0422, 0x0423, 0x0416, 0x0412,
  0x042C, 0x042B, 0x0417, 0x0428, 0x042D, 0x0429, 0x0427, 0x042A,
];

String decodeKoi8u(List<int> bytes) {
  final codes = Uint16List(bytes.length);
  for (var i = 0; i < bytes.length; i++) {
    final b = bytes[i];
    codes[i] = b < 0x80 ? b : _koi8uHigh[b - 0x80];
  }
  return String.fromCharCodes(codes);
}

String decodeWindows1251(List<int> bytes) {
  final codes = Uint16List(bytes.length);
  for (var i = 0; i < bytes.length; i++) {
    final b = bytes[i];
    if (b < 0x80) {
      codes[i] = b;
    } else if (b < 0xC0) {
      codes[i] = _cp1251High[b - 0x80];
    } else {
      codes[i] = 0x0410 + (b - 0xC0);
    }
  }
  return String.fromCharCodes(codes);
}

String decodeWindows1252(List<int> bytes) {
  final codes = Uint16List(bytes.length);
  for (var i = 0; i < bytes.length; i++) {
    final b = bytes[i];
    codes[i] = (b >= 0x80 && b < 0xA0) ? _cp1252C1[b - 0x80] : b;
  }
  return String.fromCharCodes(codes);
}

bool _hasUtf8Bom(List<int> b) => b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF;

/// Guesses between Windows-1251 and Windows-1252 for a few stray bytes.
///
/// Cyrillic words in cp1251 are runs of bytes in 0xC0..0xFF; in Western
/// European text such runs of 3+ bytes are rare.
TextEncodingKind guessSingleByte(List<int> bytes) {
  var run = 0;
  var cyrRuns = 0;
  var highBytes = 0;
  var latinRuns = 0;
  for (final b in bytes) {
    if (b >= 0xC0) {
      highBytes++;
      run++;
      if (run == 3) cyrRuns++;
    } else {
      if (run > 0 && run < 3 && _isAsciiLetter(b)) latinRuns++;
      run = 0;
    }
  }
  if (highBytes == 0) return TextEncodingKind.windows1252;
  return cyrRuns * 2 >= latinRuns ? TextEncodingKind.windows1251 : TextEncodingKind.windows1252;
}

bool _isAsciiLetter(int b) => (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A);

bool _isCyrLower(int c) =>
    (c >= 0x430 && c <= 0x44F) || c == 0x451 || c == 0x454 || c == 0x456 || c == 0x457 || c == 0x491;
bool _isCyrUpper(int c) =>
    (c >= 0x410 && c <= 0x42F) || c == 0x401 || c == 0x404 || c == 0x406 || c == 0x407 || c == 0x490;
bool _isCyr(int c) => _isCyrLower(c) || _isCyrUpper(c);
bool _isLatin1Letter(int c) => c >= 0xC0 && c <= 0xFF && c != 0xD7 && c != 0xF7;

/// How common a Cyrillic letter is in Ukrainian and Russian text
/// (lowercase): mojibake shuffles letters, so it is full of rare ones.
const _letterWeight = <int, int>{
  // о а е и н т і р с в
  0x43E: 3,
  0x430: 3,
  0x435: 3,
  0x438: 3,
  0x43D: 3,
  0x442: 3,
  0x456: 3,
  0x440: 3,
  0x441: 3,
  0x432: 3,
  // л к м д п у я з ь
  0x43B: 2,
  0x43A: 2,
  0x43C: 2,
  0x434: 2,
  0x43F: 2,
  0x443: 2,
  0x44F: 2,
  0x437: 2,
  0x44C: 2,
  // г б ч й х ж ш ю ц ы є ї
  0x433: 1,
  0x431: 1,
  0x447: 1,
  0x439: 1,
  0x445: 1,
  0x436: 1,
  0x448: 1,
  0x44E: 1,
  0x446: 1,
  0x44B: 1,
  0x454: 1, 0x457: 1,
  // щ ф э ё ґ: 0; ъ
  0x44A: -1,
};

int _lower(int c) => switch (c) {
  >= 0x410 && <= 0x42F => c + 0x20,
  0x401 => 0x451,
  0x404 => 0x454,
  0x406 => 0x456,
  0x407 => 0x457,
  0x490 => 0x491,
  _ => c,
};

/// Neither rewarded nor penalised: punctuation and the symbols of chess
/// annotations (≤ ± ∞ ⩲ □ → …), and ChessBase's private-use characters.
bool _neutral(int c) =>
    c == 0xA0 ||
    c == 0xAB ||
    c == 0xBB ||
    c == 0xB0 ||
    c == 0xB1 ||
    (c >= 0x2000 && c <= 0x24FF) ||
    (c >= 0x25A0 && c <= 0x2BFF) ||
    (c >= 0xE000 && c <= 0xF8FF);

/// Characters of real text: ASCII, Ukrainian/Russian and Western letters,
/// punctuation and chess symbols.
bool _ordinary(int c) => c < 0x80 || _isCyr(c) || _isLatin1Letter(c) || (c >= 0xA0 && c <= 0xBF) || _neutral(c);

/// How much the non-ASCII characters of [t] look like real Ukrainian,
/// Russian or Western European text: common Cyrillic letters, accented
/// letters inside Latin words. Mojibake scores low: rare letters (the
/// wrong code page shuffles them), a capital right after a lowercase
/// letter, Cyrillic glued to Latin (1252 read as 1251), words of only
/// accented letters (1251 read as 1252), box drawing (KOI8) and other
/// symbols. Case alone says nothing: chess files have ALL-CAPS headers.
int plausibility(String t) {
  var score = 0;
  final u = t.codeUnits;
  for (var i = 0; i < u.length; i++) {
    final c = u[i];
    if (c < 0x80) continue;
    final p = i > 0 ? u[i - 1] : 0x20;
    final n = i + 1 < u.length ? u[i + 1] : 0x20;
    if (_isCyr(c)) {
      if (_isAsciiLetter(p) || _isAsciiLetter(n)) {
        score -= 2;
      } else {
        score += _letterWeight[_lower(c)] ?? 0;
        if (_isCyrUpper(c) && _isCyrLower(p)) score -= 3;
      }
    } else if (_isLatin1Letter(c)) {
      score += _isAsciiLetter(p) || _isAsciiLetter(n) ? 2 : -1;
    } else if (!_neutral(c)) {
      score -= 3;
    }
  }
  return score;
}

/// Valid UTF-8 multi-byte sequence starting at [i]: its length, else 0.
int _utf8SeqLen(List<int> b, int i) {
  final lead = b[i];
  int len;
  int lo = 0x80, hi = 0xBF;
  if (lead >= 0xC2 && lead <= 0xDF) {
    len = 2;
  } else if (lead >= 0xE0 && lead <= 0xEF) {
    len = 3;
    if (lead == 0xE0) lo = 0xA0;
    if (lead == 0xED) hi = 0x9F;
  } else if (lead >= 0xF0 && lead <= 0xF4) {
    len = 4;
    if (lead == 0xF0) lo = 0x90;
    if (lead == 0xF4) hi = 0x8F;
  } else {
    return 0;
  }
  if (i + len > b.length) return 0;
  for (var k = 1; k < len; k++) {
    final x = b[i + k];
    if (x < (k == 1 ? lo : 0x80) || x > (k == 1 ? hi : 0xBF)) return 0;
  }
  return len;
}

/// ChessBase exports write some Cyrillic letters as private-use
/// characters, in UTF-8 even inside Windows-1251 text (seen in real
/// files: "\uE009то" for "что", "ТИПИ\uE010НАЯ").
const _chessBaseLetters = {0xE007: 0x042E, 0xE008: 0x044E, 0xE009: 0x0447, 0xE010: 0x0427}; // Ю ю ч Ч

/// Replaces [_chessBaseLetters] that stand inside or next to a Cyrillic
/// word (other private-use characters are ChessBase symbols).
String _fixChessBaseLetters(String t) {
  if (!t.codeUnits.any((c) => c >= 0xE007 && c <= 0xE010)) return t;
  final u = List<int>.of(t.codeUnits);
  bool letterAt(int k) => k >= 0 && k < u.length && (_isCyr(u[k]) || _chessBaseLetters.containsKey(u[k]));
  for (var k = 0; k < u.length; k++) {
    final r = _chessBaseLetters[u[k]];
    if (r != null && (letterAt(k - 1) || letterAt(k + 1))) u[k] = r;
  }
  // Second pass: a run of them next to a word (e.g. "лишнюю" → "лишн\uE008\uE008").
  for (var k = u.length - 1; k >= 0; k--) {
    final r = _chessBaseLetters[u[k]];
    if (r != null && (letterAt(k - 1) || letterAt(k + 1))) u[k] = r;
  }
  return String.fromCharCodes(u);
}

enum _LineKind { ascii, utf8, mixed, single }

/// A file that is not valid UTF-8 as a whole, decoded line by line:
/// ChessBase merges games in different encodings into one file, and a
/// comment pasted from a Windows program leaves stray bytes in UTF-8.
/// A line is UTF-8 when it is valid UTF-8 (and reads better so); mostly
/// UTF-8 with stray bytes – byte by byte; otherwise single-byte (keeping
/// ChessBase's private-use UTF-8 letters). The single-byte encoding is the
/// one whose text reads most like text, judged on the non-UTF-8 bytes only
/// (ties go to Windows-1251, the usual one for Ukrainian files).
DecodedText _decodeByLines(List<int> b) {
  final lines = <List<int>>[];
  final kinds = <_LineKind>[];
  final sample = <int>[]; // the bytes that are not UTF-8
  for (var start = 0; start < b.length;) {
    var end = start;
    while (end < b.length && b[end] != 0x0A) {
      end++;
    }
    if (end < b.length) end++; // keep the newline
    final line = b.sublist(start, end);
    start = end;
    var valid = 0;
    final stray = <int>[];
    for (var i = 0; i < line.length;) {
      if (line[i] < 0x80) {
        i++;
        continue;
      }
      final len = _utf8SeqLen(line, i);
      if (len == 0) {
        stray.add(line[i]);
        i++;
      } else {
        if (!_isPrivateLetterSeq(line, i)) valid++;
        i += len;
      }
    }
    final kind = valid == 0 && stray.isEmpty
        ? _LineKind.ascii
        : stray.isEmpty
        ? _LineKind.utf8
        : valid >= stray.length
        ? _LineKind.mixed
        : _LineKind.single;
    if (kind == _LineKind.single) sample.addAll(line);
    if (kind == _LineKind.mixed) sample.addAll(stray);
    lines.add(line);
    kinds.add(kind);
  }

  var enc = TextEncodingKind.windows1251;
  var single = decodeWindows1251;
  var bestScore = plausibility(decodeWindows1251(sample));
  for (final (k, f) in [(TextEncodingKind.koi8u, decodeKoi8u), (TextEncodingKind.windows1252, decodeWindows1252)]) {
    final score = plausibility(f(sample));
    if (score > bestScore) {
      (enc, single, bestScore) = (k, f, score);
    }
  }

  final sb = StringBuffer();
  var utf8Lines = 0, singleLines = 0;
  for (var n = 0; n < lines.length; n++) {
    final line = lines[n];
    switch (kinds[n]) {
      case _LineKind.ascii:
        sb.write(const Utf8Decoder().convert(line));
      case _LineKind.utf8:
        // Valid UTF-8 giving ordinary characters is UTF-8. Valid only by
        // accident ("Сі" in Windows-1251 is the UTF-8 of "ѳ"): whichever
        // reads better.
        final asUtf8 = const Utf8Decoder().convert(line);
        final asSingle = _decodeKeepingPrivate(line, single, anyUtf8: false);
        final utf8Wins = asUtf8.codeUnits.every(_ordinary) || plausibility(asUtf8) + 2 >= plausibility(asSingle);
        sb.write(utf8Wins ? asUtf8 : asSingle);
        utf8Wins ? utf8Lines++ : singleLines++;
      case _LineKind.mixed:
        sb.write(_decodeKeepingPrivate(line, single, anyUtf8: true));
        utf8Lines++;
      case _LineKind.single:
        sb.write(_decodeKeepingPrivate(line, single, anyUtf8: false));
        singleLines++;
    }
  }
  return DecodedText(
    _fixChessBaseLetters(_repairLatinMojibake(sb.toString())),
    utf8Lines >= singleLines && utf8Lines > 0 ? TextEncodingKind.utf8 : enc,
  );
}

/// EE 80 87..90: UTF-8 of U+E007..U+E010 (ChessBase letters/symbols).
bool _isPrivateLetterSeq(List<int> b, int i) =>
    i + 2 < b.length && b[i] == 0xEE && (b[i + 1] == 0x80 && b[i + 2] >= 0x80);

/// [line] with bytes in [single]; valid UTF-8 sequences stay UTF-8 when
/// [anyUtf8], else only ChessBase's private-use ones do.
String _decodeKeepingPrivate(List<int> line, String Function(List<int>) single, {required bool anyUtf8}) {
  final sb = StringBuffer();
  var run = <int>[];
  void flush() {
    if (run.isNotEmpty) sb.write(single(run));
    run = <int>[];
  }

  for (var i = 0; i < line.length;) {
    final len = line[i] < 0x80 ? 0 : _utf8SeqLen(line, i);
    if (len > 0 && (anyUtf8 || _isPrivateLetterSeq(line, i))) {
      flush();
      sb.write(const Utf8Decoder().convert(line, i, i + len));
      i += len;
    } else {
      run.add(line[i]);
      i++;
    }
  }
  flush();
  return sb.toString();
}

/// UTF-16 without a BOM: plain-ASCII PGN has a zero in every other byte.
TextEncodingKind? _guessUtf16(List<int> b) {
  final n = math.min(b.length, 4096) & ~1;
  if (n < 16) return null;
  var zeroEven = 0, zeroOdd = 0;
  for (var i = 0; i < n; i += 2) {
    if (b[i] == 0) zeroEven++;
    if (b[i + 1] == 0) zeroOdd++;
  }
  final pairs = n ~/ 2;
  if (zeroOdd > pairs / 4 && zeroEven < pairs / 50) return TextEncodingKind.utf16le;
  if (zeroEven > pairs / 4 && zeroOdd < pairs / 50) return TextEncodingKind.utf16be;
  return null;
}

String _decodeUtf16(List<int> b, {required bool little}) {
  final units = Uint16List(b.length ~/ 2);
  for (var i = 0; i < units.length; i++) {
    final x = b[2 * i], y = b[2 * i + 1];
    units[i] = little ? (y << 8) | x : (x << 8) | y;
  }
  return String.fromCharCodes(units);
}

/// Reverse of a single-byte decoder, for repairing mojibake.
Map<int, int> _reverse(String Function(List<int>) decode) {
  final chars = decode([for (var b = 0x80; b < 0x100; b++) b]).codeUnits;
  return {for (var k = 0; k < chars.length; k++) chars[k]: 0x80 + k};
}

final _rev1251 = _reverse(decodeWindows1251);
final _rev1252 = _reverse(decodeWindows1252);

/// Text that went UTF-8 → read as [rev]'s encoding → saved as UTF-8
/// again ("Р§РµРјРї" for "Чемп"): back to the original, if it was that.
String? _undoMojibake(String t, Map<int, int> rev) {
  final bytes = <int>[];
  for (final c in t.codeUnits) {
    if (c < 0x80) {
      bytes.add(c);
    } else {
      final b = rev[c];
      if (b == null) return null;
      bytes.add(b);
    }
  }
  try {
    return const Utf8Decoder().convert(bytes);
  } on FormatException {
    return null;
  }
}

/// Lines where Windows-1251 text was once read as Windows-1252 and saved
/// that way ("Äîñòàòîíî" for "Достаточно"): back to Cyrillic when that
/// reads better. Only lines with runs of accented letters are tried, so
/// French or German stays untouched.
String _repairLatinMojibake(String t) {
  final run = RegExp(r'[À-ÿ]{3,}');
  if (!run.hasMatch(t)) return t;
  String fix(String line) {
    if (!run.hasMatch(line)) return line;
    final sb = StringBuffer();
    for (final c in line.codeUnits) {
      final b = _rev1252[c];
      sb.write(b == null ? String.fromCharCode(c) : decodeWindows1251([b]));
    }
    final candidate = sb.toString();
    return plausibility(candidate) > plausibility(line) ? candidate : line;
  }

  return t.split('\n').map(fix).join('\n');
}

/// A decoded UTF-8 text, repaired when it is double-encoded mojibake and
/// the repair reads clearly better.
String _repairIfMojibake(String t) {
  // Mojibake of Cyrillic writes each letter as Р/С (via 1251) or Ð/Ñ (via
  // 1252) followed by what was a UTF-8 continuation byte; cheap check
  // before trying.
  final u = t.codeUnits;
  var marks = 0;
  for (var i = 0; i + 1 < u.length; i++) {
    final c = u[i];
    final rev = c == 0x420 || c == 0x421 ? _rev1251 : (c == 0xD0 || c == 0xD1 ? _rev1252 : null);
    final next = rev?[u[i + 1]];
    if (next != null && next < 0xC0) marks++;
  }
  if (marks < 3) return t;
  var best = t;
  var bestScore = plausibility(t);
  for (final rev in [_rev1251, _rev1252]) {
    final r = _undoMojibake(t, rev);
    if (r == null) continue;
    final s = plausibility(r);
    if (s > bestScore) {
      best = r;
      bestScore = s;
    }
  }
  return best;
}

/// Decodes [bytes], detecting the encoding unless [forced] is given.
DecodedText decodeChessText(List<int> bytes, {TextEncodingKind? forced}) {
  final bom = _hasUtf8Bom(bytes);
  final body = bom ? bytes.sublist(3) : bytes;
  switch (forced) {
    case TextEncodingKind.utf8:
      return DecodedText(const Utf8Decoder(allowMalformed: true).convert(body), TextEncodingKind.utf8, hadBom: bom);
    case TextEncodingKind.windows1251:
      return DecodedText(decodeWindows1251(body), TextEncodingKind.windows1251);
    case TextEncodingKind.koi8u:
      return DecodedText(decodeKoi8u(body), TextEncodingKind.koi8u);
    case TextEncodingKind.windows1252:
      return DecodedText(decodeWindows1252(body), TextEncodingKind.windows1252);
    case TextEncodingKind.utf16le || TextEncodingKind.utf16be:
      final little = forced == TextEncodingKind.utf16le;
      final hasBom = bytes.length >= 2 && bytes[0] == (little ? 0xFF : 0xFE) && bytes[1] == (little ? 0xFE : 0xFF);
      return DecodedText(_decodeUtf16(hasBom ? bytes.sublist(2) : bytes, little: little), forced!, hadBom: hasBom);
    case null:
      break;
  }
  if (bom) {
    return DecodedText(
      _repairIfMojibake(const Utf8Decoder(allowMalformed: true).convert(body)),
      TextEncodingKind.utf8,
      hadBom: true,
    );
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return decodeChessText(bytes, forced: TextEncodingKind.utf16le);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return decodeChessText(bytes, forced: TextEncodingKind.utf16be);
  }
  final utf16 = _guessUtf16(bytes);
  if (utf16 != null) return decodeChessText(bytes, forced: utf16);
  try {
    return DecodedText(
      _fixChessBaseLetters(_repairLatinMojibake(_repairIfMojibake(const Utf8Decoder().convert(body)))),
      TextEncodingKind.utf8,
    );
  } on FormatException {
    // Not UTF-8 as a whole: single-byte, possibly mixed with UTF-8.
    return _decodeByLines(body);
  }
}
