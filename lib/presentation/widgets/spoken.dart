import '../../core/l10n.dart';

/// Human-readable move for screen readers, e.g. "Кінь f3, шах" (9.4).
String spokenSan(String san, AppLocalizations l) {
  var s = san.trim();
  if (s.startsWith('O-O-O')) return l.speakLongCastle + _suffix(s, l);
  if (s.startsWith('O-O')) return l.speakShortCastle + _suffix(s, l);
  if (s == '--') return l.speakNullMove;
  final parts = <String>[];
  final piece = switch (s[0]) {
    'K' => l.pieceKing,
    'Q' => l.pieceQueen,
    'R' => l.pieceRook,
    'B' => l.pieceBishop,
    'N' => l.pieceKnight,
    _ => null,
  };
  if (piece != null) {
    parts.add(piece);
    s = s.substring(1);
  } else {
    parts.add(l.piecePawn);
  }
  final core = s.replaceAll(RegExp(r'[+#!?]'), '');
  final promo = RegExp(r'=([QRBN])').firstMatch(core);
  final body = core.replaceAll(RegExp(r'=[QRBN]'), '');
  final m = RegExp(r'^([a-h]?[1-8]?)(x?)([a-h][1-8])$').firstMatch(body);
  if (m != null) {
    if (m.group(1)!.isNotEmpty) parts.add(m.group(1)!);
    if (m.group(2)!.isNotEmpty) parts.add(l.speakTakes);
    parts.add(m.group(3)!);
  } else {
    parts.add(body);
  }
  if (promo != null) {
    parts.add(
      l.speakPromotes(switch (promo.group(1)) {
        'Q' => l.pieceQueen,
        'R' => l.pieceRook,
        'B' => l.pieceBishop,
        _ => l.pieceKnight,
      }),
    );
  }
  return parts.join(' ') + _suffix(san, l);
}

String _suffix(String san, AppLocalizations l) {
  if (san.contains('#')) return ', ${l.speakMate}';
  if (san.contains('+')) return ', ${l.speakCheck}';
  return '';
}
