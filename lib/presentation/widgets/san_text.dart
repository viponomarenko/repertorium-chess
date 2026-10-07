/// Display of chess moves in the user's notation (T-13, T-14).
///
/// * english — K Q R B N (default);
/// * ukrainian — Кр Ф Т С К;
/// * figurine — small piece images via [WidgetSpan], from the same piece
///   set as the board, sized to the cap height and sitting on the baseline.
///
/// Display only: PGN export always uses English SAN.
library;

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' show PieceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../theme/typography.dart';
import 'board_view.dart';

/// Cap height of Google Sans as a fraction of the font size (716 / 1000).
const _capHeight = 0.716;

const _ukLetters = {'K': 'Кр', 'Q': 'Ф', 'R': 'Т', 'B': 'С', 'N': 'К'};

const _figurineKinds = {
  'K': PieceKind.whiteKing,
  'Q': PieceKind.whiteQueen,
  'R': PieceKind.whiteRook,
  'B': PieceKind.whiteBishop,
  'N': PieceKind.whiteKnight,
};

/// A SAN move (optionally with a number prefix and check/annotation
/// suffix) inside arbitrary text. Castling and pawn moves have no piece.
final _moveToken = RegExp(
  r'(?<![A-Za-z0-9])([KQRBN])([a-h]?[1-8]?x?[a-h][1-8](?:=[QRBN])?[+#]?)|([a-h](?:x[a-h])?[1-8])=([QRBN])',
);

class NotationFormatter {
  const NotationFormatter(this.language, this.pieces);
  final NotationLanguage language;
  final PieceAssets pieces;

  /// Plain-text version (figurine falls back to English letters, e.g. in
  /// messages and tooltips).
  String text(String s) {
    if (language != NotationLanguage.ukrainian) return s;
    return s.replaceAllMapped(_moveToken, (m) {
      if (m.group(1) != null) {
        final rest = m.group(2)!.replaceAllMapped(RegExp('=([QRBN])'), (p) => '=${_ukLetters[p.group(1)]}');
        return '${_ukLetters[m.group(1)]}$rest';
      }
      return '${m.group(3)}=${_ukLetters[m.group(4)]}';
    });
  }

  /// Rich spans for [s] with [style]; piece letters become figurines when
  /// the figurine notation is selected.
  List<InlineSpan> spans(String s, TextStyle style) {
    if (language != NotationLanguage.figurine) return [TextSpan(text: text(s), style: style)];
    final out = <InlineSpan>[];
    var last = 0;
    for (final m in _moveToken.allMatches(s)) {
      if (m.start > last) out.add(TextSpan(text: s.substring(last, m.start), style: style));
      if (m.group(1) != null) {
        out.add(_figurine(m.group(1)!, style));
        _addWithPromotion(out, m.group(2)!, style);
      } else {
        out.add(TextSpan(text: '${m.group(3)}=', style: style));
        out.add(_figurine(m.group(4)!, style));
      }
      last = m.end;
    }
    if (last < s.length) out.add(TextSpan(text: s.substring(last), style: style));
    return out;
  }

  void _addWithPromotion(List<InlineSpan> out, String rest, TextStyle style) {
    final promo = RegExp('=([QRBN])').firstMatch(rest);
    if (promo == null) {
      out.add(TextSpan(text: rest, style: style));
      return;
    }
    out.add(TextSpan(text: rest.substring(0, promo.start + 1), style: style));
    out.add(_figurine(promo.group(1)!, style));
    out.add(TextSpan(text: rest.substring(promo.end), style: style));
  }

  InlineSpan _figurine(String letter, TextStyle style) {
    final size = (style.fontSize ?? 14) * _capHeight;
    // A little larger than the cap height: piece images have inner padding.
    final box = size * 1.3;
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Semantics(
        label: letter,
        child: Baseline(
          baseline: box * 0.88,
          baselineType: TextBaseline.alphabetic,
          child: SizedBox.square(
            dimension: box,
            child: Image(image: pieces[_figurineKinds[letter]!]!),
          ),
        ),
      ),
    );
  }
}

final notationFormatterProvider = Provider<NotationFormatter>((ref) {
  final s = ref.watch(settingsProvider);
  return NotationFormatter(NotationLanguage.fromName(s.notationLanguage), BoardAppearance.pieceSet(s.pieceSet).assets);
});

/// Text with moves rendered in the user's notation.
class MovesText extends ConsumerWidget {
  const MovesText(this.text, {super.key, this.style, this.maxLines, this.overflow, this.textAlign});
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(notationFormatterProvider);
    final base = DefaultTextStyle.of(context).style.merge(style);
    return Text.rich(
      TextSpan(children: f.spans(text, base)),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      semanticsLabel: f.text(text),
    );
  }
}

/// A single piece image (replaces Unicode chess glyphs, T-15).
class PieceIcon extends ConsumerWidget {
  const PieceIcon(this.kind, {super.key, this.size = 24, this.semanticLabel});
  final PieceKind kind;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final set = BoardAppearance.pieceSet(ref.watch(settingsProvider.select((s) => s.pieceSet)));
    return SizedBox.square(
      dimension: size,
      child: Image(image: set.assets[kind]!, semanticLabel: semanticLabel, excludeFromSemantics: semanticLabel == null),
    );
  }
}
